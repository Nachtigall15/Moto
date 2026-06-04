"""Tests für die Kursdaten-Helfer (prices.py) — reine Funktionen, kein Netzwerk."""

import datetime as dt

from stockintel.analysis.prices import (
    PricePoint,
    parse_horizon,
    price_at_or_after,
    price_at_or_before,
    returns_at_horizons,
)


def _utc(y, m, d, h=0):
    return dt.datetime(y, m, d, h, tzinfo=dt.timezone.utc)


def test_parse_horizon_units():
    assert parse_horizon("1h") == dt.timedelta(hours=1)
    assert parse_horizon("4h") == dt.timedelta(hours=4)
    assert parse_horizon("1d") == dt.timedelta(days=1)
    assert parse_horizon("3d") == dt.timedelta(days=3)
    assert parse_horizon("1w") == dt.timedelta(weeks=1)
    assert parse_horizon("1m") == dt.timedelta(days=30)


def test_parse_horizon_invalid():
    assert parse_horizon("") is None
    assert parse_horizon("d") is None
    assert parse_horizon("xx") is None
    assert parse_horizon("1y") is None  # Jahr nicht unterstützt


def _history():
    return [
        PricePoint(_utc(2024, 1, 1), 100.0),
        PricePoint(_utc(2024, 1, 2), 105.0),
        PricePoint(_utc(2024, 1, 3), 110.0),
        PricePoint(_utc(2024, 1, 5), 108.0),
    ]


def test_price_at_or_after():
    hist = _history()
    assert price_at_or_after(hist, _utc(2024, 1, 2)).close == 105.0
    # Lücke am 4.: nächster verfügbarer ist der 5.
    assert price_at_or_after(hist, _utc(2024, 1, 4)).close == 108.0
    # Nach dem letzten Punkt -> None
    assert price_at_or_after(hist, _utc(2024, 1, 10)) is None


def test_price_at_or_before():
    hist = _history()
    assert price_at_or_before(hist, _utc(2024, 1, 2)).close == 105.0
    assert price_at_or_before(hist, _utc(2024, 1, 4)).close == 110.0
    # Vor dem ersten Punkt -> None
    assert price_at_or_before(hist, _utc(2023, 12, 31)) is None


def test_returns_at_horizons():
    hist = _history()
    t0 = _utc(2024, 1, 1)
    out = returns_at_horizons(hist, t0, ["1d", "1w"])
    # Baseline = 100 (at-or-before t0)
    assert out["1d"] == 0.05      # 105 am 2.
    # 1w = t0+7d = 8.1. -> kein Punkt danach -> None
    assert out["1w"] is None


def test_returns_at_horizons_no_baseline():
    out = returns_at_horizons([], _utc(2024, 1, 1), ["1d"])
    assert out["1d"] is None
