"""Collector-Registry — baut die aktiven Adapter aus der Konfiguration.

Implementiert: RSS, EDGAR, StockTwits, Reddit, Finnhub und YouTube. Neue
Quellen werden hier ergänzt, sobald ihre Adapter existieren.
"""

from __future__ import annotations

from stockintel.collectors.base import BaseCollector
from stockintel.collectors.edgar import EdgarCollector
from stockintel.collectors.finnhub import FinnhubCollector
from stockintel.collectors.reddit import RedditCollector
from stockintel.collectors.rss import RssCollector
from stockintel.collectors.stocktwits import StockTwitsCollector
from stockintel.collectors.youtube import YouTubeCollector
from stockintel.config import Settings


def build_collectors(settings: Settings) -> list[BaseCollector]:
    """Erzeugt die laut Konfiguration aktivierten Collector-Instanzen."""
    cfg = settings.section("collectors")
    collectors: list[BaseCollector] = []
    watchlist_tickers = [w["ticker"] for w in settings.watchlist if w.get("ticker")]

    rss_cfg = cfg.get("rss", {})
    if isinstance(rss_cfg, dict) and rss_cfg.get("enabled"):
        collectors.append(RssCollector(rss_cfg))

    edgar_cfg = cfg.get("edgar", {})
    if isinstance(edgar_cfg, dict) and edgar_cfg.get("enabled"):
        params = dict(edgar_cfg)
        params["tickers"] = watchlist_tickers   # EDGAR fragt die Watchlist-Ticker ab
        collectors.append(EdgarCollector(params))

    st_cfg = cfg.get("stocktwits", {})
    if isinstance(st_cfg, dict) and st_cfg.get("enabled"):
        params = dict(st_cfg)
        params["tickers"] = watchlist_tickers   # StockTwits je Watchlist-Ticker
        collectors.append(StockTwitsCollector(params))

    rd_cfg = cfg.get("reddit", {})
    if isinstance(rd_cfg, dict) and rd_cfg.get("enabled"):
        collectors.append(RedditCollector(rd_cfg))

    fh_cfg = cfg.get("finnhub", {})
    if isinstance(fh_cfg, dict) and fh_cfg.get("enabled"):
        params = dict(fh_cfg)
        params["tickers"] = watchlist_tickers   # Finnhub-News je Watchlist-Ticker
        collectors.append(FinnhubCollector(params))

    yt_cfg = cfg.get("youtube", {})
    if isinstance(yt_cfg, dict) and yt_cfg.get("enabled"):
        collectors.append(YouTubeCollector(yt_cfg))

    return collectors
