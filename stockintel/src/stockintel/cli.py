"""Kommandozeile für StockIntel.

Verfügbare Befehle:
  * ``stockintel init-db``    – Datenbank-Schema anlegen + Watchlist syncen
  * ``stockintel collect``    – aktive Collectors abrufen (``--loop`` für Dauerbetrieb)
  * ``stockintel link``       – RawItems regelbasiert mit Companies verknüpfen
  * ``stockintel items``      – Items anzeigen (Filter: ``--ticker``, ``--source``)
  * ``stockintel companies``  – bekannte Companies + Signal-Zähler
  * ``stockintel info``       – Konfiguration/Status anzeigen
"""

from __future__ import annotations

import argparse
import datetime as dt
import sys
import time

from sqlalchemy import inspect

from stockintel import __version__
from stockintel.config import load_settings
from stockintel.db.database import get_database


def cmd_init_db(_: argparse.Namespace) -> int:
    from stockintel.analysis.entity import sync_companies

    settings = load_settings()
    db = get_database(settings)
    db.create_all()
    new_companies = sync_companies(db, settings.watchlist)
    tables = sorted(inspect(db.engine).get_table_names())
    print(f"Datenbank initialisiert: {settings.db_url}")
    print(f"Tabellen ({len(tables)}): {', '.join(tables)}")
    if new_companies:
        print(f"Watchlist synchronisiert: {new_companies} neue Company-Einträge.")
    return 0


def _collect_once(settings, db) -> int:
    """Führt genau einen Sammel-Durchlauf aller aktiven Collectors aus.

    Bleibt pro Quelle robust (Fehler einer Quelle stoppen die anderen nicht)
    und gibt die Anzahl insgesamt neu gespeicherter Items zurück. Im Anschluss
    wird die regelbasierte Entity-Resolution ausgeführt (idempotent), damit
    die neuen Items sofort mit Companies verknüpft sind.
    """
    from stockintel.analysis.entity import link_items, sync_companies
    from stockintel.collectors import build_collectors
    from stockintel.ingestion import ingest

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

    sync_companies(db, settings.watchlist)
    stats = link_items(db)
    print(
        f"  linking: {stats['signals_created']} neue Signals "
        f"(gescannt: {stats['items_scanned']})"
    )
    print(f"Gesamt neu: {total}")
    return total


def cmd_collect(args: argparse.Namespace) -> int:
    settings = load_settings()
    db = get_database(settings)

    loop = getattr(args, "loop", False)
    if not loop:
        _collect_once(settings, db)
        return 0

    interval = max(1, int(getattr(args, "interval", 600)))
    max_runs = int(getattr(args, "count", 0))  # 0 = unbegrenzt
    print(
        f"Schleifen-Modus: alle {interval}s"
        + (f", {max_runs} Läufe" if max_runs else ", unbegrenzt (Strg-C zum Beenden)")
    )
    run = 0
    try:
        while True:
            run += 1
            stamp = dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            print(f"\n== Lauf {run} @ {stamp} ==")
            try:
                _collect_once(settings, db)
            except Exception as exc:  # noqa: BLE001 - Schleife läuft trotz Fehler weiter
                print(f"  Lauf {run}: unerwarteter Fehler: {exc}")
            if max_runs and run >= max_runs:
                break
            time.sleep(interval)
    except KeyboardInterrupt:
        print(f"\nAbgebrochen nach {run} Lauf/Läufen.")
    return 0


