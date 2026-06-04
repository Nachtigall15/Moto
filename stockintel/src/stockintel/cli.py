"""Kommandozeile für StockIntel.

Verfügbare Befehle:
  * ``stockintel init-db``           – Datenbank-Schema anlegen + Watchlist syncen
  * ``stockintel collect``           – aktive Collectors abrufen (``--loop`` für Dauerbetrieb)
  * ``stockintel link``              – RawItems regelbasiert mit Companies verknüpfen
  * ``stockintel analyze``           – offene Signals mit dem KI-Triage-Modell bewerten
  * ``stockintel score``             – Buy/Hold/Sell Recommendations generieren
  * ``stockintel event-study``       – Events + Kursreaktionen (yfinance) berechnen
  * ``stockintel events``            – erkannte Events + Kursreaktionen anzeigen
  * ``stockintel reaction-profiles`` – Basisraten je Ereignistyp berechnen/anzeigen
  * ``stockintel track``             – Forward-Tracking: fällige Snapshots live erfassen
  * ``stockintel detect-anomalies``  – ML-basierte Anomalieerkennung (Z-Score)
  * ``stockintel find-ipo``          – EDGAR S-1 Filings scannen, IPO-Events anlegen
  * ``stockintel link-themes``       – Themes erkennen, Beneficiaries verlinken
  * ``stockintel items``             – Items anzeigen (Filter: ``--ticker``, ``--source``)
  * ``stockintel signals``           – bewertete Signals anzeigen (Filter: ``--ticker``)
  * ``stockintel recommendations``   – Buy/Hold/Sell Empfehlungen anzeigen
  * ``stockintel ipos``              – IPO-Events anzeigen
  * ``stockintel themes``            – Themes und ihre Profiteure anzeigen
  * ``stockintel companies``         – bekannte Companies + Signal-Zähler
  * ``stockintel info``              – Konfiguration/Status anzeigen
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


def cmd_analyze(args: argparse.Namespace) -> int:
    from stockintel.analysis.triage import analyze_signals

    settings = load_settings()
    db = get_database(settings)
    models_cfg = settings.section("models")
    model = models_cfg.get("triage") or "(Default)"
    print(f"KI-Triage mit Modell: {model} (max {args.limit} Signals)")
    try:
        stats = analyze_signals(db, settings, limit=args.limit)
    except RuntimeError as exc:
        # Fehlender API-Key / fehlendes SDK: klare Meldung statt Traceback.
        print(f"Abbruch: {exc}")
        return 0
    if stats["pending"] == 0:
        print("Keine offenen Signals. Zuerst 'stockintel collect'/'link' ausführen.")
        return 0
    print(
        f"Bewertet: {stats['analyzed']} von {stats['pending']} "
        f"(Fehler: {stats['errors']})"
    )
    return 0


def cmd_score(_: argparse.Namespace) -> int:
    from stockintel.analysis.scoring import generate_recommendations

    settings = load_settings()
    db = get_database(settings)
    stats = generate_recommendations(db)
    print(
        f"Recommendations generiert: {stats['recommendations_created']} neu, "
        f"{stats['recommendations_updated']} aktualisiert"
    )
    return 0


def cmd_recommendations(args: argparse.Namespace) -> int:
    from sqlalchemy import desc, select

    from stockintel.db.models import Company, Recommendation

    settings = load_settings()
    db = get_database(settings)
    with db.session() as session:
        stmt = (
            select(Company.ticker, Company.name, Recommendation.action, Recommendation.confidence, Recommendation.rationale)
            .join(Recommendation, Recommendation.company_id == Company.id)
            .order_by(desc(Recommendation.confidence), Company.ticker)
            .limit(args.limit)
        )
        rows = session.execute(stmt).all()
        if not rows:
            print("Keine Recommendations. Erst 'stockintel score' ausführen.")
            return 0
        print(f"{'Ticker':<8} {'Action':<8} {'Confidence':>10}  Name / Rationale")
        for ticker, name, action, confidence, rationale in rows:
            print(
                f"{ticker:<8} {action.value:<8} {confidence:>10.2f}  {name[:40]}"
            )
            if rationale:
                print(f"         → {rationale[:70]}")
    return 0


def cmd_event_study(args: argparse.Namespace) -> int:
    from stockintel.analysis.eventstudy import run_event_study

    settings = load_settings()
    db = get_database(settings)
    print(f"Event-Study läuft (max {args.limit} Events, yfinance-Kursdaten)…")
    stats = run_event_study(db, settings, limit=args.limit)
    print(
        f"Events neu: {stats['events_created']}, "
        f"Snapshots geschrieben: {stats['snapshots_written']}, "
        f"Outcomes: {stats['outcomes_computed']} (davon Hickups: {stats['hickups']})"
    )
    if stats["snapshots_written"] == 0 and stats["events_created"] >= 0:
        print("Hinweis: Ohne Marktdaten (yfinance/Netzwerk) entstehen keine Snapshots/Outcomes.")
    return 0


def cmd_events(args: argparse.Namespace) -> int:
    from sqlalchemy import desc, select
    from sqlalchemy.orm import joinedload

    from stockintel.db.models import Company, Event

    settings = load_settings()
    db = get_database(settings)
    with db.session() as session:
        stmt = (
            select(Event, Company.ticker)
            .join(Company, Event.company_id == Company.id)
            .options(joinedload(Event.outcome))
            .order_by(desc(Event.t0))
            .limit(args.limit)
        )
        if args.ticker:
            stmt = stmt.where(Company.ticker == args.ticker.upper())
        rows = session.execute(stmt).all()
        if not rows:
            print("Keine Events. Erst 'stockintel event-study' ausführen.")
            return 0
        print(f"{'Ticker':<8} {'Typ':<16} {'t0':<12} {'Final':>8} {'Abn.':>8} {'Hickup':<7} Summary")
        for event, ticker in rows:
            when = event.t0.date().isoformat() if event.t0 else "----------"
            oc = event.outcome
            final = f"{oc.final_return*100:+.1f}%" if oc and oc.final_return is not None else "  –"
            abn = f"{oc.abnormal_return*100:+.1f}%" if oc and oc.abnormal_return is not None else "  –"
            hickup = "ja" if oc and oc.is_hickup else ("nein" if oc else "–")
            print(
                f"{ticker:<8} {event.event_type.value:<16} {when:<12} "
                f"{final:>8} {abn:>8} {hickup:<7} {(event.summary or '')[:40]}"
            )
    return 0


def cmd_track(_: argparse.Namespace) -> int:
    from stockintel.analysis.eventstudy import capture_due_snapshots, run_event_study

    settings = load_settings()
    db = get_database(settings)
    # Erst fällige Live-Horizonte erfassen, dann Outcomes/Profile aktualisieren.
    captured = capture_due_snapshots(db, settings)
    print(f"Forward-Tracking: {captured} fällige Snapshots live erfasst.")
    stats = run_event_study(db, settings)
    print(
        f"Outcomes aktualisiert: {stats['outcomes_computed']} "
        f"(Hickups: {stats['hickups']}, Profile: {stats['profiles_updated']})"
    )
    return 0


def cmd_reaction_profiles(_: argparse.Namespace) -> int:
    from sqlalchemy import desc, select

    from stockintel.analysis.eventstudy import aggregate_reaction_profiles
    from stockintel.db.models import ReactionProfile

    settings = load_settings()
    db = get_database(settings)
    agg = aggregate_reaction_profiles(db)
    print(
        f"Reaction-Profiles aktualisiert: {agg['profiles_updated']} Typen "
        f"aus {agg['events_aggregated']} Outcomes"
    )
    with db.session() as session:
        rows = session.scalars(
            select(ReactionProfile).order_by(desc(ReactionProfile.sample_size))
        ).all()
        if not rows:
            print("Noch keine Basisraten. Erst 'stockintel event-study' (mit Marktdaten) laufen lassen.")
            return 0
        print(f"\n{'Event-Typ':<18} {'N':>4} {'Ø Peak':>9} {'Ø Final':>9} {'Hickup-Quote':>13}")
        for p in rows:
            peak = f"{p.avg_peak_return*100:+.1f}%" if p.avg_peak_return is not None else "    –"
            final = f"{p.avg_final_return*100:+.1f}%" if p.avg_final_return is not None else "    –"
            hick = f"{p.hickup_rate*100:.0f}%" if p.hickup_rate is not None else "  –"
            print(f"{p.event_type.value:<18} {p.sample_size:>4} {peak:>9} {final:>9} {hick:>13}")
    return 0


def cmd_find_ipo(_: argparse.Namespace) -> int:
    from stockintel.analysis.ipo import find_ipo_events, link_ipo_investors

    settings = load_settings()
    db = get_database(settings)
    stats = find_ipo_events(db)
    print(
        f"IPO-Events analysiert: {stats['ipo_events_found']} S-1 Filings, "
        f"{stats['ipo_events_created']} neue IPO-Events"
    )
    investor_stats = link_ipo_investors(db, settings)
    if investor_stats["investors_found"]:
        print(
            f"13F: {investor_stats['investors_found']} Positionen geprüft, "
            f"{investor_stats['investors_linked']} Investor-Links erstellt"
        )
    return 0


def cmd_detect_anomalies(_: argparse.Namespace) -> int:
    """ML-basierte Anomalieerkennung: Events mit statistisch unerwarteten Returns."""
    from stockintel.analysis.anomaly import (
        detect_return_anomalies,
        flag_systematic_anomalies,
    )

    settings = load_settings()
    db = get_database(settings)
    stats = detect_return_anomalies(db, z_threshold=2.0)
    print(
        f"Anomalieerkennung (Z-Score > 2.0): {stats['anomalies_detected']} Events "
        f"als statistische Ausreißer markiert"
    )

    systematic = flag_systematic_anomalies(db, outlier_rate_threshold=0.3)
    if systematic["systematic_types"]:
        print(f"⚠️  Systematische Anomalien erkannt ({len(systematic['systematic_types'])} Event-Typen):")
        for typ_info in systematic["systematic_types"]:
            rate = typ_info["anomaly_rate"] * 100
            print(f"   - {typ_info['event_type']}: {rate:.1f}% Anomalienrate ({typ_info['count']} Events)")
    else:
        print("Keine systematischen Anomalien erkannt.")

    return 0


def cmd_ipos(args: argparse.Namespace) -> int:
    from sqlalchemy import desc, select
    from sqlalchemy.orm import joinedload

    from stockintel.db.models import IpoEvent

    settings = load_settings()
    db = get_database(settings)
    with db.session() as session:
        stmt = (
            select(IpoEvent)
            .options(joinedload(IpoEvent.investors))
            .order_by(desc(IpoEvent.created_at))
            .limit(args.limit)
        )
        rows = session.scalars(stmt).unique().all()
        if not rows:
            print("Keine IPO-Events. Erst 'stockintel find-ipo' ausführen.")
            return 0
        print(f"{'Company':<30} {'Ticker':<8} {'Expected Date':<15} Investors")
        for event in rows:
            when = event.expected_date.date().isoformat() if event.expected_date else "----------"
            investors = event.investors or []
            print(
                f"{event.company_name:<30} {(event.ticker or '-'):<8} {when:<15} {len(investors)}"
            )
            for inv in investors:
                print(f"         → {inv.investor_name}")
    return 0


def cmd_link_themes(_: argparse.Namespace) -> int:
    from stockintel.analysis.themes import link_themes_to_signals, sync_themes

    settings = load_settings()
    db = get_database(settings)
    new_themes = sync_themes(db)
    if new_themes:
        print(f"Themes synchronisiert: {new_themes} neue Theme-Einträge.")
    stats = link_themes_to_signals(db)
    print(
        f"Themes analysiert: {stats['themes_found']} Theme-Matches, "
        f"{stats['beneficiaries_linked']} Beneficiary-Links erstellt"
    )
    return 0


def cmd_themes(args: argparse.Namespace) -> int:
    from sqlalchemy import desc, select

    from stockintel.db.models import Company, Theme, ThemeBeneficiary

    settings = load_settings()
    db = get_database(settings)
    with db.session() as session:
        stmt = (
            select(Theme.name, Company.ticker, ThemeBeneficiary.strength, ThemeBeneficiary.rationale)
            .join(ThemeBeneficiary, ThemeBeneficiary.theme_id == Theme.id)
            .join(Company, ThemeBeneficiary.company_id == Company.id)
        )
        if args.theme:
            stmt = stmt.where(Theme.name == args.theme)
        stmt = stmt.order_by(desc(ThemeBeneficiary.strength), Theme.name).limit(args.limit)

        rows = session.execute(stmt).all()
        if not rows:
            print("Keine Theme-Beneficiary-Links. Erst 'stockintel link-themes' ausführen.")
            return 0
        print(f"{'Theme':<25} {'Ticker':<8} {'Strength':>8}  Rationale")
        for theme_name, ticker, strength, rationale in rows:
            print(
                f"{theme_name:<25} {ticker:<8} {strength:>8.2f}  {(rationale or '').strip()[:50]}"
            )
    return 0


def cmd_signals(args: argparse.Namespace) -> int:
    from sqlalchemy import desc, select

    from stockintel.analysis.entity import RULE_BASED_MODEL
    from stockintel.db.models import Company, RawItem, Signal

    settings = load_settings()
    db = get_database(settings)
    with db.session() as session:
        stmt = (
            select(Signal, Company.ticker, RawItem.title, RawItem.url)
            .join(Company, Signal.company_id == Company.id)
            .join(RawItem, Signal.raw_item_id == RawItem.id)
        )
        if args.ticker:
            stmt = stmt.where(Company.ticker == args.ticker.upper())
        if args.analyzed:
            stmt = stmt.where(Signal.model != RULE_BASED_MODEL)
        stmt = stmt.order_by(desc(Signal.relevance), desc(Signal.id)).limit(args.limit)

        rows = session.execute(stmt).all()
        if not rows:
            print("Keine passenden Signals. Zuerst 'stockintel link'/'analyze' ausführen.")
            return 0
        for signal, ticker, title, url in rows:
            flag = "·" if signal.model == RULE_BASED_MODEL else "✓"
            text = (title or url or "").strip()[:60]
            print(
                f"{flag} {ticker:6} {signal.direction.value:8} "
                f"{signal.impact.value:6} rel={signal.relevance:3} "
                f"conf={signal.confidence:.2f}  {text}"
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

    p_analyze = sub.add_parser(
        "analyze", help="Offene Signals mit dem KI-Triage-Modell bewerten",
    )
    p_analyze.add_argument(
        "--limit", type=int, default=20,
        help="Maximale Anzahl Signals pro Lauf (Standard 20)",
    )
    p_analyze.set_defaults(func=cmd_analyze)

    p_score = sub.add_parser(
        "score",
        help="Buy/Hold/Sell Recommendations generieren aus Signals",
    )
    p_score.set_defaults(func=cmd_score)

    p_recs = sub.add_parser("recommendations", help="Buy/Hold/Sell Recommendations anzeigen")
    p_recs.add_argument("--limit", type=int, default=20, help="Anzahl (Standard 20)")
    p_recs.set_defaults(func=cmd_recommendations)

    p_signals = sub.add_parser("signals", help="Bewertete Signals anzeigen")
    p_signals.add_argument("--limit", type=int, default=20, help="Anzahl (Standard 20)")
    p_signals.add_argument("--ticker", type=str, default=None, help="Nur eine Aktie (z.B. NVDA)")
    p_signals.add_argument(
        "--analyzed", action="store_true",
        help="Nur KI-bewertete Signals (regelbasierte ausblenden)",
    )
    p_signals.set_defaults(func=cmd_signals)

    p_event_study = sub.add_parser(
        "event-study",
        help="Signals -> Events -> Kurs-Snapshots (yfinance) -> Outcomes/Hickups",
    )
    p_event_study.add_argument(
        "--limit", type=int, default=100,
        help="Maximale Anzahl Events pro Lauf (Standard 100)",
    )
    p_event_study.set_defaults(func=cmd_event_study)

    p_events = sub.add_parser("events", help="Erkannte Events + Kursreaktionen anzeigen")
    p_events.add_argument("--limit", type=int, default=20, help="Anzahl (Standard 20)")
    p_events.add_argument("--ticker", type=str, default=None, help="Nur eine Aktie (z.B. NVDA)")
    p_events.set_defaults(func=cmd_events)

    p_profiles = sub.add_parser(
        "reaction-profiles",
        help="Basisraten je Ereignistyp (Ø Reaktion, Hickup-Quote) berechnen/anzeigen",
    )
    p_profiles.set_defaults(func=cmd_reaction_profiles)

    p_track = sub.add_parser(
        "track",
        help="Forward-Tracking: fällige Kurs-Snapshots live erfassen + Outcomes",
    )
    p_track.set_defaults(func=cmd_track)

    p_find_ipo = sub.add_parser(
        "find-ipo",
        help="EDGAR S-1 Filings scannen, IPO-Events anlegen",
    )
    p_find_ipo.set_defaults(func=cmd_find_ipo)

    p_ipos = sub.add_parser("ipos", help="Erkannte IPO-Events anzeigen")
    p_ipos.add_argument("--limit", type=int, default=20, help="Anzahl (Standard 20)")
    p_ipos.set_defaults(func=cmd_ipos)

    p_link_themes = sub.add_parser(
        "link-themes",
        help="Signals analysieren, Themes erkennen und Beneficiaries verlinken",
    )
    p_link_themes.set_defaults(func=cmd_link_themes)

    p_themes = sub.add_parser("themes", help="Erkannte Hype-Themes und ihre Profiteure anzeigen")
    p_themes.add_argument("--limit", type=int, default=30, help="Anzahl (Standard 30)")
    p_themes.add_argument("--theme", type=str, default=None, help="Nur ein Theme (z.B. 'AI Infrastructure')")
    p_themes.set_defaults(func=cmd_themes)

    p_companies = sub.add_parser(
        "companies", help="Bekannte Companies + Signal-Anzahl je Unternehmen",
    )
    p_companies.set_defaults(func=cmd_companies)

    p_info = sub.add_parser("info", help="Konfiguration/Status anzeigen")
    p_info.set_defaults(func=cmd_info)

    p_anomaly = sub.add_parser(
        "detect-anomalies",
        help="ML-basierte Anomalieerkennung für Events (Z-Score-basiert)",
    )
    p_anomaly.set_defaults(func=cmd_detect_anomalies)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
