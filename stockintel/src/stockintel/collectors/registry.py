"""Collector-Registry — baut die aktiven Adapter aus der Konfiguration.

Phase 1 implementiert RSS und EDGAR. Weitere Quellen (Finnhub, Reddit,
StockTwits, YouTube) werden hier ergänzt, sobald ihre Adapter existieren.
"""

from __future__ import annotations

from stockintel.collectors.base import BaseCollector
from stockintel.collectors.edgar import EdgarCollector
from stockintel.collectors.rss import RssCollector
from stockintel.config import Settings


def build_collectors(settings: Settings) -> list[BaseCollector]:
    """Erzeugt die laut Konfiguration aktivierten Collector-Instanzen."""
    cfg = settings.section("collectors")
    collectors: list[BaseCollector] = []

    rss_cfg = cfg.get("rss", {})
    if isinstance(rss_cfg, dict) and rss_cfg.get("enabled"):
        collectors.append(RssCollector(rss_cfg))

    edgar_cfg = cfg.get("edgar", {})
    if isinstance(edgar_cfg, dict) and edgar_cfg.get("enabled"):
        params = dict(edgar_cfg)
        # EDGAR fragt die Watchlist-Ticker ab.
        params["tickers"] = [w["ticker"] for w in settings.watchlist if w.get("ticker")]
        collectors.append(EdgarCollector(params))

    return collectors
