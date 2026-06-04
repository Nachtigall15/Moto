"""Finnhub-Collector (Phase 1).

Holt Unternehmens-News der Watchlist-Ticker über die Finnhub-API
(``/company-news``). Die News-Endpunkte sind im kostenlosen Free-Tier
enthalten; benötigt wird lediglich ein API-Key.

Benötigt einen Finnhub-API-Key (https://finnhub.io/dashboard):
``FINNHUB_API_KEY`` in der .env (oder ``collectors.finnhub.api_key``).
"""

from __future__ import annotations

import datetime as dt
import os
from typing import Iterable

import httpx

from stockintel.collectors.base import BaseCollector, CollectedItem

COMPANY_NEWS_URL = "https://finnhub.io/api/v1/company-news"
DEFAULT_LOOKBACK_DAYS = 7


def _parse_unix(value: object) -> dt.datetime | None:
    """Wandelt einen Unix-Zeitstempel (Sekunden) in ein UTC-datetime um."""
    try:
        ts = int(value)  # type: ignore[arg-type]
    except (TypeError, ValueError):
        return None
    if ts <= 0:
        return None
    return dt.datetime.fromtimestamp(ts, tz=dt.timezone.utc)


def parse_company_news(symbol: str, data: list) -> Iterable[CollectedItem]:
    """Wandelt eine Finnhub-``company-news``-Antwort in CollectedItems um (rein, testbar).

    Erwartet eine Liste von Artikel-Objekten mit den Feldern ``id``,
    ``headline``, ``summary``, ``url`` und ``datetime`` (Unix-Sekunden).
    Artikel ohne ``id`` werden übersprungen.
    """
    if not isinstance(data, list):
        return
    for article in data:
        if not isinstance(article, dict):
            continue
        aid = article.get("id")
        if aid is None:
            continue
        headline = article.get("headline") or None
        yield CollectedItem(
            source_key="finnhub",
            external_id=f"fh_{aid}",        # global eindeutig -> dedupliziert
            title=f"{symbol} {headline}".strip() if headline else symbol,
            body=article.get("summary") or None,
            url=article.get("url") or None,
            published_at=_parse_unix(article.get("datetime")),
        )


class FinnhubCollector(BaseCollector):
    source_key = "finnhub"
    name = "Finnhub"
    kind = "news"

    def __init__(self, config: dict | None = None) -> None:
        super().__init__(config)
        self.tickers = [str(t).upper() for t in self.config.get("tickers", [])]
        self.lookback_days = int(self.config.get("lookback_days", DEFAULT_LOOKBACK_DAYS))
        self.limit = self.config.get("limit")  # optional: Obergrenze je Ticker
        self.api_key = self.config.get("api_key") or os.environ.get("FINNHUB_API_KEY")

    def fetch(self) -> Iterable[CollectedItem]:
        if not self.tickers:
            return
        if not self.api_key:
            raise RuntimeError(
                "Finnhub-API-Key fehlt: FINNHUB_API_KEY in der .env setzen "
                "(https://finnhub.io/dashboard)."
            )
        today = dt.datetime.now(dt.timezone.utc).date()
        date_from = (today - dt.timedelta(days=self.lookback_days)).isoformat()
        date_to = today.isoformat()
        with httpx.Client(timeout=30.0) as client:
            for symbol in self.tickers:
                resp = client.get(
                    COMPANY_NEWS_URL,
                    params={
                        "symbol": symbol,
                        "from": date_from,
                        "to": date_to,
                        "token": self.api_key,
                    },
                )
                if resp.status_code != 200:
                    continue
                items = parse_company_news(symbol, resp.json())
                if self.limit:
                    for i, item in enumerate(items):
                        if i >= int(self.limit):
                            break
                        yield item
                else:
                    yield from items
