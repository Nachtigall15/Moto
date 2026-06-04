"""Tests für Alert-System."""

import pytest

from stockintel.alerts import Alert, AlertManager, LogAlert, EmailAlert, SlackAlert


class MockAlert(Alert):
    """Mock Alert für Testing."""

    def __init__(self):
        self.messages: list[tuple[str, str]] = []

    def send(self, subject: str, message: str) -> None:
        self.messages.append((subject, message))


def test_log_alert():
    """LogAlert sendet."""
    alert = LogAlert()
    alert.send("Test", "Message")  # Sollte nicht crashen


def test_email_alert_without_config():
    """EmailAlert ohne Config."""
    alert = EmailAlert()
    alert.send("Test", "Message")  # Sollte nicht crashen (skipped)


def test_slack_alert_without_config():
    """SlackAlert ohne Config."""
    alert = SlackAlert()
    alert.send("Test", "Message")  # Sollte nicht crashen (skipped)


def test_alert_manager_single_handler():
    """AlertManager mit einem Handler."""
    mock = MockAlert()
    manager = AlertManager(handlers=[mock])
    manager.send("Subject", "Message")
    assert len(mock.messages) == 1
    assert mock.messages[0] == ("Subject", "Message")


def test_alert_manager_multiple_handlers():
    """AlertManager mit mehreren Handlern."""
    mock1 = MockAlert()
    mock2 = MockAlert()
    manager = AlertManager(handlers=[mock1, mock2])
    manager.send("Subject", "Message")
    assert len(mock1.messages) == 1
    assert len(mock2.messages) == 1


def test_alert_manager_handler_failure_continues():
    """AlertManager: Fehler eines Handlers stoppt nicht die anderen."""

    class FailingAlert(Alert):
        def send(self, subject: str, message: str) -> None:
            raise RuntimeError("Intentional failure")

    mock = MockAlert()
    manager = AlertManager(handlers=[FailingAlert(), mock])
    manager.send("Subject", "Message")  # Sollte nicht crashen
    assert len(mock.messages) == 1  # Zweiter Handler sollte trotzbaudem laufen
