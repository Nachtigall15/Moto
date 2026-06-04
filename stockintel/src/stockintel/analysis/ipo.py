"""IPO-Events erkennen und Investoren extrahieren.

Nutzt EDGAR S-1 Filings (Börsengang-Prospekte) und 13F-Filings (Investorenpositionen).
Phase 3b: regelbasiert + später KI-augmentiert.
"""

from __future__ import annotations

import logging
import re
from typing import TYPE_CHECKING, Callable

from sqlalchemy import select
from sqlalchemy.orm import joinedload

from stockintel.analysis.thirteenf import Holding, fetch_13f_holdings, issuer_matches
from stockintel.db.models import IpoEvent, IpoInvestor, RawItem, Source

if TYPE_CHECKING:
    from stockintel.config import Settings
    from stockintel.db.database import Database

logger = logging.getLogger(__name__)

HoldingsProvider = Callable[[str], list[Holding]]


# S-1 Filings sind explizit im EDGAR Form-Index
# 13F-HR: institutionelle Positionen (>$100M Portfolios)
S1_FORM_TYPE = "S-1"
S1_FORM_TYPES = ["S-1", "S-1/A", "S-1MEF"]  # S-1 + Amendments
DEFAULT_13F_USER_AGENT = "stockintel research example@example.com"


def extract_ipo_from_s1(url: str, title: str, body: str | None = None) -> dict | None:
    """Versucht, Company-Name und Ticker aus einer S-1 URL/Title zu extrahieren.

    EDGAR URLs für S-1 folgen dem Pattern:
    https://www.sec.gov/cgi-bin/browse-edgar?action=getcompany&CIK=...&type=S-1&...
    oder in den Filing-Daten direkt nach Ticker-Pattern.

    Gibt {company_name, ticker} oder None zurück.
    """
    if not url:
        return None

    # Versuche aus Titel zu extrahieren: "Company Inc. (TICK) - S-1 Registration"
    match = re.search(r'([A-Z][A-Za-z\s&,\.]+?)\s+\(([A-Z]{1,5})\)', title or "")
    if match:
        return {
            "company_name": match.group(1).strip(),
            "ticker": match.group(2).strip(),
        }

    # Fallback: nur aus URL nach CIK (nicht zuverlässig ohne Lookup)
    return None


def find_ipo_events(db: Database) -> dict[str, int]:
    """Scannet alle EDGAR-RawItems auf S-1 Filings, erstellt IpoEvents.

    Idempotent: pro CIK/Company wird nur ein IpoEvent erstellt.
    Returns: {ipo_events_found, ipo_events_created}.
    """
    stats = {"ipo_events_found": 0, "ipo_events_created": 0}

    with db.session() as session:
        # EDGAR-Items laden (nur "S-1" Form Type)
        edgar_source = session.scalar(select(Source).where(Source.key == "edgar"))
        if not edgar_source:
            return stats

        # Items mit "S-1" im Title/URL filtern
        s1_items = session.scalars(
            select(RawItem)
            .where(RawItem.source_id == edgar_source.id)
        ).all()

        existing_tickers = set(
            session.scalars(select(IpoEvent.ticker)).all()
        )

        for item in s1_items:
            title = item.title or ""
            if not any(form in title for form in S1_FORM_TYPES):
                continue

            stats["ipo_events_found"] += 1

            parsed = extract_ipo_from_s1(item.url or "", title, item.body)
            if not parsed:
                continue

            ticker = parsed.get("ticker")
            if ticker in existing_tickers:
                continue

            ipo_event = IpoEvent(
                company_name=parsed["company_name"],
                ticker=ticker,
                expected_date=item.published_at,
                source_url=item.url,
            )
            session.add(ipo_event)
            stats["ipo_events_created"] += 1
            existing_tickers.add(ticker)

        session.commit()

    return stats


def _managers_from_settings(settings: Settings | None) -> list[dict]:
    """Liest die zu verfolgenden 13F-Manager aus den Settings (Sektion ``ipo``)."""
    if settings is None:
        return []
    ipo_cfg = settings.section("ipo")
    managers = ipo_cfg.get("managers")
    if not isinstance(managers, list):
        return []
    return [m for m in managers if isinstance(m, dict) and m.get("cik")]


def _edgar_user_agent(settings: Settings | None) -> str | None:
    """Übernimmt den EDGAR-User-Agent aus der Collector-Konfiguration (falls gesetzt)."""
    if settings is None:
        return None
    edgar_cfg = settings.section("collectors").get("edgar")
    if isinstance(edgar_cfg, dict):
        return edgar_cfg.get("user_agent")
    return None


def link_ipo_investors(
    db: Database,
    settings: Settings | None = None,
    managers: list[dict] | None = None,
    holdings_provider: HoldingsProvider | None = None,
    user_agent: str | None = None,
) -> dict[str, int]:
    """Verknüpft IpoEvents mit institutionellen Haltern aus 13F-Filings.

    Für jeden verfolgten Vermögensverwalter (``managers`` = Liste mit ``cik`` +
    ``name``; Default: aus Settings) werden dessen 13F-Positionen geladen und per
    Namensabgleich den bekannten IPO-Events zugeordnet. Treffer werden als
    ``IpoInvestor`` gespeichert.

    ``holdings_provider`` (Callable ``cik -> list[Holding]``) ist für Tests
    injizierbar; Default ist der EDGAR-Abruf. Idempotent: ein (IPO, Investor)-Paar
    wird nicht doppelt angelegt.

    Returns: {investors_found, investors_linked}.
    """
    managers = managers if managers is not None else _managers_from_settings(settings)
    stats = {"investors_found": 0, "investors_linked": 0}
    if not managers:
        return stats

    ua = user_agent or _edgar_user_agent(settings) or DEFAULT_13F_USER_AGENT
    provider = holdings_provider or (lambda cik: fetch_13f_holdings(cik, ua))

    with db.session() as session:
        ipos = session.scalars(
            select(IpoEvent).options(joinedload(IpoEvent.investors))
        ).unique().all()
        if not ipos:
            return stats

        # Bereits vorhandene (ipo_id, investor_name) für Idempotenz.
        existing = {
            (inv.ipo_id, inv.investor_name)
            for ipo in ipos
            for inv in ipo.investors
        }

        for manager in managers:
            cik = str(manager.get("cik"))
            manager_name = manager.get("name") or f"CIK {cik}"
            try:
                holdings = provider(cik)
            except Exception as exc:  # noqa: BLE001 - ein Manager-Fehler stoppt nicht alle
                logger.warning("13F-Provider für %s fehlgeschlagen: %s", manager_name, exc)
                continue
            stats["investors_found"] += len(holdings)

            for ipo in ipos:
                match = next(
                    (h for h in holdings if issuer_matches(h.issuer, ipo.company_name)),
                    None,
                )
                if match is None:
                    continue
                key = (ipo.id, manager_name)
                if key in existing:
                    continue
                session.add(
                    IpoInvestor(
                        ipo_id=ipo.id,
                        investor_name=manager_name,
                        stake_note=_format_stake(match),
                    )
                )
                existing.add(key)
                stats["investors_linked"] += 1

        session.commit()
    return stats


def _format_stake(holding: Holding) -> str:
    """Kurze Notiz zur Position (Stückzahl/Wert) für die Anzeige."""
    parts = [f"Emittent: {holding.issuer}"]
    if holding.shares:
        parts.append(f"{holding.shares:,.0f} Stück")
    if holding.value:
        parts.append(f"Wert {holding.value:,.0f}")
    if holding.cusip:
        parts.append(f"CUSIP {holding.cusip}")
    return " | ".join(parts)
