"""Quellen-Adapter (Collectors). Phase 1.

Jede Quelle wird als eigener Adapter implementiert, der von ``BaseCollector``
erbt und ``CollectedItem``-Objekte in einheitlicher Form liefert.
"""

from stockintel.collectors.base import BaseCollector, CollectedItem
from stockintel.collectors.edgar import EdgarCollector
from stockintel.collectors.registry import build_collectors
from stockintel.collectors.rss import RssCollector

__all__ = [
    "BaseCollector",
    "CollectedItem",
    "EdgarCollector",
    "RssCollector",
    "build_collectors",
]
