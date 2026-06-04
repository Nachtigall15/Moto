"""Kursdaten via yfinance (Event-Study-Vertiefung).

Dünner, testbarer Wrapper um yfinance. yfinance/pandas werden erst beim
tatsächlichen Abruf importiert (Lazy Import), damit das Modul ohne diese
Abhängigkeiten ladbar bleibt. Fehlt yfinance oder schlägt der Netzwerk-Abruf
fehl, liefern die Funktionen leere/None-Resultate statt zu crashen — die
Engine bleibt so in einer Sandbox ohne Marktdaten lauffähig.
"""

from __future__ import annotations

import datetime as dt
import logging
from dataclasses import dataclass

logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class PricePoint:
    """Ein Kurspunkt: Zeitstempel (UTC) + Schlusskurs."""

    ts: dt.datetime
    close: float


# Einheit eines Horizont-Strings ("1h", "3d", ...) -> timedelta-Fabrik.
_HORIZON_UNITS = {
    "h": lambda n: dt.timedelta(hours=n),
    "d": lambda n: dt.timedelta(days=n),
    "w": lambda n: dt.timedelta(weeks=n),
    "m": lambda n: dt.timedelta(days=30 * n),   # Monat ~ 30 Tage (Näherung)
}


def parse_horizon(horizon: str) -> dt.timedelta | None:
    """Wandelt "1h"/"4h"/"1d"/"3d"/"1w"/"1m" in eine ``timedelta`` um.

    Ungültige Eingaben ergeben ``None``.
    """
    if not horizon or len(horizon) < 2:
        return None
    factory = _HORIZON_UNITS.get(horizon[-1].lower())
    if factory is None:
        return None
    try:
        n = int(horizon[:-1])
    except ValueError:
        return None
    return factory(n)


def price_at_or_after(history: list[PricePoint], when: dt.datetime) -> PricePoint | None:
    """Erster Kurspunkt mit ``ts >= when`` (history aufsteigend sortiert)."""
    for point in history:
        if point.ts >= when:
            return point
    return None


def price_at_or_before(history: list[PricePoint], when: dt.datetime) -> PricePoint | None:
    """Letzter Kurspunkt mit ``ts <= when`` (history aufsteigend sortiert)."""
    found: PricePoint | None = None
    for point in history:
        if point.ts <= when:
            found = point
        else:
            break
    return found


def _as_date_str(value: dt.datetime | dt.date) -> str:
    """ISO-Datum für die yfinance-Range (Tagesgrenzen)."""
    if isinstance(value, dt.datetime):
        return value.date().isoformat()
    return value.isoformat()


def _to_utc(ts) -> dt.datetime:
    """Wandelt einen pandas-Timestamp/datetime in ein UTC-``datetime`` um."""
    pydt = ts.to_pydatetime() if hasattr(ts, "to_pydatetime") else ts
    if pydt.tzinfo is None:
        return pydt.replace(tzinfo=dt.timezone.utc)
    return pydt.astimezone(dt.timezone.utc)


def fetch_history(
    ticker: str,
    start: dt.datetime | dt.date,
    end: dt.datetime | dt.date,
    interval: str = "1d",
) -> list[PricePoint]:
    """Lädt Kurshistorie via yfinance als aufsteigend sortierte ``PricePoint``-Liste.

    ``end`` ist inklusiv (intern wird +1 Tag gerechnet). Liefert eine leere
    Liste, wenn yfinance fehlt oder der Abruf scheitert — nie eine Exception.
    """
    try:
        import yfinance as yf
    except ImportError:
        logger.warning("yfinance nicht installiert — keine Kursdaten (pip install .[collectors])")
        return []

    start_s = _as_date_str(start)
    # yfinance behandelt ``end`` exklusiv -> einen Tag draufrechnen, damit der
    # end-Tag in der Range enthalten ist.
    end_base = end if isinstance(end, dt.datetime) else dt.datetime.combine(end, dt.time())
    end_s = _as_date_str(end_base + dt.timedelta(days=1))

    try:
        raw = yf.Ticker(str(ticker)).history(
            start=start_s, end=end_s, interval=interval, auto_adjust=True
        )
    except Exception as exc:  # noqa: BLE001 - yfinance/Netzwerk robust kapseln
        logger.warning("yfinance-Abruf für %s fehlgeschlagen: %s", ticker, exc)
        return []

    points: list[PricePoint] = []
    try:
        for idx, close in raw["Close"].items():
            if close is None or close != close:  # NaN-Check
                continue
            points.append(PricePoint(ts=_to_utc(idx), close=float(close)))
    except (KeyError, TypeError) as exc:
        logger.warning("yfinance-Antwort für %s unerwartet: %s", ticker, exc)
        return []

    points.sort(key=lambda p: p.ts)
    return points


