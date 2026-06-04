"""Tests für Event-Study Modul."""

import pytest

from stockintel.analysis.eventstudy import classify_event_type, classify_hickup
from stockintel.db.models import Direction, Horizon, Impact, Signal, EventType


def test_classify_hickup_detects_reversal():
    """Hickup: +6% Spike, dann +2% final (< 6%-3%=3%)."""
    baseline = 100.0
    peak = 106.0      # +6% (> 5%)
    final = 102.0     # +2% (< 6%-3%=3%)
    assert classify_hickup(baseline, peak, final) is True


def test_classify_hickup_sustained_move_is_not_hickup():
    """Nachhaltige Bewegung: +5% bleibt +4%."""
    baseline = 100.0
    peak = 105.0
    final = 104.0     # Keine Rückkehr
    assert classify_hickup(baseline, peak, final) is False


def test_classify_hickup_ignores_negative_peak():
    """Negative Bewegung wird nicht als Hickup erkannt."""
    baseline = 100.0
    peak = 97.0       # -3%
    final = 96.0
    assert classify_hickup(baseline, peak, final) is False


def test_classify_hickup_missing_data():
    """Missing price data returns False."""
    assert classify_hickup(None, 105.0, 102.0) is False
    assert classify_hickup(100.0, None, 102.0) is False
    assert classify_hickup(100.0, 105.0, None) is False
    assert classify_hickup(0, 105.0, 102.0) is False


def test_classify_event_type_earnings():
    """Earnings wird erkannt."""
    from stockintel.db.models import Direction, Horizon, Impact

    signal = Signal(
        raw_item_id=1, company_id=1,
        relevance=55, direction=Direction.POSITIVE, impact=Impact.HIGH,
        horizon=Horizon.DAYS, confidence=0.8,
    )
    event_type = classify_event_type(signal, "Apple Q3 Earnings Beat", "Strong revenue growth")
    assert event_type == EventType.EARNINGS


def test_classify_event_type_fda():
    """FDA Approval wird erkannt."""
    from stockintel.db.models import Direction, Horizon, Impact

    signal = Signal(
        raw_item_id=1, company_id=1,
        relevance=75, direction=Direction.POSITIVE, impact=Impact.HIGH,
        horizon=Horizon.MONTHS, confidence=0.9,
    )
    event_type = classify_event_type(signal, "FDA Approval", "Drug cleared for market")
    assert event_type == EventType.FDA


def test_classify_event_type_too_low_relevance():
    """Relevance-Threshold wird beachtet."""
    from stockintel.db.models import Direction, Horizon, Impact

    signal = Signal(
        raw_item_id=1, company_id=1,
        relevance=25, direction=Direction.POSITIVE, impact=Impact.LOW,
        horizon=Horizon.DAYS, confidence=0.5,
    )
    event_type = classify_event_type(signal, "FDA filing", "preliminary")
    # FDA needs relevance >= 60, so should fall back to OTHER
    assert event_type == EventType.OTHER


def test_classify_event_type_fallback_other():
    """Unknown pattern returns OTHER."""
    from stockintel.db.models import Direction, Horizon, Impact

    signal = Signal(
        raw_item_id=1, company_id=1,
        relevance=50, direction=Direction.NEUTRAL, impact=Impact.LOW,
        horizon=Horizon.DAYS, confidence=0.6,
    )
    event_type = classify_event_type(signal, "Random news", "no keywords match")
    assert event_type == EventType.OTHER
