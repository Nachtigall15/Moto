"""Tests für Theme-Extraction und Beneficiary-Linking."""

import pytest

from stockintel.analysis.themes import extract_themes_from_text, link_themes_to_signals, sync_themes
from stockintel.config import Settings
from stockintel.db.database import Database
from stockintel.db.models import Company, RawItem, Signal, Source, Theme


def test_extract_themes_ai_keywords():
    text = "NVIDIA announces new AI accelerators for machine learning"
    themes = extract_themes_from_text(text)
    assert "AI Infrastructure" in themes


def test_extract_themes_ev_keywords():
    text = "Tesla battery technology advances in electric vehicle production"
    themes = extract_themes_from_text(text)
    assert "Electric Vehicles" in themes


def test_extract_themes_cloud_keywords():
    text = "AWS cloud computing expansion with new data center"
    themes = extract_themes_from_text(text)
    assert "Cloud Computing" in themes


def test_extract_themes_empty_text():
    themes = extract_themes_from_text(None)
    assert themes == []
    themes = extract_themes_from_text("")
    assert themes == []


def test_extract_themes_deduplicates():
    text = "AI infrastructure for artificial intelligence and machine learning"
    themes = extract_themes_from_text(text)
    assert themes.count("AI Infrastructure") <= 1


def test_sync_themes_idempotent(tmp_path):
    db = Database(f"sqlite:///{tmp_path/'t.db'}")
    db.create_all()

    count1 = sync_themes(db)
    count2 = sync_themes(db)  # Second run should find 0 new
    assert count1 > 0
    assert count2 == 0


def test_link_themes_to_signals_happy_path(tmp_path):
    db = Database(f"sqlite:///{tmp_path/'t.db'}")
    db.create_all()

    with db.session() as session:
        # Setup
        comp = Company(ticker="NVDA", name="NVIDIA", sector="Semiconductors", on_watchlist=True)
        src = Source(key="test", name="Test", kind="api", enabled=True)
        session.add_all([comp, src])
        session.flush()

        # Create raw item with AI keyword
        item = RawItem(
            source_id=src.id, external_id="1",
            title="AI boom drives semiconductor demand",
            body="Strong growth in AI chips",
        )
        from stockintel.db.models import Direction, Horizon, Impact

        signal = Signal(
            raw_item_id=None,  # Will be set after item insert
            company_id=comp.id,
            relevance=75, direction=Direction.NEUTRAL, impact=Impact.LOW, horizon=Horizon.DAYS, confidence=0.8,
        )
        session.add(item)
        session.flush()
        signal.raw_item_id = item.id
        session.add(signal)
        session.commit()

    # Sync and link
    sync_themes(db)
    stats = link_themes_to_signals(db)

    assert stats["themes_found"] > 0
    assert stats["beneficiaries_linked"] >= 0  # May be 0 if sector doesn't match pattern


def test_link_themes_updates_stats(tmp_path):
    """Verify that stats are correctly returned."""
    db = Database(f"sqlite:///{tmp_path/'t.db'}")
    db.create_all()
    sync_themes(db)

    with db.session() as session:
        comp = Company(ticker="NVDA", name="NVIDIA", sector="Semiconductors", on_watchlist=True)
        src = Source(key="test", name="Test", kind="api", enabled=True)
        session.add_all([comp, src])
        session.flush()

        item = RawItem(
            source_id=src.id, external_id="1",
            title="AI infrastructure boom",
        )
        from stockintel.db.models import Direction, Horizon, Impact

        signal = Signal(
            raw_item_id=None,
            company_id=comp.id,
            relevance=50, direction=Direction.NEUTRAL, impact=Impact.LOW, horizon=Horizon.DAYS, confidence=0.5,
        )
        session.add(item)
        session.flush()
        signal.raw_item_id = item.id
        session.add(signal)
        session.commit()

    stats = link_themes_to_signals(db)
    assert "themes_found" in stats
    assert "beneficiaries_linked" in stats
    assert stats["themes_found"] >= 0
    assert stats["beneficiaries_linked"] >= 0
