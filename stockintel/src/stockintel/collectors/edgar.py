"""SEC-EDGAR-Collector (Phase 1).

Holt die jüngsten Pflichtmeldungen der Watchlist-Unternehmen über die offiziellen
SEC-Endpunkte (ohne API-Key). Ablauf:

1. Ticker -> CIK über ``company_tickers.json``.
2. Jüngste Filings je CIK über ``data.sec.gov/submissions/CIK##########.json``.

Hinweis: Die SEC verlangt einen aussagekräftigen ``User-Agent`` mit Kontakt.
Setze ihn über ``collectors.edgar.user_agent`` oder die Umgebungsvariable
``STOCKINTEL_SEC_UA``.
"""

from __future__ import annotations

import datetime as dt
import os
from typing import Iterable

import httpx

from stockintel.collectors.base import BaseCollector, CollectedItem

TICKERS_URL = "https://www.sec.gov/files/company_tickers.json"
SUBMISSIONS_URL = "https://data.sec.gov/submissions/CIK{cik}.json"
DEFAULT_USER_AGENT = "stockintel research example@example.com"


def parse_company_tickers(data: dict) -> dict[str, str]:
    """Baut eine Abbildung Ticker -> zehnstellige CIK aus company_tickers.json."""
    out: dict[str, str] = {}
    for row in data.values():
        ticker = str(row.get("ticker", "")).upper()
        cik = row.get("cik_str")
        if ticker and cik is not None:
            out[ticker] = str(cik).zfill(10)
    return out


def _parse_date(value: str | None) -> dt.datetime | None:
    if not value:
        return None
    try:
        return dt.datetime.strptime(value, "%Y-%m-%d").replace(tzinfo=dt.timezone.utc)
    except ValueError:
        return None


def parse_submissions(ticker: str, cik: str, data: dict, limit: int = 20) -> Iterable[CollectedItem]:
    """Wandelt die submissions-JSON eines Unternehmens in CollectedItems um."""
    recent = data.get("filings", {}).get("recent", {})
    forms = recent.get("form", [])
    accessions = recent.get("accessionNumber", [])
    dates = recent.get("filingDate", [])
    docs = recent.get("primaryDocument", [])
    descs = recent.get("primaryDocDescription", [])

    count = min(len(accessions), limit) if limit else len(accessions)
    cik_int = int(cik)
    for i in range(count):
        accession = accessions[i]
        acc_nodash = accession.replace("-", "")
        doc = docs[i] if i < len(docs) else ""
        form = forms[i] if i < len(forms) else ""
        desc = descs[i] if i < len(descs) else ""
        url = f"https://www.sec.gov/Archives/edgar/data/{cik_int}/{acc_nodash}/{doc}"
        title = f"{ticker} {form}" + (f" — {desc}" if desc else "")
        yield CollectedItem(
            source_key="edgar",
            external_id=accession,
            title=title,
            body=desc or None,
            url=url,
            published_at=_parse_date(dates[i] if i < len(dates) else None),
        )


class EdgarCollector(BaseCollector):
    source_key = "edgar"
    name = "SEC EDGAR"
    kind = "filing"

    def __init__(self, config: dict | None = None) -> None:
        super().__init__(config)
        self.tickers = [str(t).upper() for t in self.config.get("tickers", [])]
        self.user_agent = (
            self.config.get("user_agent")
            or os.environ.get("STOCKINTEL_SEC_UA")
            or DEFAULT_USER_AGENT
        )
        self.limit = int(self.config.get("limit", 20))

    @staticmethod
    def _json_or_raise(resp: httpx.Response, what: str) -> dict:
        if resp.status_code != 200:
            raise RuntimeError(
                f"EDGAR-{what}: HTTP {resp.status_code} ({resp.text[:60]!r}). "
                "Ist der Host (sec.gov / data.sec.gov) in der Netzwerk-Allowlist?"
            )
        try:
            return resp.json()
        except ValueError as exc:
            raise RuntimeError(
                f"EDGAR-{what}: ungültige Antwort ({resp.text[:60]!r})."
            ) from exc

    def fetch(self) -> Iterable[CollectedItem]:
        if not self.tickers:
            return
        headers = {"User-Agent": self.user_agent, "Accept-Encoding": "gzip, deflate"}
        with httpx.Client(headers=headers, timeout=30.0) as client:
            cik_map = parse_company_tickers(self._json_or_raise(client.get(TICKERS_URL), "Tickerliste"))
            for ticker in self.tickers:
                cik = cik_map.get(ticker)
                if not cik:
                    continue
                resp = client.get(SUBMISSIONS_URL.format(cik=cik))
                if resp.status_code != 200:
                    continue
                yield from parse_submissions(ticker, cik, resp.json(), self.limit)
