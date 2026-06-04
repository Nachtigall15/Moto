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

    p_info = sub.add_parser("info", help="Konfiguration/Status anzeigen")
    p_info.set_defaults(func=cmd_info)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
