"""Quellen-Adapter (Collectors). Phase 1.

Jede Quelle wird als eigener Adapter implementiert, der von ``BaseCollector``
erbt und ``RawItem``-Objekte in einheitlicher Form liefert.
"""

from stockintel.collectors.base import BaseCollector, CollectedItem

__all__ = ["BaseCollector", "CollectedItem"]