def current_price(ticker: str) -> float | None:
    """Aktuellster verfügbarer Schlusskurs (Live-ish) via yfinance.

    Für Forward-Tracking: misst den Kurs zum Zeitpunkt des Abrufs. Liefert
    ``None`` ohne yfinance/Netz oder bei leerer Antwort (nie eine Exception).
    """
    try:
        import yfinance as yf
    except ImportError:
        return None
    try:
        hist = yf.Ticker(str(ticker)).history(period="1d")
    except Exception as exc:  # noqa: BLE001 - yfinance/Netzwerk robust kapseln
        logger.warning("Live-Kurs für %s fehlgeschlagen: %s", ticker, exc)
        return None
    try:
        closes = hist["Close"]
    except (KeyError, TypeError):
        return None
    if len(closes) == 0:
        return None
    val = float(closes.iloc[-1])
    return val if val == val else None  # NaN-Check


# --- Waehrungs-Umrechnung (Anzeige in EUR) --------------------------------

# Kleiner Prozess-Cache fuer FX-Kurse: {("USD","EUR"): (rate, ts)}.
_FX_CACHE: dict[tuple[str, str], tuple[float, dt.datetime]] = {}
_FX_TTL = dt.timedelta(hours=6)


def fx_rate(from_currency: str, to_currency: str = "EUR") -> float | None:
    """Wechselkurs ``from_currency`` -> ``to_currency`` (z.B. USD->EUR).

    Nutzt yfinance (``"<FROM><TO>=X"``). Ergebnis wird einige Stunden
    gecacht. Liefert ``1.0`` bei gleicher Waehrung, ``None`` bei Fehlern.
    """
    frm = (from_currency or "").upper().strip()
    to = (to_currency or "EUR").upper().strip()
    if not frm or frm == to:
        return 1.0

    now = dt.datetime.now(dt.timezone.utc)
    cached = _FX_CACHE.get((frm, to))
    if cached and now - cached[1] < _FX_TTL:
        return cached[0]

    try:
        import yfinance as yf
    except ImportError:
        return None
    try:
        hist = yf.Ticker(f"{frm}{to}=X").history(period="5d")
        closes = hist["Close"]
        rate = float(closes.iloc[-1])
    except Exception as exc:  # noqa: BLE001 - FX/Netz robust kapseln
        logger.warning("FX-Kurs %s->%s fehlgeschlagen: %s", frm, to, exc)
        return None
    if rate != rate or rate <= 0:  # NaN/ungueltig
        return None
    _FX_CACHE[(frm, to)] = (rate, now)
    return rate


def convert(value: float | None, from_currency: str, to_currency: str = "EUR") -> float | None:
    """Rechnet einen Betrag in die Zielwaehrung um (oder gibt ihn unveraendert
    zurueck, wenn kein FX-Kurs verfuegbar ist)."""
    if value is None:
        return None
    rate = fx_rate(from_currency, to_currency)
    if rate is None:
        return value
    return value * rate



def returns_at_horizons(
    history: list[PricePoint],
    t0: dt.datetime,
    horizons: list[str],
) -> dict[str, float | None]:
    """Renditen ggü. Baseline (Kurs at-or-before t0) an jedem Horizont.

    Reine Funktion (keine Netzwerk-/DB-Zugriffe) — gut testbar.
    """
    baseline_point = price_at_or_before(history, t0) or price_at_or_after(history, t0)
    if baseline_point is None or baseline_point.close == 0:
        return {h: None for h in horizons}

    baseline = baseline_point.close
    out: dict[str, float | None] = {}
    for h in horizons:
        delta = parse_horizon(h)
        if delta is None:
            out[h] = None
            continue
        point = price_at_or_after(history, t0 + delta)
        out[h] = (point.close - baseline) / baseline if point else None
    return out
