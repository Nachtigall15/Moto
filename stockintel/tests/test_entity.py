"""Tests fuer die regelbasierte Entity-Resolution (Phase 2-Vorstufe)."""

import datetime as dt

from sqlalchemy import select

from stockintel.analysis.entity import (
    CompanyMatcher,
    find_matches,
    link_items,
    score_relevance,
    sync_companies,
)
from stockintel.db.database import Database
from stockintel.db.models import Company, Direction, RawItem, Signal, Source


def _matcher_tesla() -> CompanyMatcher:
    return CompanyMatcher(ticker="TSLA", name="Tesla", aliases=("Tesla Motors",))


def test_find_matches_ticker_in_title():
    m = _matcher_tesla()
    matches = find_matches(m, title="$TSLA pumpt hart", body=None)
    kinds = [x.kind for x in matches]
    assert "ticker" in kinds
    assert all(x.in_title for x in matches if x.kind == "ticker")


def test_find_matches_name_in_body_case_insensitive():
    m = _matcher_tesla()
    matches = find_matches(m, title="Marktbericht", body="tesla hat geliefert")
    assert any(x.kind == "name" and not x.in_title for x in matches)


def test_find_matches_alias_hit():
    m = _matcher_tesla()
    matches = find_matches(m, title=None, body="Tesla Motors meldet ...")
    # 'Tesla' UND 'Tesla Motors' matchen beide (name + alias)
    kinds = {x.kind for x in matches}
    assert "name" in kinds and "alias" in kinds


def test_find_matches_avoids_false_positives_via_word_boundary():
    m = _matcher_tesla()
    # 'TSLA' steckt in 'BLATSLAVE', 'Tesla' in 'Teslawatch' — beide ohne Wortgrenze
    matches = find_matches(m, title="BLATSLAVE Teslawatch", body=None)
    assert matches == []


def test_find_matches_ticker_case_sensitive():
    m = _matcher_tesla()
    # Kleingeschriebenes 'tsla' soll NICHT als Ticker matchen (sonst zu viele
    # Falschtreffer in Lauftext). Name 'tesla' ist case-insensitiv erlaubt.
    matches = find_matches(m, title="tsla irgendwas", body=None)
    assert all(x.kind != "ticker" for x in matches)


def test_score_relevance_ordering():
    # Ticker (70) > Name (55) > Alias (40)
    only_ticker = [find_matches(_matcher_tesla(), "$TSLA", None)[0]]
    only_name = [find_matches(_matcher_tesla(), "Tesla News", None)[0]]
    assert score_relevance(only_ticker) > score_relevance(only_name)


def test_score_relevance_title_bonus_and_multi_kind():
    m = _matcher_tesla()
    in_body = find_matches(m, title=None, body="$TSLA und Tesla erwaehnt")
    in_title = find_matches(m, title="$TSLA und Tesla erwaehnt", body=None)
    # Beide haben mehrere Kinds -> +5; in_title hat zusaetzlich +10
    assert score_relevance(in_title) == score_relevance(in_body) + 10
    # Mit ticker+name in_title: 70 (base) + 10 (title) + 5 (multi) = 85
    assert score_relevance(in_title) == 85


def test_score_relevance_no_matches_is_zero():
    assert score_relevance([]) == 0


def _seed_source_and_items(session, items: list[tuple[str, str | None]]):
    src = Source(key="t", name="Test", kind="api", enabled=True)
    session.add(src)
    session.flush()
    raws = []
    for i, (title, body) in enumerate(items):
        raw = RawItem(
            source_id=src.id, external_id=f"x{i}", title=title, body=body,
            published_at=dt.datetime(2026, 6, 4, tzinfo=dt.timezone.utc),
        )
        session.add(raw)
        raws.append(raw)
    session.flush()
    return raws


def test_sync_companies_creates_and_updates(tmp_path):
    db = Database(f"sqlite:///{tmp_path/'t.db'}")
    db.create_all()
    wl = [
        {"ticker": "NVDA", "name": "NVIDIA", "sector": "Semis"},
        {"ticker": "TSLA", "name": "Tesla", "sector": "Auto",
         "aliases": ["Tesla Motors"]},
    ]
    assert sync_companies(db, wl) == 2     # zwei neu
    assert sync_companies(db, wl) == 0     # idempotent

    # Update: Sektor aendern
    wl[0]["sector"] = "Semiconductors"
    sync_companies(db, wl)
    with db.session() as session:
        nvda = session.scalars(select(Company).where(Company.ticker == "NVDA")).one()
        assert nvda.sector == "Semiconductors"
        assert nvda.on_watchlist is True
        tsla = session.scalars(select(Company).where(Company.ticker == "TSLA")).one()
        assert "Tesla Motors" in (tsla.aliases or "")


def test_link_items_end_to_end(tmp_path):
    db = Database(f"sqlite:///{tmp_path/'t.db'}")
    db.create_all()
    sync_companies(db, [
        {"ticker": "NVDA", "name": "NVIDIA"},
        {"ticker": "TSLA", "name": "Tesla"},
    ])
    with db.session() as session:
        _seed_source_and_items(session, [
            ("$TSLA pumpt", None),                       # -> TSLA
            ("Marktbericht", "NVIDIA meldet Rekord"),    # -> NVDA
            ("Reine Werbung", None),                     # -> nichts
            ("$TSLA und NVDA News", "Tesla + NVIDIA"),   # -> beide
        ])
        session.commit()

    stats = link_items(db)
    assert stats["items_scanned"] == 4
    assert stats["signals_created"] == 4    # 1 + 1 + 0 + 2

    # Erneuter Lauf ist idempotent
    again = link_items(db)
    assert again["signals_created"] == 0

    # Sanity-Check der Signale
    with db.session() as session:
        sigs = list(session.scalars(select(Signal)))
        assert len(sigs) == 4
        # Alle bekommen NEUTRAL als Platzhalter
        assert all(s.direction == Direction.NEUTRAL for s in sigs)
        assert all(s.model == "rule-based-v1" for s in sigs)
