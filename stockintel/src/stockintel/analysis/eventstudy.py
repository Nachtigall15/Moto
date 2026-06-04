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
import logging
import re
from dataclasses import dataclass
from typing import TYPE_CHECKING

from sqlalchemy import desc, select
from sqlalchemy.orm import joinedload

from stockintel.analysis.prices import (
    current_price,
    fetch_history,
    parse_horizon,
    price_at_or_after,
    price_at_or_before,
)
from stockintel.db.models import (
    Direction,
    Event,
    EventOutcome,
    EventSnapshot,
    EventType,
    ReactionProfile,
    Signal,
)

if TYPE_CHECKING:
    from stockintel.config import Settings
    from stockintel.db.database import Database

logger = logging.getLogger(__name__)

DEFAULT_HORIZONS = ["1h", "4h", "1d", "3d", "1w", "1m"]
DEFAULT_BENCHMARK = "SPY"
# Pseudo-Horizont für den Basiskurs bei t0 (Offset 0). Wird als eigener
# Snapshot abgelegt, damit die Baseline unabhängig vom kleinsten Mess-Horizont
# korrekt ist (relevant bei reinen Tagesdaten, wo 1h/4h auf t0 zurückfallen).
BASELINE_HORIZON = "t0"


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


DEFAULT_REVERSAL_RATIO = 0.6   # Anteil der Spitzenbewegung, der zurückkommt
DEFAULT_MIN_SPIKE = 0.05       # Mindest-Spike (5%), damit Rauschen kein Hickup ist


def is_hickup_from_returns(
    peak_return: float | None,
    final_return: float | None,
    reversal_ratio: float = DEFAULT_REVERSAL_RATIO,
    min_spike: float = DEFAULT_MIN_SPIKE,
) -> bool:
    """Hickup-Regel auf Renditen-Basis (Strohfeuer).

    Ein Hickup liegt vor, wenn es einen nennenswerten Spike gab
    (``peak_return >= min_spike``) und davon mindestens ``reversal_ratio`` wieder
    abgegeben wurde. ``reversal_ratio`` entspricht ``event_study.hickup_reversal_ratio``.
    """
    if peak_return is None or final_return is None:
        return False
    if peak_return < min_spike:
        return False
    given_back = peak_return - final_return
    return given_back >= reversal_ratio * peak_return


def classify_hickup(
    baseline_price: float | None,
    peak_price: float | None,
    final_price: float | None,
    reversal_ratio: float = DEFAULT_REVERSAL_RATIO,
    min_spike: float = DEFAULT_MIN_SPIKE,
) -> bool:
    """Erkennt Hickup (Spike + Rückkehr) aus Kursen.

    Rechnet Baseline/Peak/Final in Renditen um und wendet
    :func:`is_hickup_from_returns` an. Fehlende/0-Baseline -> kein Hickup.
    """
    if not all([baseline_price, peak_price, final_price]):
        return False
    if baseline_price == 0:
        return False

    peak_return = (peak_price - baseline_price) / baseline_price
    final_return = (final_price - baseline_price) / baseline_price
    return is_hickup_from_returns(peak_return, final_return, reversal_ratio, min_spike)


def _horizon_sort_key(snapshot: EventSnapshot) -> dt.timedelta:
    """Sortierschlüssel: tatsächliche Horizont-Dauer (nicht lexikalisch!).

    "1h" < "4h" < "1d" < "3d" < "1w" < "1m" — string-sortiert wäre die
    Reihenfolge falsch.
    """
    return parse_horizon(snapshot.horizon or "") or dt.timedelta(0)


def compute_event_outcome(
    event: Event,
    reversal_ratio: float = DEFAULT_REVERSAL_RATIO,
) -> EventOutcome | None:
    """Berechnet das Outcome aus Event-Snapshots.

    Liefert Baseline, Peak-Return, Final-Return, abnormale Rendite (vs.
    Benchmark) und das Hickup-Flag. Benötigt mindestens zwei verwertbare
    Kurs-Snapshots. Gibt ``None`` zurück, wenn die Datenlage nicht reicht.
    """
    snapshots = sorted(
        (s for s in (event.snapshots or []) if s.price),
        key=_horizon_sort_key,
    )
    if len(snapshots) < 2:
        return None

    baseline = snapshots[0].price
    final = snapshots[-1].price
    peak = max(s.price for s in snapshots)
    if not baseline:
        return None

    peak_return = (peak - baseline) / baseline
    final_return = (final - baseline) / baseline
    is_hickup = classify_hickup(baseline, peak, final, reversal_ratio=reversal_ratio)

    # Abnormale Rendite: Eigenbewegung minus Benchmark-Bewegung (Markt herausrechnen).
    abnormal_return = final_return
    bench_first = snapshots[0].benchmark_price
    bench_last = snapshots[-1].benchmark_price
    if bench_first and bench_last:
        bench_return = (bench_last - bench_first) / bench_first
        abnormal_return = final_return - bench_return

    return EventOutcome(
        event_id=event.id,
        baseline_price=baseline,
        peak_return=peak_return,
        final_return=final_return,
        abnormal_return=abnormal_return,
        is_hickup=is_hickup,
        notes=f"{len(snapshots)} Snapshots, Benchmark={'ja' if bench_first else 'nein'}",
    )


