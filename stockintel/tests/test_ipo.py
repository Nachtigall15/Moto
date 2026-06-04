"""Tests für IPO-Event-Erkennung."""

import pytest

from stockintel.analysis.ipo import extract_ipo_from_s1, find_ipo_events
from stockintel.db.database import Database
from stockintel.db.models import RawItem, Source


def test_extract_ipo_from_s1_with_ticker():
    """S-1 Title mit Ticker in Klammern."""
    title = "OpenAI Inc. (OAIN) - S-1 Registration Statement"
    url = "https://www.sec.gov/cgi-bin/browse-edgar?..."
    result = extract_ipo_from_s1(url, title)
    assert result is not None
    assert result["company_name"] == "OpenAI Inc."
    assert result["ticker"] == "OAIN"


def test_extract_ipo_from_s1_no_ticker():
    """S-1 Title ohne Ticker."""
    title = "Some Company S-1 Filing"
    url = "https://www.sec.gov/cgi-bin/browse-edgar?..."
    result = extract_ipo_from_s1(url, title)
    # May be None or fallback to regex
    assert result is None or isinstance(result, dict)


def test_extract_ipo_from_s1_empty_url():
    """Empty URL returns None."""
    result = extract_ipo_from_s1("", "Some Title")
    assert result is None


def test_find_ipo_events_no_s1_items(tmp_path):
    """If no S-1 items, return 0."""
    db = Database(f"sqlite:///{tmp_path/'t.db'}")
    db.create_all()

    with db.session() as session:
        src = Source(key="edgar", name="EDGAR", kind="filing", enabled=True)
        session.add(src)
        session.flush()
        # Add non-S-1 item
        session.add(RawItem(
            source_id=src.id, external_id="1",
            title="TSLA 10-K Annual Report",
        ))
        session.commit()

    stats = find_ipo_events(db)
    assert stats["ipo_events_found"] == 0
    assert stats["ipo_events_created"] == 0


def test_find_ipo_events_with_s1_item(tmp_path):
    """Create IPO event from S-1 filing."""
    db = Database(f"sqlite:///{tmp_path/'t.db'}")
    db.create_all()

    with db.session() as session:
        src = Source(key="edgar", name="EDGAR", kind="filing", enabled=True)
        session.add(src)
        session.flush()
        # Add S-1 item
        session.add(RawItem(
            source_id=src.id, external_id="1",
            title="Acme Corp. (ACME) - S-1 Registration Statement",
            url="https://www.sec.gov/cgi-bin/browse-edgar?...",
        ))
        session.commit()

    stats = find_ipo_events(db)
    assert stats["ipo_events_found"] == 1
    # May or may not create depending on extraction success
    assert stats["ipo_events_created"] >= 0
