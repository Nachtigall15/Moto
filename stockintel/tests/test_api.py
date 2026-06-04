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
