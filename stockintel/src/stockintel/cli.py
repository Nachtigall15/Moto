"""Kommandozeile für StockIntel.

Phase 0 unterstützt:
  * ``stockintel init-db``  – Datenbank-Schema anlegen
  * ``stockintel info``     – Konfiguration/Status anzeigen
"""

from __future__ import annotations

import argparse
import sys

from sqlalchemy import inspect

from stockintel import __version__
from stockintel.config import load_settings
from stockintel.db.database import get_database


def cmd_init_db(_: argparse.Namespace) -> int:
    settings = load_settings()
    db = get_database(settings)
    db.create_all()
    tables = sorted(inspect(db.engine).get_table_names())
    print(f"Datenbank initialisiert: {settings.db_url}")
    print(f"Tabellen ({len(tables)}): {', '.join(tables)}")
    return 0


def cmd_collect(_: argparse.Namespace) -> int:
    from stockintel.collectors import build_collectors
    from stockintel.ingestion import ingest

    settings = load_settings()
    db = get_database(settings)
    collectors = build_collectors(settings)
    if not collectors:
        print("Keine aktiven Collectors. In config/settings.yaml aktivieren.")
        return 0

    total = 0
    for collector in collectors:
        try:
            count = ingest(db, collector)
        except Exception as exc:  # noqa: BLE001 - pro Quelle robust bleiben
            print(f"  {collector.source_key}: Fehler beim Abruf: {exc}")
            continue
        total += count
        print(f"  {collector.source_key}: {count} neue Items")
    print(f"Gesamt neu: {total}")
    return 0


def cmd_items(args: argparse.Namespace) -> int:
    from sqlalchemy import desc, select

    from stockintel.db.models import RawItem, Source

    settings = load_settings()
    db = get_database(settings)
    with db.session() as session:
        rows = session.execute(
            select(RawItem, Source.key)
            .join(Source)
            .order_by(desc(RawItem.fetched_at))
            .limit(args.limit)
        ).all()
        if not rows:
            print("Noch keine Items. Zuerst 'stockintel collect' ausführen.")
            return 0
        for item, source_key in rows:
            when = item.published_at.date().isoformat() if item.published_at else "----------"
            print(f"[{source_key:8}] {when}  {(item.title or item.url or '').strip()[:90]}")
    return 0


def cmd_info(_: argparse.Namespace) -> int:
    settings = load_settings()
    watchlist = settings.watchlist
    print(f"StockIntel {__version__}")
    print(f"DB-URL:    {settings.db_url}")
    print(f"Watchlist: {len(watchlist)} Eintrag/Einträge")
    for item in watchlist:
        print(f"  - {item.get('ticker', '?'):6} {item.get('name', '')}")
    collectors = settings.section("collectors")
    if collectors:
        enabled = [k for k, v in collectors.items() if isinstance(v, dict) and v.get("enabled")]
        print(f"Aktive Collectors: {', '.join(enabled) or '(keine)'}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="stockintel", description="StockIntel Engine")
    parser.add_argument("--version", action="version", version=f"stockintel {__version__}")
    sub = parser.add_subparsers(dest="command", required=True)

    p_init = sub.add_parser("init-db", help="Datenbank-Schema anlegen")
    p_init.set_defaults(func=cmd_init_db)

    p_collect = sub.add_parser("collect", help="Aktive Collectors abrufen und speichern")
    p_collect.set_defaults(func=cmd_collect)

    p_items = sub.add_parser("items", help="Zuletzt gespeicherte Items anzeigen")
    p_items.add_argument("--limit", type=int, default=20, help="Anzahl Einträge (Standard 20)")
    p_items.set_defaults(func=cmd_items)

    p_info = sub.add_parser("info", help="Konfiguration/Status anzeigen")
    p_info.set_defaults(func=cmd_info)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
