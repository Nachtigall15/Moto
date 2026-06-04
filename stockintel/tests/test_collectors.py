"""Tests für Phase-1-Collectors und Ingestion (ohne Netzwerk)."""

import feedparser

from stockintel.collectors.base import BaseCollector, CollectedItem
from stockintel.collectors.edgar import parse_company_tickers, parse_submissions
from stockintel.collectors.rss import parse_entries
from stockintel.db.database import Database
from stockintel.ingestion import ingest

SAMPLE_RSS = """<?xml version="1.0"?>
<rss version="2.0"><channel>
  <item>
    <title>Beispiel-Schlagzeile</title>
    <link>https://example.com/a</link>
    <guid>guid-a</guid>
    <description>Zusammenfassung A</description>
    <pubDate>Tue, 03 Jun 2026 10:00:00 GMT</pubDate>
  </item>
</channel></rss>"""

SAMPLE_TICKERS = {
    "0": {"cik_str": 320193, "ticker": "AAPL", "title": "Apple Inc."},
    "1": {"cik_str": 1045810, "ticker": "NVDA", "title": "NVIDIA CORP"},
}

SAMPLE_SUBMISSIONS = {
    "filings": {
        "recent": {
            "accessionNumber": ["0001045810-26-000001", "0001045810-26-000002"],
            "form": ["8-K", "10-Q"],
            "filingDate": ["2026-05-30", "2026-05-15"],
            "primaryDocument": ["nvda-8k.htm", "nvda-10q.htm"],
            "primaryDocDescription": ["CURRENT REPORT", "QUARTERLY REPORT"],
        }
    }
}


def test_parse_rss_entries():
    items = list(parse_entries(feedparser.parse(SAMPLE_RSS)))
    assert len(items) == 1
    assert items[0].title == "Beispiel-Schlagzeile"
    assert items[0].external_id == "guid-a"
    assert items[0].published_at is not None


def test_parse_company_tickers():
    mapping = parse_company_tickers(SAMPLE_TICKERS)
    assert mapping["NVDA"] == "0001045810"   # auf 10 Stellen aufgefüllt


def test_parse_submissions_builds_urls():
    items = list(parse_submissions("NVDA", "0001045810", SAMPLE_SUBMISSIONS))
    assert len(items) == 2
    assert items[0].external_id == "0001045810-26-000001"
    assert "edgar/data/1045810/000104581026000001/nvda-8k.htm" in items[0].url
    assert items[0].title.startswith("NVDA 8-K")


class _FakeCollector(BaseCollector):
    source_key = "fake"
    name = "Fake"
    kind = "api"

    def __init__(self, items):
        super().__init__({})
        self._items = items

    def fetch(self):
        return iter(self._items)


def _item(ext):
    return CollectedItem("fake", ext, f"title {ext}", None, f"https://x/{ext}", None)


def test_ingest_stores_and_deduplicates(tmp_path):
    db = Database(f"sqlite:///{tmp_path/'t.db'}")
    db.create_all()
    collector = _FakeCollector([_item("1"), _item("2"), _item("2")])

    assert ingest(db, collector) == 2          # ein Duplikat im selben Lauf
    assert ingest(db, collector) == 0          # erneuter Lauf: nichts Neues