# --------------------------------------------------------------------------- #
# Snapshot-Befüllung & Treiber (yfinance-gestützt)
# --------------------------------------------------------------------------- #
def build_events_from_signals(db: Database, limit: int = 100) -> int:
    """Erzeugt Events aus aussagekräftigen Signals (relevance>=30, gerichtet).

    Idempotent: pro ``raw_item_id`` wird höchstens ein Event angelegt.
    Returns: Anzahl neu erzeugter Events.
    """
    created = 0
    with db.session() as session:
        signals = (
            session.scalars(
                select(Signal)
                .options(joinedload(Signal.raw_item))
                .where(Signal.relevance >= 30)
                .where(Signal.direction != Direction.NEUTRAL)
                .order_by(desc(Signal.relevance), desc(Signal.id))
                .limit(limit)
            ).all()
        )
        existing_items = set(session.scalars(select(Event.raw_item_id)).all())

        for sig in signals:
            if sig.raw_item_id in existing_items:
                continue
            item = sig.raw_item
            event_type = classify_event_type(sig, item.title if item else None,
                                              item.body if item else None)
            t0 = (item.published_at if item else None) or dt.datetime.now(dt.timezone.utc)
            session.add(
                Event(
                    company_id=sig.company_id,
                    raw_item_id=sig.raw_item_id,
                    event_type=event_type,
                    t0=t0,
                    summary=f"{sig.direction.value.upper()}: {((item.title if item else '') or '')[:100]}",
                )
            )
            existing_items.add(sig.raw_item_id)
            created += 1

        session.commit()
    return created


def backfill_event_snapshots(
    db: Database,
    event_id: int,
    horizons: list[str] | None = None,
    benchmark: str | None = DEFAULT_BENCHMARK,
) -> int:
    """Füllt fehlende ``EventSnapshot``-Zeilen eines Events aus yfinance-Historie.

    Lädt Tageshistorie für Ticker (+ Benchmark) um t0 herum und sampled an jedem
    Horizont den Kurs at-or-after. Zusätzlich wird ein Baseline-Snapshot bei t0
    (Kurs at-or-before t0) abgelegt. Idempotent über ``UniqueConstraint(event_id,
    horizon)`` — bereits vorhandene Horizonte werden übersprungen.

    Bei reinen Tagesdaten lösen Intraday-Horizonte (1h/4h) auf den nächsten
    Tagesschluss auf (dokumentierte Näherung; Stunden-Granularität bietet
    yfinance historisch nur ~60 Tage zurück).

    Returns: Anzahl neu geschriebener Snapshots (0, wenn keine Kursdaten).
    """
    horizons = horizons or DEFAULT_HORIZONS
    with db.session() as session:
        event = session.get(Event, event_id)
        if event is None:
            return 0
        ticker = event.company.ticker if event.company else None
        if not ticker:
            return 0

        existing = set(
            session.scalars(
                select(EventSnapshot.horizon).where(EventSnapshot.event_id == event_id)
            ).all()
        )
        missing = [h for h in horizons if h not in existing]
        need_baseline = BASELINE_HORIZON not in existing
        if not missing and not need_baseline:
            return 0

        t0 = event.t0
        if t0.tzinfo is None:
            t0 = t0.replace(tzinfo=dt.timezone.utc)

        # Fenster: ab Tag vor t0 bis zum längsten Horizont (+2 Tage Puffer).
        max_delta = max((parse_horizon(h) or dt.timedelta(0) for h in missing),
                        default=dt.timedelta(days=1))
        start = t0 - dt.timedelta(days=1)
        end = t0 + max_delta + dt.timedelta(days=2)

        history = fetch_history(ticker, start, end, interval="1d")
        if not history:
            return 0
        bench_history = fetch_history(benchmark, start, end, interval="1d") if benchmark else []

        written = 0

        # Baseline-Snapshot bei t0 (Kurs at-or-before t0).
        if need_baseline:
            base_point = price_at_or_before(history, t0) or price_at_or_after(history, t0)
            if base_point is not None:
                base_bench = price_at_or_before(bench_history, t0) or price_at_or_after(bench_history, t0)
                session.add(
                    EventSnapshot(
                        event_id=event_id,
                        horizon=BASELINE_HORIZON,
                        price=base_point.close,
                        benchmark_price=base_bench.close if base_bench else None,
                        captured_at=base_point.ts,
                    )
                )
                written += 1

        for h in missing:
            delta = parse_horizon(h)
            if delta is None:
                continue
            target = t0 + delta
            point = price_at_or_after(history, target)
            if point is None:
                continue
            bench_point = price_at_or_after(bench_history, target) if bench_history else None
            session.add(
                EventSnapshot(
                    event_id=event_id,
                    horizon=h,
                    price=point.close,
                    benchmark_price=bench_point.close if bench_point else None,
                    captured_at=point.ts,
                )
            )
            written += 1
        session.commit()
        return written


