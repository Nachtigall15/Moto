"""Custom Alert Rules: Benutzer können Regeln definieren für Benachrichtigungen.

Beispiele:
- Alert wenn Signal für NVDA mit Relevanz > 80
- Alert wenn Event mit abnormal_return < -5%
- Alert wenn neue Buy-Recommendation für Tech-Sektor
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import TYPE_CHECKING

from sqlalchemy import select

from stockintel.db.models import Company, Event, EventOutcome, Recommendation, Signal

if TYPE_CHECKING:
    from stockintel.db.database import Database


class AlertCondition(str, Enum):
    """Bedingungstypen für Alerts."""
    SIGNAL_RELEVANCE = "signal_relevance"  # Signal mit min Relevanz
    SIGNAL_DIRECTION = "signal_direction"  # Signal mit bestimmter Richtung
    EVENT_RETURN = "event_return"  # Event mit abnormal return > threshold
    RECOMMENDATION_ACTION = "recommendation_action"  # Neue Buy/Sell Empfehlung
    ANOMALY_DETECTED = "anomaly_detected"  # Anomalie erkannt


@dataclass
class AlertRule:
    """Definition einer Alert-Regel."""
    name: str
    condition: AlertCondition
    ticker: str | None = None  # None = alle Tickers
    threshold: float | None = None  # z.B. relevance >= 80, return < -0.05
    description: str | None = None

    def matches_signal(self, signal: Signal, company_ticker: str) -> bool:
        """Prüft ob Signal gegen diese Regel matched."""
        if self.condition not in [AlertCondition.SIGNAL_RELEVANCE, AlertCondition.SIGNAL_DIRECTION]:
            return False

        # Ticker-Filter
        if self.ticker and company_ticker.upper() != self.ticker.upper():
            return False

        # Relevance-Check
        if self.condition == AlertCondition.SIGNAL_RELEVANCE:
            if self.threshold is not None:
                return signal.relevance >= self.threshold
            return True

        # Direction-Check
        if self.condition == AlertCondition.SIGNAL_DIRECTION:
            if self.threshold == "positive":
                return signal.direction.value == "positive"
            elif self.threshold == "negative":
                return signal.direction.value == "negative"
            return True

        return False

    def matches_event(self, event: Event, outcome: EventOutcome, company_ticker: str) -> bool:
        """Prüft ob Event gegen diese Regel matched."""
        if self.condition != AlertCondition.EVENT_RETURN:
            return False

        if self.ticker and company_ticker.upper() != self.ticker.upper():
            return False

        if outcome and outcome.abnormal_return is not None and self.threshold is not None:
            # threshold = -0.05 bedeutet: alert wenn return < -0.05 (Absturz)
            return outcome.abnormal_return < self.threshold

        return False

    def matches_recommendation(
        self, recommendation: "Recommendation", company_ticker: str
    ) -> bool:
        """Prüft ob Recommendation gegen diese Regel matched."""
        if self.condition != AlertCondition.RECOMMENDATION_ACTION:
            return False

        if self.ticker and company_ticker.upper() != self.ticker.upper():
            return False

        if self.threshold in ["buy", "sell", "hold"]:
            return recommendation.action.value == self.threshold

        return True


def evaluate_rules(
    db: Database, rules: list[AlertRule]
) -> dict[str, list[dict]]:
    """Evaluiert alle Rules gegen aktuelle Daten.

    Returns:
        {rule_name: [matching_items]}
    """
    alerts_triggered = {rule.name: [] for rule in rules}

    with db.session() as session:
        # Evaluate SIGNAL rules
        signal_rules = [r for r in rules if r.condition in [
            AlertCondition.SIGNAL_RELEVANCE,
            AlertCondition.SIGNAL_DIRECTION,
        ]]

        if signal_rules:
            signals = session.execute(
                select(Signal, Company.ticker)
                .join(Company, Signal.company_id == Company.id)
            ).all()

            for signal, ticker in signals:
                for rule in signal_rules:
                    if rule.matches_signal(signal, ticker):
                        alerts_triggered[rule.name].append({
                            "type": "signal",
                            "ticker": ticker,
                            "relevance": signal.relevance,
                            "direction": signal.direction.value,
                        })

        # Evaluate EVENT rules
        event_rules = [r for r in rules if r.condition == AlertCondition.EVENT_RETURN]

        if event_rules:
            events = session.execute(
                select(Event, Company.ticker, EventOutcome)
                .join(Company, Event.company_id == Company.id)
                .outerjoin(EventOutcome, EventOutcome.event_id == Event.id)
                .where(EventOutcome.abnormal_return.isnot(None))
            ).all()

            for event, ticker, outcome in events:
                for rule in event_rules:
                    if rule.matches_event(event, outcome, ticker):
                        alerts_triggered[rule.name].append({
                            "type": "event",
                            "ticker": ticker,
                            "event_type": event.event_type.value,
                            "abnormal_return": outcome.abnormal_return if outcome else None,
                        })

        # Evaluate RECOMMENDATION rules
        rec_rules = [r for r in rules if r.condition == AlertCondition.RECOMMENDATION_ACTION]

        if rec_rules:
            recommendations = session.execute(
                select(Recommendation, Company.ticker)
                .join(Company, Recommendation.company_id == Company.id)
            ).all()

            for rec, ticker in recommendations:
                for rule in rec_rules:
                    if rule.matches_recommendation(rec, ticker):
                        alerts_triggered[rule.name].append({
                            "type": "recommendation",
                            "ticker": ticker,
                            "action": rec.action.value,
                            "confidence": rec.confidence,
                        })

    return {k: v for k, v in alerts_triggered.items() if v}


# Example rules
DEFAULT_RULES = [
    AlertRule(
        name="High Relevance Signals",
        condition=AlertCondition.SIGNAL_RELEVANCE,
        threshold=85,
        description="Alert bei Signals mit Relevanz >= 85%",
    ),
    AlertRule(
        name="Crash Detection",
        condition=AlertCondition.EVENT_RETURN,
        threshold=-0.10,
        description="Alert wenn abnormal return < -10% (Absturz)",
    ),
    AlertRule(
        name="Buy Recommendations",
        condition=AlertCondition.RECOMMENDATION_ACTION,
        threshold="buy",
        description="Alert bei neuen Buy-Recommendations",
    ),
]
