"""Tests für Event-Study Modul."""

import datetime as dt

import pytest

from stockintel.analysis.eventstudy import (
    build_events_from_signals,
    classify_event_type,
    classify_hickup,
    compute_event_outcome,
)
from stockintel.db.database import Database
from stockintel.db.models import (
    Company,
    Direction,
    Event,
    EventSnapshot,
    EventType,
    Horizon,
    Impact,
    RawItem,
    Signal,
    Source,
)


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


# --------------------------------------------------------------------------- #
# Outcome-Berechnung
# --------------------------------------------------------------------------- #
def _snap(horizon, price, benchmark=None):
    return EventSnapshot(horizon=horizon, price=price, benchmark_price=benchmark)


def test_compute_outcome_orders_by_horizon_duration():
    """Snapshots werden nach Dauer (nicht lexikalisch) sortiert: 1h<1d<1w."""
    event = Event(id=1, company_id=1, t0=dt.datetime.now(dt.timezone.utc))
    # Absichtlich unsortiert + lexikalisch trügerisch (1w<1d als String).
    event.snapshots = [_snap("1w", 90.0), _snap("1h", 100.0), _snap("1d", 120.0)]
    outcome = compute_event_outcome(event)
    assert outcome is not None
    # Baseline = 1h (100), final = 1w (90), peak = 1d (120)
    assert outcome.baseline_price == 100.0
    assert outcome.peak_return == pytest.approx(0.20)
    assert outcome.final_return == pytest.approx(-0.10)


def test_compute_outcome_abnormal_return_vs_benchmark():
    """Abnormale Rendite = Eigenbewegung minus Benchmark-Bewegung."""
    event = Event(id=1, company_id=1, t0=dt.datetime.now(dt.timezone.utc))
    event.snapshots = [
        _snap("1h", 100.0, benchmark=400.0),
        _snap("1d", 110.0, benchmark=440.0),  # +10% Eigen, +10% Benchmark
    ]
    outcome = compute_event_outcome(event)
    assert outcome.final_return == pytest.approx(0.10)
    assert outcome.abnormal_return == pytest.approx(0.0)  # Marktbewegung herausgerechnet


def test_compute_outcome_needs_two_snapshots():
    event = Event(id=1, company_id=1, t0=dt.datetime.now(dt.timezone.utc))
    event.snapshots = [_snap("1h", 100.0)]
    assert compute_event_outcome(event) is None


def test_build_events_from_signals(tmp_path):
    """Aussagekräftige Signals werden zu Events; neutrale/leise ignoriert."""
    db = Database(f"sqlite:///{tmp_path/'t.db'}")
    db.create_all()
    with db.session() as session:
        src = Source(key="rss", name="RSS", kind="rss")
        comp = Company(ticker="NVDA", name="NVIDIA")
        session.add_all([src, comp])
        session.flush()
        item_hi = RawItem(source_id=src.id, external_id="a", title="NVDA earnings beat")
        item_lo = RawItem(source_id=src.id, external_id="b", title="meh")
        item_neutral = RawItem(source_id=src.id, external_id="c", title="neutral note")
        session.add_all([item_hi, item_lo, item_neutral])
        session.flush()
        # relevant + gerichtet -> Event
        session.add(Signal(raw_item_id=item_hi.id, company_id=comp.id, relevance=70,
                           direction=Direction.POSITIVE, impact=Impact.HIGH,
                           horizon=Horizon.DAYS, confidence=0.8))
        # zu niedrige relevance -> kein Event
        session.add(Signal(raw_item_id=item_lo.id, company_id=comp.id, relevance=10,
                           direction=Direction.POSITIVE, impact=Impact.LOW,
                           horizon=Horizon.DAYS, confidence=0.5))
        # neutral -> kein Event
        session.add(Signal(raw_item_id=item_neutral.id, company_id=comp.id, relevance=80,
                           direction=Direction.NEUTRAL, impact=Impact.LOW,
                           horizon=Horizon.DAYS, confidence=0.5))
        session.commit()

    created = build_events_from_signals(db)
    assert created == 1
    # Idempotent: erneuter Lauf erzeugt keine Duplikate
    assert build_events_from_signals(db) == 0
