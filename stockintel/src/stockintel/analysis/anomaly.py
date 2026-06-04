"""ML-basierte Anomalieerkennung für unerwartete Event-Reactions.

Statistische Outlier-Detection (Z-Score) zur Identifikation unerwarteter
Marktbewegungen nach Events. Markiert Events, deren abnormale Renditen
statistisch signifikant vom Durchschnitt abweichen.
"""

from __future__ import annotations

import statistics
from typing import TYPE_CHECKING

from sqlalchemy import select, update

from stockintel.db.models import Event, EventOutcome

if TYPE_CHECKING:
    from stockintel.db.database import Database


def detect_return_anomalies(db: Database, z_threshold: float = 2.0) -> dict[str, int]:
    """Erkennt Events mit statistisch unerwarteten Returns (Outlier).

    Args:
        db: Database connection
        z_threshold: Z-Score Schwelle (default 2.0 = ~95% confidence)

    Returns:
        {anomalies_detected, outcomes_marked}
    """
    with db.session() as session:
        # Alle Outcomes mit abnormalen Renditen laden
        outcomes = session.execute(
            select(EventOutcome).where(EventOutcome.abnormal_return.isnot(None))
        ).scalars().all()

        if len(outcomes) < 3:
            return {"anomalies_detected": 0, "outcomes_marked": 0}

        # Berechne Mittelwert und Standardabweichung
        returns = [o.abnormal_return for o in outcomes]
        mean = statistics.mean(returns)
        try:
            stdev = statistics.stdev(returns)
        except statistics.StatisticsError:
            stdev = 0

        if stdev == 0:
            return {"anomalies_detected": 0, "outcomes_marked": 0}

        # Markiere Outlier (Z-Score > threshold)
        anomalies = 0
        for outcome in outcomes:
            z_score = abs((outcome.abnormal_return - mean) / stdev)
            is_anomaly = z_score > z_threshold

            if is_anomaly and not outcome.is_anomaly:
                session.execute(
                    update(EventOutcome)
                    .where(EventOutcome.id == outcome.id)
                    .values(is_anomaly=True)
                )
                anomalies += 1

        session.commit()
        return {"anomalies_detected": anomalies, "outcomes_marked": anomalies}


def estimate_event_type_risk(
    db: Database, event_type_enum
) -> float:
    """Schätzt durchschnittliches Risiko (Volatilität) für einen Event-Typ.

    Args:
        db: Database connection
        event_type_enum: Event type enum (z.B. EventType.EARNINGS)

    Returns:
        Standard deviation of abnormal returns for that type (risk level)
    """
    with db.session() as session:
        outcomes = session.execute(
            select(EventOutcome)
            .join(Event, EventOutcome.event_id == Event.id)
            .where(
                Event.event_type == event_type_enum,
                EventOutcome.abnormal_return.isnot(None),
            )
        ).scalars().all()

        if len(outcomes) < 2:
            return 0.0

        returns = [o.abnormal_return for o in outcomes]
        try:
            return statistics.stdev(returns)
        except statistics.StatisticsError:
            return 0.0


def flag_systematic_anomalies(db: Database, outlier_rate_threshold: float = 0.3):
    """Flags Event-Typen mit ungewöhnlich hoher Anomalienrate.

    Args:
        db: Database connection
        outlier_rate_threshold: % Anomalien, ab dem Typ als 'systematic' markiert

    Returns:
        {systematic_types, event_types_checked}
    """
    from stockintel.db.models import EventType

    systematic_types = []
    for event_type in EventType:
        with db.session() as session:
            all_outcomes = session.execute(
                select(EventOutcome)
                .join(Event, EventOutcome.event_id == Event.id)
                .where(Event.event_type == event_type)
            ).scalars().all()

            anomaly_count = sum(1 for o in all_outcomes if o.is_anomaly)
            if len(all_outcomes) > 0:
                anomaly_rate = anomaly_count / len(all_outcomes)
                if anomaly_rate > outlier_rate_threshold:
                    systematic_types.append(
                        {
                            "event_type": event_type.value,
                            "anomaly_rate": anomaly_rate,
                            "count": len(all_outcomes),
                        }
                    )

    return {
        "systematic_types": systematic_types,
        "event_types_checked": len(list(EventType)),
    }
