"""Event-Study Modul: Kursreaktionen auf Ereignisse analysieren.

Phase 4:
- Signals -> Events konvertieren (wenn relevance > threshold)
- Ereignistypen klassifizieren (via Keywords + später KI)
- Historische Kursreaktionen tracken (yfinance)
- Hickup-Erkennung: Spike + Rückkehr
- Basisraten je Ereignistyp aggregieren
"""

from __future__ import annotations

import datetime as dt
import re
from dataclasses import dataclass
from typing import TYPE_CHECKING

from sqlalchemy import select

from stockintel.db.models import Event, EventOutcome, EventType, Signal

if TYPE_CHECKING:
    from stockintel.db.database import Database


@dataclass(frozen=True)
class EventTypeClassifier:
    """Pattern zum Erkennen von Ereignistypen aus Text."""
    event_type: EventType
    keywords: list[str]
    min_relevance: int = 40  # Mindest-Relevance für diese Klassifikation


# Klassifikations-Patterns
EVENT_TYPE_PATTERNS = [
    EventTypeClassifier(
        event_type=EventType.EARNINGS,
        keywords=["earnings", "quarterly results", "q1", "q2", "q3", "q4", "revenue", "eps"],
        min_relevance=50,
    ),
    EventTypeClassifier(
        event_type=EventType.GUIDANCE,
        keywords=["guidance", "outlook", "forecast", "forward", "fy2"],
        min_relevance=45,
    ),
    EventTypeClassifier(
        event_type=EventType.FDA,
        keywords=["fda", "approval", "clinical trial", "drug", "pharmaceutical"],
        min_relevance=60,
    ),
    EventTypeClassifier(
        event_type=EventType.MA,
        keywords=["acquisition", "merger", "acquired", "deal", "takeover", "bid"],
        min_relevance=70,
    ),
    EventTypeClassifier(
        event_type=EventType.IPO,
        keywords=["ipo", "public offering", "s-1", "listing", "flotation"],
        min_relevance=80,
    ),
    EventTypeClassifier(
        event_type=EventType.CEO_COMMENT,
        keywords=["ceo", "founder", "management", "executive", "analyst call"],
        min_relevance=35,
    ),
    EventTypeClassifier(
        event_type=EventType.HIGH_PROFILE_POST,
        keywords=["musk", "trump", "post", "tweet", "statement", "elon"],
        min_relevance=40,
    ),
    EventTypeClassifier(
        event_type=EventType.INSIDER,
        keywords=["insider", "insider trading", "insider purchase", "insider sale", "form 4"],
        min_relevance=50,
    ),
]


def classify_event_type(signal: Signal, title: str | None = None, body: str | None = None) -> EventType:
    """Klassifiziert ein Signal in einen EventType (regelbasiert).

    Verwendet Keywords + Relevance-Threshold. Fallback: OTHER.
    """
    text = f"{title or ''} {body or ''}".lower()
    relevance = signal.relevance or 0

    for pattern in EVENT_TYPE_PATTERNS:
        if relevance < pattern.min_relevance:
            continue
        for keyword in pattern.keywords:
            if re.search(r'\b' + re.escape(keyword) + r'\b', text):
                return pattern.event_type

    return EventType.OTHER


def signal_to_event(db: Database, signal: Signal) -> Event | None:
    """Konvertiert einen Signal (wenn aussagekräftig) zu einem Event.

    Prüft: relevance > 30, direction != neutral.
    Returns: neue Event oder None.
    Idempotent: pro Signal wird maximal ein Event angelegt.
    """
    if not signal.relevance or signal.relevance < 30:
        return None
    if signal.direction.value == "neutral":
        return None

    with db.session() as session:
        # Prüfe ob Event schon exists
        existing = session.scalar(
            select(Event).where(Event.raw_item_id == signal.raw_item_id)
        )
        if existing:
            return None

        # Item laden für Klassifikation
        item = signal.raw_item
        event_type = classify_event_type(signal, item.title, item.body)

        t0 = item.published_at or dt.datetime.now(dt.timezone.utc)
        event = Event(
            company_id=signal.company_id,
            raw_item_id=signal.raw_item_id,
            event_type=event_type,
            t0=t0,
            summary=f"{signal.direction.value.upper()}: {(item.title or '')[:100]}",
        )
        session.add(event)
        session.commit()
        return event


def classify_hickup(
    baseline_price: float | None,
    peak_price: float | None,
    final_price: float | None,
    peak_threshold: float = 0.05,  # 5% Spike
    revert_threshold: float = 0.03,  # 3% Rückkehr
) -> bool:
    """Erkennt Hickup: Spike + Rückkehr (Strohfeuer).

    Hickup = (peak_return > peak_threshold) AND (final_return < peak_return - revert_threshold).
    """
    if not all([baseline_price, peak_price, final_price]):
        return False

    if baseline_price == 0:
        return False

    peak_return = (peak_price - baseline_price) / baseline_price
    final_return = (final_price - baseline_price) / baseline_price

    # Ist ein Spike vorhanden UND ist er wieder zurückgekommen?
    return (peak_return > peak_threshold) and (final_return <= peak_return - revert_threshold)


def compute_event_outcome(event: Event) -> EventOutcome | None:
    """Berechnet Outcome aus Event-Snapshots: Rendite, abnormal return, Hickup-Flag.

    Später: yfinance fetch der Snapshots. Für jetzt: Stub mit Dummy-Berechnung.
    """
    if not event.snapshots:
        return None

    # Snapshots sortieren nach Horizon
    snapshots = sorted(event.snapshots, key=lambda s: s.horizon or "")
    if not snapshots:
        return None

    baseline = snapshots[0].price if snapshots else None
    peak = max((s.price for s in snapshots if s.price), default=None)
    final = snapshots[-1].price if snapshots else None

    if not baseline or not peak or not final:
        return None

    peak_return = (peak - baseline) / baseline if baseline else None
    final_return = (final - baseline) / baseline if baseline else None
    is_hickup = classify_hickup(baseline, peak, final)

    return EventOutcome(
        event_id=event.id,
        baseline_price=baseline,
        peak_return=peak_return,
        final_return=final_return,
        abnormal_return=final_return,  # Später: vs. Index gerechnet
        is_hickup=is_hickup,
    )
