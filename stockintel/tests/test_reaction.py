"""Tests für Reaction-Profile-Aggregation + vereinheitlichte Hickup-Regel."""

import datetime as dt

import pytest

from stockintel.analysis.eventstudy import (
    aggregate_reaction_profiles,
    is_hickup_from_returns,
)
from stockintel.db.database import Database
from stockintel.db.models import (
    Company,
    Event,
    EventOutcome,
    EventType,
    ReactionProfile,
)


def test_is_hickup_from_returns_reversal_ratio():
    # Spike +6%, final +2% -> 4% zurück; 0.6*6%=3.6%; 4%>=3.6% -> Hickup
    assert is_hickup_from_returns(0.06, 0.02) is True
    # Spike +6%, final +5% -> nur 1% zurück -> kein Hickup
    assert is_hickup_from_returns(0.06, 0.05) is False
    # Strengeres Ratio
    assert is_hickup_from_returns(0.06, 0.02, reversal_ratio=0.9) is False


def test_is_hickup_min_spike_filters_noise():
    # Kleiner Spike (2% < min_spike 5%), komplett zurück -> kein Hickup (Rauschen)
    assert is_hickup_from_returns(0.02, 0.0) is False


def test_is_hickup_none_safe():
    assert is_hickup_from_returns(None, 0.01) is False
    assert is_hickup_from_returns(0.06, None) is False


def _event_with_outcome(session, company_id, event_type, peak, final, hickup, t0):
    ev = Event(company_id=company_id, event_type=event_type, t0=t0)
    session.add(ev)
    session.flush()
    session.add(EventOutcome(
        event_id=ev.id, baseline_price=100.0,
        peak_return=peak, final_return=final, abnormal_return=final, is_hickup=hickup,
    ))


def test_aggregate_reaction_profiles(tmp_path):
    db = Database(f"sqlite:///{tmp_path/'t.db'}")
    db.create_all()
    t0 = dt.datetime(2024, 1, 1, tzinfo=dt.timezone.utc)
    with db.session() as session:
        comp = Company(ticker="NVDA", name="NVIDIA")
        session.add(comp)
        session.flush()
        # Zwei EARNINGS-Events: einer Hickup, einer nicht.
        _event_with_outcome(session, comp.id, EventType.EARNINGS, 0.08, 0.06, False, t0)
        _event_with_outcome(session, comp.id, EventType.EARNINGS, 0.10, 0.01, True, t0)
        # Ein FDA-Event.
        _event_with_outcome(session, comp.id, EventType.FDA, 0.20, 0.18, False, t0)
        session.commit()

    stats = aggregate_reaction_profiles(db)
    assert stats["profiles_updated"] == 2  # EARNINGS + FDA
    assert stats["events_aggregated"] == 3

    with db.session() as session:
        earn = session.query(ReactionProfile).filter_by(event_type=EventType.EARNINGS).one()
        assert earn.sample_size == 2
        assert earn.avg_peak_return == pytest.approx(0.09)   # (0.08+0.10)/2
        assert earn.avg_final_return == pytest.approx(0.035)  # (0.06+0.01)/2
        assert earn.hickup_rate == pytest.approx(0.5)         # 1 von 2

        fda = session.query(ReactionProfile).filter_by(event_type=EventType.FDA).one()
        assert fda.sample_size == 1
        assert fda.hickup_rate == pytest.approx(0.0)


def test_aggregate_reaction_profiles_idempotent(tmp_path):
    """Zweiter Lauf legt kein zweites Profil je Typ an (Upsert)."""
    db = Database(f"sqlite:///{tmp_path/'t.db'}")
    db.create_all()
    t0 = dt.datetime(2024, 1, 1, tzinfo=dt.timezone.utc)
    with db.session() as session:
        comp = Company(ticker="NVDA", name="NVIDIA")
        session.add(comp)
        session.flush()
        _event_with_outcome(session, comp.id, EventType.EARNINGS, 0.08, 0.06, False, t0)
        session.commit()

    aggregate_reaction_profiles(db)
    aggregate_reaction_profiles(db)
    with db.session() as session:
        assert session.query(ReactionProfile).count() == 1
