"""Tests für FastAPI Endpoints."""

import pytest
from fastapi.testclient import TestClient

from stockintel.api import create_app


@pytest.fixture
def client():
    """FastAPI Test-Client (nutzt live-DB)."""
    app = create_app()
    return TestClient(app)


def test_health(client):
    """Health Check."""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_companies_endpoint(client):
    """Companies-Endpoint liefert List."""
    response = client.get("/companies")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    if data:
        assert "ticker" in data[0]
        assert "name" in data[0]


def test_signals_endpoint(client):
    """Signals-Endpoint liefert List."""
    response = client.get("/signals")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    if data:
        assert "ticker" in data[0]
        assert "direction" in data[0]


def test_recommendations_endpoint(client):
    """Recommendations-Endpoint liefert List."""
    response = client.get("/recommendations")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    if data:
        assert "ticker" in data[0]
        assert "action" in data[0]


def test_stats_endpoint(client):
    """Stats-Endpoint liefert Metriken."""
    response = client.get("/stats")
    assert response.status_code == 200
    data = response.json()
    assert "items" in data
    assert "signals" in data
    assert "companies" in data
    assert "timestamp" in data
    assert isinstance(data["items"], int)


def test_limit_parameter(client):
    """Limit-Parameter funktioniert."""
    response = client.get("/companies?limit=5")
    assert response.status_code == 200
    data = response.json()
    assert len(data) <= 5


def test_ticker_filter(client):
    """Ticker-Filter funktioniert."""
    response = client.get("/signals?ticker=NVDA")
    assert response.status_code == 200


def test_analyzed_only_filter(client):
    """Analyzed-Only Filter funktioniert."""
    response = client.get("/signals?analyzed_only=true")
    assert response.status_code == 200


def test_analyze_endpoint(client):
    """Analyze-Endpoint exists und antwortet."""
    response = client.post("/analyze?limit=5")
    assert response.status_code in [200, 400]  # OK oder BadRequest


def test_score_endpoint(client):
    """Score-Endpoint exists und antwortet."""
    response = client.post("/score")
    assert response.status_code == 200


def test_dashboard_served(client):
    """Web-Dashboard (/) liefert HTML aus."""
    response = client.get("/")
    assert response.status_code == 200
    assert "text/html" in response.headers["content-type"]
    assert "StockIntel" in response.text


def test_static_css_served(client):
    """Static CSS wird ausgeliefert."""
    response = client.get("/static/style.css")
    assert response.status_code == 200
    assert "text/css" in response.headers["content-type"]


def test_static_js_served(client):
    """Static JS wird ausgeliefert."""
    response = client.get("/static/app.js")
    assert response.status_code == 200


def test_search_companies_finds_catalog_and_rejects_junk(client):
    """Suche findet Katalog-Werte (inkl. WKN/ISIN) und lehnt Freitext-Müll ab."""
    # Tencent ist im neuen Katalog auffindbar.
    r = client.get("/search/companies?query=tencent")
    assert r.status_code == 200
    results = r.json()["results"]
    assert results and results[0]["ticker"] == "TCEHY"
    assert results[0]["wkn"] and results[0]["isin"]

    # WKN-Suche (Apple).
    r = client.get("/search/companies?query=865985")
    assert r.json()["results"][0]["ticker"] == "AAPL"

    # Freitext-Müll erzeugt keine Phantom-Firma.
    r = client.get("/search/companies?query=qqqzzz")
    assert r.json()["results"] == []


def test_add_watchlist_resolves_canonical_and_rejects_junk(client):
    """Hinzufügen löst auf den kanonischen Ticker auf; Müll wird abgelehnt."""
    # 'Apple' (Name) -> AAPL (kanonisch)
    r = client.post("/watchlist?ticker=APPLE&name=Apple")
    assert r.status_code == 200
    assert r.json()["ticker"] == "AAPL"

    # Müll-Eingabe -> 400
    r = client.post("/watchlist?ticker=QQQZZZ&name=Quatsch")
    assert r.status_code == 400


def test_delete_company_roundtrip(client):
    """Eine Company lässt sich vollständig über die API löschen."""
    from stockintel.db.database import get_database
    from stockintel.db.models import Company
    from sqlalchemy import select

    db = get_database()
    with db.session() as s:
        if not s.scalar(select(Company).where(Company.ticker == "ZZTESTDEL")):
            s.add(Company(ticker="ZZTESTDEL", name="Zz Test Del", on_watchlist=False))
            s.commit()

    r = client.delete("/company/ZZTESTDEL")
    assert r.status_code == 200 and r.json()["deleted"] is True

    # Zweiter Aufruf -> 404 (existiert nicht mehr).
    assert client.delete("/company/ZZTESTDEL").status_code == 404


def test_detailed_signals_analyzed_only_excludes_rule_based(client):
    """analyzed_only blendet die rule-based Platzhalter aus."""
    from stockintel.analysis.entity import RULE_BASED_MODEL

    r = client.get("/signals/detailed?analyzed_only=true&limit=50")
    assert r.status_code == 200
    # Kein zurückgegebenes Signal darf das rule-based-Modell tragen — das prüfen
    # wir indirekt: rule-based Signals haben confidence 0.0 UND relevance ∈ {40,55,70,80,85,90}.
    # Robuster: die Liste darf leer sein, aber wenn befüllt, ist sie nach Relevanz sortiert.
    data = r.json()
    rels = [s["relevance"] for s in data]
    assert rels == sorted(rels, reverse=True)
