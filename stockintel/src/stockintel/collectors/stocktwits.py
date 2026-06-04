"""StockTwits-Collector (Phase 1).

Liest den öffentlichen Symbol-Stream von StockTwits (ohne API-Key) für die
Watchlist-Ticker. Schnelle, aber "laute" Social-Signale — die Bewertung der
Verlässlichkeit übernimmt später die KI-Analyse.
"""

from __future__ import annotations

import datetime as dt
from typing import Iterable

import httpx

from stockintel.collectors.base import BaseCollector, CollectedItem

STREAM_URL = "https://api.stocktwits.com/api/2/streams/symbol/{symbol}.json"
DEFAULT_USER_AGENT = "stockintel/0.0.1"


def _parse_iso(value: str | None) -> dt.datetime | None:
    if not value:
        return None
    try:
        return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def parse_stocktwits(symbol: str, data: dict) -> Iterable[CollectedItem]:
    """Wandelt eine StockTwits-Stream-Antwort in CollectedItems um (rein, testbar)."""
    for msg in data.get("messages", []):
        mid = msg.get("id")
        if mid is None:
            continue
        user = (msg.get("user") or {}).get("username", "")
        url = f"https://stocktwits.com/{user}/message/{mid}" if user else None
        yield CollectedItem(
            source_key="stocktwits",
            external_id=f"st_{mid}",          # global eindeutig -> dedupliziert
            title=f"${symbol} @{user}".strip(),
            body=msg.get("body"),
            url=url,
            published_at=_parse_iso(msg.get("created_at")),
        )


class StockTwitsCollector(BaseCollector):
    source_key = "stocktwits"
    name = "StockTwits"
    kind = "social"

    def __init__(self, config: dict | None = None) -> None:
        super().__init__(config)
        self.tickers = [str(t).upper() for t in self.config.get("tickers", [])]
        self.user_agent = self.config.get("user_agent") or DEFAULT_USER_AGENT

    def fetch(self) -> Iterable[CollectedItem]:
        if not self.tickers:
            return
        headers = {"User-Agent": self.user_agent}
        with httpx.Client(headers=headers, timeout=30.0) as client:
            for symbol in self.tickers:
                resp = client.get(STREAM_URL.format(symbol=symbol))
                if resp.status_code != 200:
                    continue
                yield from parse_stocktwits(symbol, resp.json())
