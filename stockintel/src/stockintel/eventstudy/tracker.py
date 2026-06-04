"""Kern-Hilfen der Event-Study (Phase 4).

Phase 0 liefert die reine, testbare Logik (Horizont-Umrechnung, Hickup-Regel)
ohne externe Kursdatenquelle. Die Anbindung an yfinance/Finnhub und den
Scheduler folgt in Phase 4.
"""

from __future__ import annotations

import datetime as dt

# Unterstützte Horizonte als Offsets ab dem Ereigniszeitpunkt t0.
HORIZON_OFFSETS: dict[str, dt.timedelta] = {
    "1h": dt.timedelta(hours=1),
    "4h": dt.timedelta(hours=4),
    "1d": dt.timedelta(days=1),
    "3d": dt.timedelta(days=3),
    "1w": dt.timedelta(weeks=1),
    "1m": dt.timedelta(days=30),
}


def horizon_to_timedelta(horizon: str) -> dt.timedelta:
    """Wandelt einen Horizont-Schlüssel ("1h", "1d", …) in ein timedelta."""
    try:
        return HORIZON_OFFSETS[horizon]
    except KeyError as exc:  # pragma: no cover - defensive
        raise ValueError(f"Unbekannter Horizont: {horizon!r}") from exc


def classify_hickup(
    peak_return: float,
    final_return: float,
    reversal_ratio: float = 0.6,
) -> bool:
    """Erkennt ein Strohfeuer ("Hickup").

    Ein Hickup liegt vor, wenn es eine nennenswerte anfängliche Bewegung gab
    (``peak_return``), von der bis zum Ende ein Großteil wieder abgegeben wurde.

    Args:
        peak_return: Maximale relative Bewegung kurz nach dem Ereignis (z.B. 0.06).
        final_return: Relative Bewegung am letzten gemessenen Horizont.
        reversal_ratio: Anteil der Spitzenbewegung, der mindestens wieder
            abgegeben sein muss, damit es als Hickup gilt.

    Returns:
        True, wenn das Muster einem Strohfeuer entspricht.
    """
    if peak_return <= 0:
        return False
    given_back = peak_return - final_return
    return given_back >= reversal_ratio * peak_return