def capture_due_snapshots(
    db: Database,
    settings: Settings | None = None,
    now: dt.datetime | None = None,
    max_age_days: int = 35,
    fresh_window_hours: float = 2.0,
    price_fn=None,
) -> int:
    """Forward-Tracking: erfasst gerade fällig gewordene Horizonte mit Live-Kurs.

    Für jedes Event im Tracking-Fenster (t0 jünger als ``max_age_days``) wird
    jeder konfigurierte Horizont (inkl. Baseline bei t0), dessen Zielzeit soeben
    erreicht wurde (``now - fresh_window <= target <= now``) und der noch fehlt,
    mit dem aktuellen Kurs als Snapshot abgelegt. Das schmale Frische-Fenster
    sorgt für Intraday-Präzision (je Lauf wird nahe der echten Zielzeit gemessen);
    ältere, verpasste Horizonte überlässt es dem historischen Backfill.

    Idempotent über ``UniqueConstraint(event_id, horizon)``. ``price_fn`` (Callable
    ``ticker -> float|None``) ist für Tests injizierbar; Default ist der yfinance-
    Live-Kurs. Returns: Anzahl neu geschriebener Snapshots.
    """
    horizons, benchmark, _ = _event_study_config(settings)
    now = now or dt.datetime.now(dt.timezone.utc)
    price_fn = price_fn or current_price
    fresh = dt.timedelta(hours=fresh_window_hours)
    cutoff = now - dt.timedelta(days=max_age_days)

    price_cache: dict[str, float | None] = {}

    def cached(symbol: str | None) -> float | None:
        if not symbol:
            return None
        if symbol not in price_cache:
            price_cache[symbol] = price_fn(symbol)
        return price_cache[symbol]

    checks: list[tuple[str, dt.timedelta]] = [(BASELINE_HORIZON, dt.timedelta(0))]
    checks += [(h, parse_horizon(h)) for h in horizons if parse_horizon(h) is not None]

    written = 0
    with db.session() as session:
        events = (
            session.scalars(
                select(Event)
                .options(joinedload(Event.snapshots), joinedload(Event.company))
                .where(Event.t0 >= cutoff)
            )
            .unique()
            .all()
        )
        for event in events:
            ticker = event.company.ticker if event.company else None
            if not ticker:
                continue
            t0 = event.t0
            if t0.tzinfo is None:
                t0 = t0.replace(tzinfo=dt.timezone.utc)
            captured = {s.horizon for s in event.snapshots}

            for horizon, delta in checks:
                if horizon in captured:
                    continue
                target = t0 + delta
                if target > now or (now - target) > fresh:
                    continue  # noch nicht fällig oder zu alt (Backfill zuständig)
                price = cached(ticker)
                if price is None:
                    continue
                session.add(
                    EventSnapshot(
                        event_id=event.id,
                        horizon=horizon,
                        price=price,
                        benchmark_price=cached(benchmark),
                        captured_at=now,
                    )
                )
                captured.add(horizon)
                written += 1
        session.commit()
    return written


def persist_event_outcome(
    db: Database,
    event_id: int,
    reversal_ratio: float = DEFAULT_REVERSAL_RATIO,
) -> EventOutcome | None:
    """Berechnet das Outcome eines Events und schreibt/aktualisiert es (idempotent)."""
    with db.session() as session:
        event = session.scalar(
            select(Event)
            .options(joinedload(Event.snapshots), joinedload(Event.outcome))
            .where(Event.id == event_id)
        )
        if event is None:
            return None
        computed = compute_event_outcome(event, reversal_ratio=reversal_ratio)
        if computed is None:
            return None

        existing = event.outcome
        if existing:
            existing.baseline_price = computed.baseline_price
            existing.peak_return = computed.peak_return
            existing.final_return = computed.final_return
            existing.abnormal_return = computed.abnormal_return
            existing.is_hickup = computed.is_hickup
            existing.notes = computed.notes
            existing.computed_at = dt.datetime.now(dt.timezone.utc)
            result = existing
        else:
            session.add(computed)
            result = computed
        session.commit()
        session.refresh(result)
        return result


