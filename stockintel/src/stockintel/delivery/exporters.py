"""Export-Funktionen für StockIntel Daten: CSV, JSON, TSV."""

from __future__ import annotations

import csv
import json
from io import StringIO
from typing import TYPE_CHECKING

from sqlalchemy import select
from sqlalchemy.orm import joinedload

from stockintel.db.models import Company, Event, EventOutcome, Recommendation, Signal

if TYPE_CHECKING:
    from stockintel.db.database import Database


def export_signals_csv(db: Database) -> str:
    """Exportiert alle Signals als CSV."""
    output = StringIO()
    writer = csv.writer(output)

    # Header
    writer.writerow([
        "ticker", "relevance", "direction", "confidence",
        "impact", "horizon", "title", "published_at", "created_at"
    ])

    with db.session() as session:
        signals = session.execute(
            select(Signal, Company.ticker)
            .join(Company, Signal.company_id == Company.id)
            .options(joinedload(Signal.raw_item))
            .order_by(Signal.created_at.desc())
        ).all()

        for signal, ticker in signals:
            writer.writerow([
                ticker,
                signal.relevance,
                signal.direction.value,
                signal.confidence,
                signal.impact.value,
                signal.horizon.value,
                (signal.raw_item.title or "")[:100] if signal.raw_item else "",
                signal.raw_item.published_at.isoformat() if signal.raw_item and signal.raw_item.published_at else "",
                signal.created_at.isoformat(),
            ])

    return output.getvalue()


def export_events_csv(db: Database) -> str:
    """Exportiert alle Events mit Outcomes als CSV."""
    output = StringIO()
    writer = csv.writer(output)

    # Header
    writer.writerow([
        "ticker", "event_type", "peak_return", "final_return",
        "abnormal_return", "is_hickup", "is_anomaly", "created_at"
    ])

    with db.session() as session:
        events = session.execute(
            select(Event, Company.ticker, EventOutcome)
            .join(Company, Event.company_id == Company.id)
            .outerjoin(EventOutcome, EventOutcome.event_id == Event.id)
            .order_by(Event.created_at.desc())
        ).all()

        for event, ticker, outcome in events:
            writer.writerow([
                ticker,
                event.event_type.value,
                outcome.peak_return if outcome else "",
                outcome.final_return if outcome else "",
                outcome.abnormal_return if outcome else "",
                "yes" if outcome and outcome.is_hickup else "",
                "yes" if outcome and outcome.is_anomaly else "",
                event.created_at.isoformat(),
            ])

    return output.getvalue()


def export_recommendations_json(db: Database) -> str:
    """Exportiert alle Recommendations als JSON."""
    with db.session() as session:
        recommendations = session.execute(
            select(Recommendation, Company.ticker, Company.name, Company.sector)
            .join(Company, Recommendation.company_id == Company.id)
        ).all()

        data = [
            {
                "ticker": row[1],
                "name": row[2],
                "sector": row[3],
                "action": row[0].action.value,
                "confidence": row[0].confidence,
                "score": row[0].score,
                "rationale": row[0].rationale,
                "created_at": row[0].created_at.isoformat(),
            }
            for row in recommendations
        ]

    return json.dumps(data, indent=2)


def export_portfolio_snapshot(db: Database) -> str:
    """Exportiert einen Portfolio-Snapshot (top picks pro sector)."""
    with db.session() as session:
        # Top recommendation pro sektor
        recommendations = session.execute(
            select(Recommendation, Company.ticker, Company.name, Company.sector)
            .join(Company, Recommendation.company_id == Company.id)
            .order_by(Company.sector, Recommendation.confidence.desc())
        ).all()

        snapshot = {}
        for rec, ticker, name, sector in recommendations:
            if sector not in snapshot:
                snapshot[sector] = {
                    "ticker": ticker,
                    "name": name,
                    "action": rec.action.value,
                    "confidence": rec.confidence,
                    "rationale": rec.rationale,
                }

        return json.dumps(snapshot, indent=2)
