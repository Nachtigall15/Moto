"""Basis-Schnittstelle für alle Quellen-Adapter (Phase 1).

Konkrete Collectors (EDGAR, RSS, Finnhub, Reddit, StockTwits, YouTube) erben von
``BaseCollector`` und geben normalisierte ``CollectedItem``-Objekte zurück. Die
Speicherung als ``RawItem`` übernimmt die Ingestion-Schicht.
"""

from __future__ import annotations

import abc
import datetime as dt
from dataclasses import dataclass
from typing import Iterable


@dataclass(slots=True)
class CollectedItem:
    """Eine von einem Adapter eingesammelte, noch nicht gespeicherte Information."""

    source_key: str
    external_id: str | None
    title: str | None
    body: str | None
    url: str | None
    published_at: dt.datetime | None


class BaseCollector(abc.ABC):
    """Gemeinsame Basis aller Quellen-Adapter."""

    #: Eindeutiger Schlüssel der Quelle, z.B. "edgar" oder "reddit".
    source_key: str = "base"
    #: Art der Quelle: rss | api | social | filing.
    kind: str = "api"

    def __init__(self, config: dict | None = None) -> None:
        self.config = config or {}

    @abc.abstractmethod
    def fetch(self) -> Iterable[CollectedItem]:
        """Holt neue Items von der Quelle. In Phase 1 zu implementieren."""
        raise NotImplementedError