def run_event_study(
    db: Database,
    settings: Settings | None = None,
    limit: int = 100,
) -> dict[str, int]:
    """Treiber: Signals -> Events -> Snapshots (yfinance) -> Outcomes.

    Schritte:
      1. Aussagekräftige Signals zu Events verdichten.
      2. Je Event fehlende Kurs-Snapshots aus yfinance nachladen.
      3. Outcomes (Rendite, abnormal, Hickup) berechnen und persistieren.

    Robust ohne Marktdaten: Ohne yfinance/Netzwerk entstehen Events, aber keine
    Snapshots/Outcomes (Zähler bleiben 0).

    Returns: {events_created, snapshots_written, outcomes_computed, hickups,
    profiles_updated}.
    """
    horizons, benchmark, reversal_ratio = _event_study_config(settings)
    stats = {
        "events_created": 0, "snapshots_written": 0,
        "outcomes_computed": 0, "hickups": 0, "profiles_updated": 0,
    }

    stats["events_created"] = build_events_from_signals(db, limit=limit)

    with db.session() as session:
        event_ids = list(
            session.scalars(select(Event.id).order_by(desc(Event.t0)).limit(limit)).all()
        )

    for event_id in event_ids:
        written = backfill_event_snapshots(db, event_id, horizons, benchmark)
        stats["snapshots_written"] += written
        outcome = persist_event_outcome(db, event_id, reversal_ratio=reversal_ratio)
        if outcome is not None:
            stats["outcomes_computed"] += 1
            if outcome.is_hickup:
                stats["hickups"] += 1

    # Basisraten je Ereignistyp aus allen Outcomes aktualisieren.
    profile_stats = aggregate_reaction_profiles(db)
    stats["profiles_updated"] = profile_stats["profiles_updated"]

    logger.info("Event-Study: %s", stats)
    return stats


def aggregate_reaction_profiles(db: Database) -> dict[str, int]:
    """Aggregiert alle ``EventOutcome``s je ``EventType`` zu ``ReactionProfile``.

    Berechnet pro Ereignistyp: Stichprobengröße, durchschnittlicher Peak-/Final-
    Return und Hickup-Quote. Diese Basisraten dienen als historischer Kontext
    (Konfidenz, Buy/Hold/Sell). Idempotent: ein Profil je EventType (Upsert).

    Returns: {profiles_updated, events_aggregated}.
    """
    from collections import defaultdict

    stats = {"profiles_updated": 0, "events_aggregated": 0}
    with db.session() as session:
        rows = session.execute(
            select(
                Event.event_type,
                EventOutcome.peak_return,
                EventOutcome.final_return,
                EventOutcome.is_hickup,
            ).join(EventOutcome, EventOutcome.event_id == Event.id)
        ).all()

        buckets: dict[EventType, list[tuple]] = defaultdict(list)
        for event_type, peak, final, hickup in rows:
            buckets[event_type].append((peak, final, hickup))

        for event_type, items in buckets.items():
            n = len(items)
            peaks = [p for p, _, _ in items if p is not None]
            finals = [f for _, f, _ in items if f is not None]
            hickups = sum(1 for _, _, h in items if h)

            avg_peak = sum(peaks) / len(peaks) if peaks else None
            avg_final = sum(finals) / len(finals) if finals else None
            hickup_rate = hickups / n if n else None

            profile = session.scalar(
                select(ReactionProfile).where(ReactionProfile.event_type == event_type)
            )
            if profile:
                profile.sample_size = n
                profile.avg_peak_return = avg_peak
                profile.avg_final_return = avg_final
                profile.hickup_rate = hickup_rate
                profile.updated_at = dt.datetime.now(dt.timezone.utc)
            else:
                session.add(
                    ReactionProfile(
                        event_type=event_type,
                        sample_size=n,
                        avg_peak_return=avg_peak,
                        avg_final_return=avg_final,
                        hickup_rate=hickup_rate,
                    )
                )
            stats["profiles_updated"] += 1
            stats["events_aggregated"] += n

        session.commit()
    return stats


def _event_study_config(settings: Settings | None) -> tuple[list[str], str | None, float]:
    """Liest Horizonte, Benchmark und Hickup-Reversal-Ratio aus den Settings."""
    if settings is None:
        return DEFAULT_HORIZONS, DEFAULT_BENCHMARK, DEFAULT_REVERSAL_RATIO
    cfg = settings.section("event_study")
    horizons = cfg.get("horizons") if isinstance(cfg.get("horizons"), list) else None
    benchmark = cfg.get("index_benchmark") or DEFAULT_BENCHMARK
    ratio = cfg.get("hickup_reversal_ratio")
    reversal_ratio = float(ratio) if isinstance(ratio, (int, float)) else DEFAULT_REVERSAL_RATIO
    return (horizons or DEFAULT_HORIZONS), benchmark, reversal_ratio