def cmd_items(args: argparse.Namespace) -> int:
    from sqlalchemy import desc, select

    from stockintel.db.models import Company, RawItem, Signal, Source

    settings = load_settings()
    db = get_database(settings)
    with db.session() as session:
        stmt = select(RawItem, Source.key).join(Source)
        if args.source:
            stmt = stmt.where(Source.key == args.source)
        if args.ticker:
            sub = (
                select(Signal.raw_item_id)
                .join(Company, Signal.company_id == Company.id)
                .where(Company.ticker == args.ticker.upper())
            )
            stmt = stmt.where(RawItem.id.in_(sub))
        stmt = stmt.order_by(desc(RawItem.fetched_at)).limit(args.limit)

        rows = session.execute(stmt).all()
        if not rows:
            hint = "Noch keine Items"
            if args.ticker or args.source:
                hint = "Keine passenden Items"
            print(f"{hint}. Zuerst 'stockintel collect' ausführen.")
            return 0
        for item, source_key in rows:
            when = item.published_at.date().isoformat() if item.published_at else "----------"
            print(f"[{source_key:8}] {when}  {(item.title or item.url or '').strip()[:90]}")
    return 0


def cmd_link(_: argparse.Namespace) -> int:
    from stockintel.analysis.entity import link_items, sync_companies

    settings = load_settings()
    db = get_database(settings)
    new_companies = sync_companies(db, settings.watchlist)
    if new_companies:
        print(f"Watchlist synchronisiert: {new_companies} neue Company-Einträge.")
    stats = link_items(db)
    print(
        f"RawItems gescannt: {stats['items_scanned']}, "
        f"neue Signals: {stats['signals_created']}"
    )
    return 0


def cmd_companies(_: argparse.Namespace) -> int:
    from sqlalchemy import func, select

    from stockintel.db.models import Company, Signal

    settings = load_settings()
    db = get_database(settings)
    with db.session() as session:
        rows = session.execute(
            select(
                Company.ticker,
                Company.name,
                Company.sector,
                Company.on_watchlist,
                func.count(Signal.id).label("signal_count"),
            )
            .outerjoin(Signal, Signal.company_id == Company.id)
            .group_by(Company.id)
            .order_by(Company.ticker)
        ).all()
        if not rows:
            print("Keine Companies. Erst 'stockintel init-db' oder 'stockintel link' ausführen.")
            return 0
        print(f"{'Ticker':<8} {'Sektor':<18} {'Watchlist':<10} {'Signals':>7}  Name")
        for ticker, name, sector, on_watchlist, signal_count in rows:
            wl = "ja" if on_watchlist else "nein"
            print(
                f"{ticker:<8} {(sector or '-'):<18} {wl:<10} {signal_count:>7}  {name}"
            )
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
    p_collect.add_argument(
        "--loop", action="store_true",
        help="Wiederholt sammeln statt nur einmal (Strg-C beendet)",
    )
    p_collect.add_argument(
        "--interval", type=int, default=600,
        help="Sekunden zwischen den Läufen im Schleifen-Modus (Standard 600)",
    )
    p_collect.add_argument(
        "--count", type=int, default=0,
        help="Anzahl der Läufe im Schleifen-Modus (0 = unbegrenzt)",
    )
    p_collect.set_defaults(func=cmd_collect)

    p_items = sub.add_parser("items", help="Zuletzt gespeicherte Items anzeigen")
    p_items.add_argument("--limit", type=int, default=20, help="Anzahl Einträge (Standard 20)")
    p_items.add_argument(
        "--ticker", type=str, default=None,
        help="Nur Items, die einer Aktie zugeordnet sind (z.B. NVDA)",
    )
    p_items.add_argument(
        "--source", type=str, default=None,
        help="Nur Items aus einer bestimmten Quelle (edgar/rss/stocktwits/finnhub/reddit)",
    )
    p_items.set_defaults(func=cmd_items)

    p_link = sub.add_parser(
        "link",
        help="RawItems regelbasiert mit Companies verknüpfen (Signals anlegen)",
    )
    p_link.set_defaults(func=cmd_link)

    p_companies = sub.add_parser(
        "companies", help="Bekannte Companies + Signal-Anzahl je Unternehmen",
    )
    p_companies.set_defaults(func=cmd_companies)

    p_info = sub.add_parser("info", help="Konfiguration/Status anzeigen")
    p_info.set_defaults(func=cmd_info)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
