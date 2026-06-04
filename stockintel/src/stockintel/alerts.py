"""Alert-System: Benachrichtigungen über wichtige Events.

Phase 5: Email, Slack, oder Log-basierte Alerts.
Für jetzt: Log-basiert + Email-Scaffold.
"""

from __future__ import annotations

import logging
import os
from abc import ABC, abstractmethod
from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import select

from stockintel.db.models import Action, Company, Recommendation

if TYPE_CHECKING:
    from stockintel.db.database import Database

logger = logging.getLogger(__name__)


class Alert(ABC):
    """Base-Klasse für Alert-Handler."""

    @abstractmethod
    def send(self, subject: str, message: str) -> None:
        """Sendet einen Alert."""
        pass


class LogAlert(Alert):
    """Logging-basierter Alert (Development)."""

    def send(self, subject: str, message: str) -> None:
        logger.warning(f"[ALERT] {subject}: {message}")


class EmailAlert(Alert):
    """Email-basierter Alert (Scaffold für später)."""

    def __init__(self, smtp_host: str = "", smtp_port: int = 587, from_addr: str = "", to_addr: str = ""):
        self.smtp_host = smtp_host or os.getenv("STOCKINTEL_SMTP_HOST", "smtp.gmail.com")
        self.smtp_port = smtp_port or int(os.getenv("STOCKINTEL_SMTP_PORT", "587"))
        self.from_addr = from_addr or os.getenv("STOCKINTEL_EMAIL_FROM", "")
        self.to_addr = to_addr or os.getenv("STOCKINTEL_EMAIL_TO", "")

    def send(self, subject: str, message: str) -> None:
        """Sendet Email (Scaffold: loggt nur)."""
        if not self.from_addr or not self.to_addr:
            logger.warning(f"Email alert skipped (no config): {subject}")
            return
        # TODO: SMTP-Integration
        logger.info(f"[EMAIL ALERT] {subject}: {message}")


class SlackAlert(Alert):
    """Slack-basierter Alert (Scaffold für später)."""

    def __init__(self, webhook_url: str = ""):
        self.webhook_url = webhook_url or os.getenv("STOCKINTEL_SLACK_WEBHOOK", "")

    def send(self, subject: str, message: str) -> None:
        """Sendet Slack Message (Scaffold: loggt nur)."""
        if not self.webhook_url:
            logger.warning(f"Slack alert skipped (no config): {subject}")
            return
        # TODO: Slack webhook integration
        logger.info(f"[SLACK ALERT] {subject}: {message}")


class AlertManager:
    """Verwaltet Alert-Handler und triggert Benachrichtigungen."""

    def __init__(self, handlers: list[Alert] | None = None):
        self.handlers = handlers or [LogAlert()]

    def send(self, subject: str, message: str) -> None:
        """Sendet Alert an alle Handler."""
        for handler in self.handlers:
            try:
                handler.send(subject, message)
            except Exception as e:
                logger.error(f"Alert handler failed: {e}")

    def alert_high_relevance_signal(self, db: Database, threshold: int = 70) -> None:
        """Alertet Signals mit hoher Relevanz."""
        from stockintel.db.models import Signal

        with db.session() as session:
            high_signals = session.scalars(
                select(Signal)
                .where(Signal.relevance >= threshold)
                .order_by(Signal.relevance.desc())
                .limit(5)
            ).all()

            if high_signals:
                signal_list = ", ".join(
                    [f"{s.company.ticker} (rel={s.relevance})" for s in high_signals]
                )
                self.send(
                    "High-Relevance Signals",
                    f"Top signals: {signal_list}",
                )

    def alert_buy_recommendation(self, db: Database) -> None:
        """Alertet BUY-Recommendations."""
        with db.session() as session:
            buys = session.scalars(
                select(Recommendation)
                .where(Recommendation.action == Action.BUY)
                .order_by(Recommendation.confidence.desc())
            ).all()

            if buys:
                buy_list = ", ".join([f"{r.company.ticker} (conf={r.confidence:.2f})" for r in buys])
                self.send(
                    "BUY Recommendations",
                    f"Companies to buy: {buy_list}",
                )

    def alert_sell_recommendation(self, db: Database) -> None:
        """Alertet SELL-Recommendations."""
        with db.session() as session:
            sells = session.scalars(
                select(Recommendation)
                .where(Recommendation.action == Action.SELL)
                .order_by(Recommendation.confidence.desc())
            ).all()

            if sells:
                sell_list = ", ".join([f"{r.company.ticker} (conf={r.confidence:.2f})" for r in sells])
                self.send(
                    "SELL Recommendations",
                    f"Companies to sell: {sell_list}",
                )


def create_alert_manager() -> AlertManager:
    """Erstellt AlertManager basierend auf Environment."""
    handlers: list[Alert] = [LogAlert()]

    if os.getenv("STOCKINTEL_SLACK_WEBHOOK"):
        handlers.append(SlackAlert())

    if os.getenv("STOCKINTEL_EMAIL_FROM"):
        handlers.append(EmailAlert())

    return AlertManager(handlers)
