"""IPO-Events erkennen und Investoren extrahieren.

Nutzt EDGAR S-1 Filings (Börsengang-Prospekte) und 13F-Filings (Investorenpositionen).
Phase 3b: regelbasiert + später KI-augmentiert.
"""

from __future__ import annotations

import re
from typing import TYPE_CHECKING

from sqlalchemy import select

from stockintel.db.models import IpoEvent, IpoInvestor, RawItem, Source

if TYPE_CHECKING:
    from stockintel.db.database import Database


# S-1 Filings sind explizit im EDGAR Form-Index
# 13F-HR: institutionelle Positionen (>$100M Portfolios)
S1_FORM_TYPE = "S-1"
S1_FORM_TYPES = ["S-1", "S-1/A", "S-1MEF"]  # S-1 + Amendments


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


def link_ipo_investors(db: Database) -> dict[str, int]:
    """Verknüpft IpoEvents mit Investoren (später: aus 13F Filings).

    Für jetzt: Stub (TODO nach 13F-Parsing).
    Returns: {investors_found, investors_linked}.
    """
    # Später: Parse 13F-Filings für institutional holdings
    # Für jetzt leeres Scaffold
    return {"investors_found": 0, "investors_linked": 0}
