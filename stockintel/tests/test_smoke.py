"""Smoke-Tests für das Phase-0-Gerüst."""

from stockintel.eventstudy import classify_hickup, horizon_to_timedelta


def test_horizon_to_timedelta():
    assert horizon_to_timedelta("1h").total_seconds() == 3600
    assert horizon_to_timedelta("1d").days == 1


def test_classify_hickup_detects_reversal():
    # Stieg +6%, am Ende nur noch +1% -> Großteil abgegeben -> Hickup.
    assert classify_hickup(peak_return=0.06, final_return=0.01) is True


def test_classify_hickup_sustained_move_is_not_hickup():
    # Stieg +6% und hielt +5% -> nachhaltige Bewegung, kein Hickup.
    assert classify_hickup(peak_return=0.06, final_return=0.05) is False


def test_classify_hickup_ignores_negative_peak():
    assert classify_hickup(peak_return=-0.02, final_return=-0.04) is False


def test_database_schema_creates_tables(tmp_path):
    from stockintel.db.database import Database

    db = Database(f"sqlite:///{tmp_path/'t.db'}")
    db.create_all()
    from sqlalchemy import inspect

    tables = set(inspect(db.engine).get_table_names())
    assert {"companies", "events", "event_outcomes", "reaction_profiles"} <= tables
