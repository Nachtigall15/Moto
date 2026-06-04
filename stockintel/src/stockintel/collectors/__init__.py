"""Quellen-Adapter (Collectors). Phase 1.

Jede Quelle wird als eigener Adapter implementiert, der von ``BaseCollector``
erbt und ``CollectedItem``-Objekte in einheitlicher Form liefert.
"""

from stockintel.collectors.base import BaseCollector, CollectedItem
from stockintel.collectors.edgar import EdgarCollector
from stockintel.collectors.finnhub import FinnhubCollector
from stockintel.collectors.reddit import RedditCollector
from stockintel.collectors.registry import build_collectors
from stockintel.collectors.rss import RssCollector
from stockintel.collectors.stocktwits import StockTwitsCollector

__all__ = [
    "BaseCollector",
    "CollectedItem",
    "EdgarCollector",
    "FinnhubCollector",
    "RedditCollector",
    "RssCollector",
    "StockTwitsCollector",
    "build_collectors",
]
