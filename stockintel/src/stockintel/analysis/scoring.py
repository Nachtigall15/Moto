"""Buy/Hold/Sell Scoring: Aggregation von Signals zu Empfehlungen.

Phase 4: Signals -> Recommendations (mit Konfidenz + Begründung).
Regelbasiert: Direction, Impact, Relevance, Konfidenz aggregieren.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import func, select

from stockintel.db.models import Action, Company, Direction, Impact, Recommendation, Signal

if TYPE_CHECKING:
    from stockintel.db.database import Database


def score_company(signals: list[Signal]) -> tuple[Action, float, str]:
    """Berechnet Buy/Hold/Sell aus einer Liste von Signals.

    Regelbasiert:
    - Positive Signals (direction=positive) erhoehen Score
    - Negative reduzieren Score
    - High Impact zählt doppelt
    - Relevance und Confidence gewichten

    Score -100..+100 -> Sell/Hold/Buy.
    Returns: (action, confidence, rationale).
    """
    if not signals:
        return Action.HOLD, 0.0, "Keine Signals vorhanden."

    score = 0.0
    total_weight = 0.0
    positive_count = 0
    negative_count = 0

    for sig in signals:
        # Weight: Relevance * Confidence
        weight = (sig.relevance or 0) / 100.0 * (sig.confidence or 0.5)
        total_weight += weight

        # Direction Score
        direction_val = {"positive": 1.0, "neutral": 0.0, "negative": -1.0}.get(
            sig.direction.value, 0.0
        )

        # Impact Multiplier
        impact_mult = {"low": 1.0, "medium": 1.5, "high": 2.0}.get(sig.impact.value, 1.0)

        signal_contribution = direction_val * weight * impact_mult
        score += signal_contribution

        if direction_val > 0:
            positive_count += 1
        elif direction_val < 0:
            negative_count += 1

    # Normalize Score zu -100..+100
    if total_weight > 0:
        score = (score / total_weight) * 100
    else:
        score = 0.0

    # Confidence: Anteil positive/negative + Gewicht
    signal_count = len(signals)
    agreement_ratio = max(positive_count, negative_count) / max(signal_count, 1)
    confidence = min(total_weight, 1.0) * agreement_ratio

    # Action: Score -> Buy/Hold/Sell
    if score > 20:
        action = Action.BUY
        rationale = f"{positive_count}/{signal_count} positive Signals, Score {score:.0f}"
    elif score < -20:
        action = Action.SELL
        rationale = f"{negative_count}/{signal_count} negative Signals, Score {score:.0f}"
    else:
        action = Action.HOLD
        rationale = f"Mixed Signals (Score {score:.0f}), abwarten"

    return action, confidence, rationale


def generate_recommendations(db: Database) -> dict[str, int]:
    """Generiert Buy/Hold/Sell Recommendations für alle Companies mit Signals.

    Idempotent: pro Company wird maximal eine aktuelle Recommendation angelegt
    (ältere werden nicht gelöscht, aber neue überschreiben).

    Returns: {recommendations_created, recommendations_updated}.
    """
    stats = {"recommendations_created": 0, "recommendations_updated": 0}

    with db.session() as session:
        # Companies mit Signals laden
        companies_with_signals = session.execute(
            select(Company).distinct()
            .join(Signal, Signal.company_id == Company.id)
            .order_by(Company.id)
        ).scalars().all()

        for company in companies_with_signals:
            signals = session.scalars(
                select(Signal).where(Signal.company_id == company.id)
            ).all()

            if not signals:
                continue

            action, confidence, rationale = score_company(signals)

            # Prüfe ob Recommendation bereits existiert (einfaches Update)
            existing = session.scalar(
                select(Recommendation).where(Recommendation.company_id == company.id)
            )

            if existing:
                existing.action = action
                existing.confidence = confidence
                existing.rationale = rationale
                stats["recommendations_updated"] += 1
            else:
                rec = Recommendation(
                    company_id=company.id,
                    action=action,
                    confidence=confidence,
                    rationale=rationale,
                )
                session.add(rec)
                stats["recommendations_created"] += 1

        session.commit()

    return stats
