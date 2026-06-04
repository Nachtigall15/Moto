"""Tests für Forward-Tracking (capture_due_snapshots) — injizierter Live-Kurs."""

import datetime as dt

from stockintel.analysis.eventstudy import BASELINE_HORIZON, capture_due_snapshots
from stockintel.db.database import Database
from stockintel.db.models import Company, Event, EventSnapshot, EventType


def _setup(tmp_path, t0):
    db = Database(f"sqlite:///{tmp_path/'t.db'}")
    db.create_all()
    with db.session() as session:
        comp = Company(ticker="NVDA", name="NVIDIA")
        session.add(comp)
        session.flush()
        session.add(Event(company_id=comp.id, event_type=EventType.EARNINGS, t0=t0))
        session.commit()
    return db


def _price_fn(symbol):
    return 200.0 if symbol == "NVDA" else 500.0  # Ticker vs Benchmark


def test_captures_due_fresh_horizons(tmp_path):
    """Horizonte, deren Zielzeit gerade fällig wurde, werden live erfasst."""
    now = dt.datetime(2024, 1, 1, 12, 0, tzinfo=dt.timezone.utc)
    # t0 vor 1h -> Baseline (t0) und 1h sind fällig & frisch; 4h/1d noch nicht.
    t0 = now - dt.timedelta(hours=1)
    db = _setup(tmp_path, t0)

    written = capture_due_snapshots(db, now=now, price_fn=_price_fn)
    assert written == 2  # "t0" + "1h"

    with db.session() as session:
        snaps = {s.horizon: s for s in session.query(EventSnapshot).all()}
        assert set(snaps) == {BASELINE_HORIZON, "1h"}
        assert snaps["1h"].price == 200.0
        assert snaps["1h"].benchmark_price == 500.0


def test_skips_not_yet_due(tmp_path):
    """Frisches Event (t0=now): nur Baseline fällig, künftige Horizonte nicht."""
    now = dt.datetime(2024, 1, 1, 12, 0, tzinfo=dt.timezone.utc)
    db = _setup(tmp_path, now)
    written = capture_due_snapshots(db, now=now, price_fn=_price_fn)
    assert written == 1  # nur "t0"
    with db.session() as session:
        horizons = {s.horizon for s in session.query(EventSnapshot).all()}
        assert horizons == {BASELINE_HORIZON}


def test_skips_stale_horizons(tmp_path):
    """Lange vergangene Horizonte (> Frische-Fenster) bleiben dem Backfill."""
    now = dt.datetime(2024, 1, 10, 12, 0, tzinfo=dt.timezone.utc)
    t0 = now - dt.timedelta(days=5)  # alle Horizonte bis 3d sind alt
    db = _setup(tmp_path, t0)
    written = capture_due_snapshots(db, now=now, price_fn=_price_fn, fresh_window_hours=2.0)
    assert written == 0  # nichts frisch fällig


def test_idempotent(tmp_path):
    """Zweiter Lauf erfasst denselben Horizont nicht erneut."""
    now = dt.datetime(2024, 1, 1, 12, 0, tzinfo=dt.timezone.utc)
    t0 = now - dt.timedelta(hours=1)
    db = _setup(tmp_path, t0)
    first = capture_due_snapshots(db, now=now, price_fn=_price_fn)
    second = capture_due_snapshots(db, now=now, price_fn=_price_fn)
    assert first == 2
    assert second == 0


def test_no_price_writes_nothing(tmp_path):
    """Ohne Kursdaten (price_fn -> None) entstehen keine Snapshots (kein Crash)."""
    now = dt.datetime(2024, 1, 1, 12, 0, tzinfo=dt.timezone.utc)
    t0 = now - dt.timedelta(hours=1)
    db = _setup(tmp_path, t0)
    written = capture_due_snapshots(db, now=now, price_fn=lambda s: None)
    assert written == 0
