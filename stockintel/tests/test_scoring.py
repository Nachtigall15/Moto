"""Tests für Buy/Hold/Sell Scoring."""

import pytest

from stockintel.analysis.scoring import score_company
from stockintel.db.models import Action, Direction, Horizon, Impact, Signal


def test_score_company_all_positive():
    """Alle positive Signals -> BUY."""
    signals = [
        Signal(
            raw_item_id=1, company_id=1,
            relevance=80, direction=Direction.POSITIVE, impact=Impact.HIGH,
            horizon=Horizon.WEEKS, confidence=0.9,
        ),
        Signal(
            raw_item_id=2, company_id=1,
            relevance=70, direction=Direction.POSITIVE, impact=Impact.MEDIUM,
            horizon=Horizon.DAYS, confidence=0.8,
        ),
    ]
    action, confidence, rationale = score_company(signals)
    assert action == Action.BUY
    assert confidence > 0.5
    assert "positive" in rationale.lower()


def test_score_company_all_negative():
    """Alle negative Signals -> SELL."""
    signals = [
        Signal(
            raw_item_id=1, company_id=1,
            relevance=80, direction=Direction.NEGATIVE, impact=Impact.HIGH,
            horizon=Horizon.WEEKS, confidence=0.9,
        ),
        Signal(
            raw_item_id=2, company_id=1,
            relevance=70, direction=Direction.NEGATIVE, impact=Impact.MEDIUM,
            horizon=Horizon.DAYS, confidence=0.8,
        ),
    ]
    action, confidence, rationale = score_company(signals)
    assert action == Action.SELL
    assert confidence > 0.5
    assert "negative" in rationale.lower()


def test_score_company_mixed():
    """Perfectly balanced Mixed Signals -> HOLD."""
    signals = [
        Signal(
            raw_item_id=1, company_id=1,
            relevance=60, direction=Direction.POSITIVE, impact=Impact.MEDIUM,
            horizon=Horizon.WEEKS, confidence=0.75,
        ),
        Signal(
            raw_item_id=2, company_id=1,
            relevance=60, direction=Direction.NEGATIVE, impact=Impact.MEDIUM,
            horizon=Horizon.DAYS, confidence=0.75,
        ),
    ]
    action, confidence, rationale = score_company(signals)
    assert action == Action.HOLD


def test_score_company_empty():
    """Keine Signals -> HOLD mit Confidence 0."""
    signals = []
    action, confidence, rationale = score_company(signals)
    assert action == Action.HOLD
    assert confidence == 0.0


def test_score_company_impact_weighting():
    """High Impact wird höher gewichtet."""
    high_impact = [
        Signal(
            raw_item_id=1, company_id=1,
            relevance=60, direction=Direction.POSITIVE, impact=Impact.HIGH,
            horizon=Horizon.WEEKS, confidence=0.8,
        ),
    ]
    low_impact = [
        Signal(
            raw_item_id=2, company_id=1,
            relevance=60, direction=Direction.POSITIVE, impact=Impact.LOW,
            horizon=Horizon.WEEKS, confidence=0.8,
        ),
    ]
    action_high, conf_high, _ = score_company(high_impact)
    action_low, conf_low, _ = score_company(low_impact)

    assert action_high == Action.BUY
    # High impact sollte höhere Confidence geben
    assert conf_high >= conf_low
