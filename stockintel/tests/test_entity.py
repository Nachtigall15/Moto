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


# --------------------------------------------------------------------------- #
# normalize_companies: Dedup + Muell-Entfernung
# --------------------------------------------------------------------------- #
def test_normalize_companies_merges_and_cleans(tmp_path):
    from stockintel.analysis.entity import normalize_companies
    from stockintel.db.models import Horizon, Impact

    db = Database(f"sqlite:///{tmp_path/'t.db'}")
    db.create_all()
    with db.session() as session:
        raws = _seed_source_and_items(session, [
            ("Apple launches iPhone", "Apple stock up"),   # ri0 -> APPLE (name)
            ("$AAPL hits record", "AAPL rally"),           # ri1 -> AAPL (ticker)
        ])
        aapl = Company(ticker="AAPL", name="Apple Inc.", sector="Technology", on_watchlist=True)
        apple = Company(ticker="APPLE", name="APPLE", on_watchlist=False)   # Duplikat
        penis = Company(ticker="PENIS", name="Penis", on_watchlist=False)   # Muell
        tencent = Company(ticker="TENCENT", name="TENCENT", on_watchlist=False)  # leerer Katalog-Rest
        session.add_all([aapl, apple, penis, tencent])
        session.flush()

        def mksig(raw, co):
            return Signal(raw_item_id=raw.id, company_id=co.id, relevance=80,
                          direction=Direction.NEUTRAL, impact=Impact.LOW, horizon=Horizon.DAYS,
                          confidence=0.0, rationale="rule", model="rule-based-v1")
        session.add_all([mksig(raws[1], aapl), mksig(raws[0], apple)])
        session.commit()

    report = normalize_companies(db)

    assert "APPLE -> AAPL" in report["merged"]
    assert "PENIS" in report["deleted"]
    # TENCENT loest auf TCEHY auf, hat aber 0 Signale + keine Watchlist -> entfernt
    assert "TCEHY" in report["deleted"]

    with db.session() as session:
        companies = list(session.scalars(select(Company)))
        assert [c.ticker for c in companies] == ["AAPL"]   # nur die kanonische bleibt
        aapl = companies[0]
        # Beide Signale (Ticker- und Name-Treffer) haengen jetzt an AAPL
        sig_count = len(list(session.scalars(select(Signal).where(Signal.company_id == aapl.id))))
        assert sig_count == 2
        # Alias "Apple" wurde aus dem Katalog gesetzt
        assert "Apple" in (aapl.aliases or "")


def test_normalize_companies_keeps_watchlist_pre_ipo(tmp_path):
    """Pre-IPO-Firmen auf der Watchlist (z.B. Anthropic) bleiben erhalten."""
    from stockintel.analysis.entity import normalize_companies

    db = Database(f"sqlite:///{tmp_path/'t.db'}")
    db.create_all()
    with db.session() as session:
        session.add(Company(ticker="ANTHROPIC", name="Anthropic", on_watchlist=True))
        session.commit()

    normalize_companies(db)
    with db.session() as session:
        tickers = [c.ticker for c in session.scalars(select(Company))]
        assert "ANTHROPIC" in tickers


# --------------------------------------------------------------------------- #
# Katalog
# --------------------------------------------------------------------------- #
def test_catalog_resolve_and_search():
    from stockintel.data import companies as catalog

    assert catalog.resolve_ticker("Apple") == "AAPL"
    assert catalog.resolve_ticker("APPLE") == "AAPL"
    assert catalog.resolve_ticker("865985") == "AAPL"           # WKN
    assert catalog.resolve_ticker("US0378331005") == "AAPL"     # ISIN
    assert catalog.resolve_ticker("tencent") == "TCEHY"
    assert catalog.resolve_ticker("voellig-unbekannt") is None  # kein Phantom

    res = catalog.search("siemens")
    assert res and res[0]["ticker"] == "SIE"
    assert res[0]["wkn"] and res[0]["isin"]


# --------------------------------------------------------------------------- #
# Qualitätssicherung: Inhalts-Substanz dämpft Müll-Posts
# --------------------------------------------------------------------------- #
def test_content_quality_downgrades_low_substance():
    from stockintel.analysis.entity import (
        CompanyMatcher, find_matches, score_relevance, quality_adjusted_relevance,
    )

    def qa(title, body):
        m = find_matches(CompanyMatcher(ticker="TSLA", name="Tesla"), title, body)
        return score_relevance(m), quality_adjusted_relevance(m, title, body, "TSLA", "Tesla")

    base_meme, qa_meme = qa("$TSLA", "")                       # nur Ticker, kein Text
    base_hype, qa_hype = qa("$TSLA to the moon 🚀 buy buy", "") # Pump-Hype
    base_news, qa_news = qa("TSLA Tesla recalls cars over brake defect, regulator opens probe",
                            "The recall affects 1.2 million vehicles.")  # echte News

    # Regel-Basis ist überall hoch (Ticker im Titel), aber die QA trennt klar:
    assert base_meme == base_hype  # gleiche rohe Regel-Basis
    assert qa_meme < 25 and qa_hype < 25      # Müll wird stark gedämpft
    assert qa_news > 60                        # echte News bleibt hoch
    assert qa_news > qa_meme and qa_news > qa_hype


def test_rescore_rule_based_downgrades_existing(tmp_path):
    from stockintel.analysis.entity import link_items, rescore_rule_based, sync_companies
    from sqlalchemy import select

    db = Database(f"sqlite:///{tmp_path/'t.db'}")
    db.create_all()
    sync_companies(db, [{"ticker": "TSLA", "name": "Tesla"}])
    with db.session() as session:
        _seed_source_and_items(session, [
            ("$TSLA", None),                                            # Müll -> niedrig
            ("TSLA Tesla beats earnings, raises full-year guidance", "Strong quarter."),  # News -> hoch
        ])
        session.commit()

    link_items(db)
    # Simuliere "alte" Daten: setze alle rule-based Signals zurück auf 80.
    with db.session() as session:
        for sig in session.scalars(select(Signal)):
            sig.relevance = 80
        session.commit()

    stats = rescore_rule_based(db)
    assert stats["downgraded"] >= 1

    with db.session() as session:
        sigs = {(_title_of(session, s)): s.relevance for s in session.scalars(select(Signal))}
    # Der reine "$TSLA"-Post ist jetzt deutlich niedriger als die echte News.
    meme = min(sigs.values())
    news = max(sigs.values())
    assert meme < 25 < news


def _title_of(session, signal):
    from stockintel.db.models import RawItem
    ri = session.get(RawItem, signal.raw_item_id)
    return ri.title if ri else ""
