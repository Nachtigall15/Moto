"""Ingestion-Schicht (Phase 1).

Nimmt die von einem Collector gelieferten ``CollectedItem``-Objekte entgegen,
stellt die zugehörige ``Source`` sicher und speichert sie dedupliziert als
``RawItem``. Deduplikation erfolgt über (source, external_id bzw. url).
"""

from __future__ import annotations

from sqlalchemy import select

from stockintel.collectors.base import BaseCollector
from stockintel.db.database import Database
from stockintel.db.models import RawItem, Source


def ensure_source(session, key: str, name: str, kind: str) -> Source:
    """Liefert die Source mit ``key`` oder legt sie an."""
    src = session.scalars(select(Source).where(Source.key == key)).first()
    if src is None:
        src = Source(key=key, name=name, kind=kind, enabled=True)
        session.add(src)
        session.flush()
    return src


def ingest(db: Database, collector: BaseCollector) -> int:
    """Holt Items vom Collector und speichert die neuen als RawItem.

    Returns:
        Anzahl der neu gespeicherten Items (Duplikate werden übersprungen).
    """
    items = list(collector.fetch())
    new = 0
    with db.session() as session:
        src = ensure_source(session, collector.source_key, collector.name, collector.kind)
        existing = set(
            session.scalars(select(RawItem.external_id).where(RawItem.source_id == src.id))
        )
        for item in items:
            key = item.external_id or item.url
            if key is None or key in existing:
                continue
            session.add(
                RawItem(
                    source_id=src.id,
                    external_id=key,
                    url=item.url,
                    title=item.title,
                    body=item.body,
                    published_at=item.published_at,
                )
            )
            existing.add(key)
            new += 1
        session.commit()
    return new
