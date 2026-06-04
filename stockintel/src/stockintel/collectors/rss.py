"""RSS-Collector (Phase 1).

Liest Finanz-/Markt-RSS-Feeds via ``feedparser`` und liefert normalisierte
``CollectedItem``-Objekte. Die Feed-Liste ist über die Konfiguration anpassbar.
"""

from __future__ import annotations

import calendar
import datetime as dt
from typing import Iterable

import feedparser

from stockintel.collectors.base import BaseCollector, CollectedItem

# Frei verfügbare, schlüssellose Finanz-/Markt-Feeds als Standard.
DEFAULT_FEEDS: list[str] = [
    "https://www.cnbc.com/id/100003114/device/rss/rss.html",   # CNBC Top News
    "https://www.cnbc.com/id/10000664/device/rss/rss.html",    # CNBC Markets
    "https://feeds.a.dj.com/rss/RSSMarketsMain.xml",           # WSJ Markets
    "https://www.nasdaq.com/feed/rssoutbound?category=Stocks", # Nasdaq Stocks
]


def _entry_datetime(entry) -> dt.datetime | None:
    """Konvertiert das Veröffentlichungsdatum eines Feed-Eintrags nach UTC."""
    parsed = entry.get("published_parsed") or entry.get("updated_parsed")
    if not parsed:
        return None
    return dt.datetime.fromtimestamp(calendar.timegm(parsed), tz=dt.timezone.utc)


def parse_entries(parsed_feed) -> Iterable[CollectedItem]:
    """Wandelt ein geparstes feedparser-Ergebnis in CollectedItems um.

    Als reine Funktion (ohne Netzwerk) gut testbar.
    """
    for entry in parsed_feed.entries:
        link = entry.get("link")
        yield CollectedItem(
            source_key="rss",
            external_id=entry.get("id") or link,
            title=entry.get("title"),
            body=entry.get("summary"),
            url=link,
            published_at=_entry_datetime(entry),
        )


class RssCollector(BaseCollector):
    source_key = "rss"
    name = "RSS News"
    kind = "rss"

    def __init__(self, config: dict | None = None) -> None:
        super().__init__(config)
        self.feeds: list[str] = self.config.get("feeds") or DEFAULT_FEEDS

    def fetch(self) -> Iterable[CollectedItem]:
        for url in self.feeds:
            parsed = feedparser.parse(url)
            yield from parse_entries(parsed)
