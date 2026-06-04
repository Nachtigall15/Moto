"""FastAPI REST-Server für StockIntel.

Phase 5: HTTP-API + Scheduling.
Endpoints für Daten-Abfragen, Triage-Trigger, Recommendation-Updates.
"""

from __future__ import annotations

import logging
from contextlib import asynccontextmanager
from datetime import datetime, timedelta
from typing import TYPE_CHECKING

from apscheduler.schedulers.background import BackgroundScheduler
from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy import desc, select

from stockintel.analysis.scoring import generate_recommendations
from stockintel.analysis.triage import analyze_signals
from stockintel.config import load_settings
from stockintel.db.database import get_database
from stockintel.db.models import Company, Recommendation, Signal

if TYPE_CHECKING:
    from stockintel.db.database import Database

logger = logging.getLogger(__name__)

# Global scheduler
scheduler: BackgroundScheduler | None = None


class CompanyInfo(BaseModel):
    """Company mit Signal-Zähler."""
    ticker: str
    name: str
    sector: str | None
    signal_count: int


class SignalInfo(BaseModel):
    """Signal mit Company-Info."""
    ticker: str
    title: str | None
    direction: str
    relevance: int
    confidence: float


class RecommendationInfo(BaseModel):
    """Buy/Hold/Sell Recommendation."""
    ticker: str
    action: str
    confidence: float
    rationale: str | None


def schedule_background_tasks(db: Database) -> None:
    """Registriert Background-Tasks."""
    global scheduler
    settings = load_settings()

    if scheduler is None:
        scheduler = BackgroundScheduler()
        scheduler.start()

    # Analyze: jeden Tag um 09:00
    scheduler.add_job(
        func=lambda: _background_analyze(db, settings),
        trigger="cron",
        hour=9,
        minute=0,
        id="analyze_daily",
        replace_existing=True,
    )

    # Score: jeden Tag um 10:00
    scheduler.add_job(
        func=lambda: _background_score(db),
        trigger="cron",
        hour=10,
        minute=0,
        id="score_daily",
        replace_existing=True,
    )

    logger.info("Background tasks scheduled")


def _background_analyze(db: Database, settings) -> None:
    """Background: Analyze signals."""
    try:
        stats = analyze_signals(db, settings, limit=50)
        logger.info(f"Background analyze: {stats}")
    except Exception as e:
        logger.error(f"Background analyze failed: {e}")


def _background_score(db: Database) -> None:
    """Background: Generate recommendations."""
    try:
        stats = generate_recommendations(db)
        logger.info(f"Background score: {stats}")
    except Exception as e:
        logger.error(f"Background score failed: {e}")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """App lifecycle: startup + shutdown."""
    logger.info("StockIntel API starting")
    db = get_database(load_settings())
    schedule_background_tasks(db)
    yield
    if scheduler:
        scheduler.shutdown()
    logger.info("StockIntel API stopped")


def create_app() -> FastAPI:
    """Erstellt und konfiguriert die FastAPI-Anwendung."""
    app = FastAPI(
        title="StockIntel API",
        description="Markt-Intelligence-Engine REST-API",
        version="0.0.1",
        lifespan=lifespan,
    )

    settings = load_settings()
    db = get_database(settings)

    @app.get("/health")
    async def health():
        """Health Check."""
        return {"status": "ok", "version": "0.0.1"}

    @app.get("/companies", response_model=list[CompanyInfo])
    async def list_companies(limit: int = Query(50, ge=1, le=1000)):
        """Listet alle Companies mit Signal-Zähler."""
        from sqlalchemy import func

        with db.session() as session:
            rows = session.execute(
                select(
                    Company.ticker,
                    Company.name,
                    Company.sector,
                    func.count(Signal.id).label("signal_count"),
                )
                .outerjoin(Signal, Signal.company_id == Company.id)
                .group_by(Company.id)
                .order_by(Company.ticker)
                .limit(limit)
            ).all()

            return [
                CompanyInfo(
                    ticker=row.ticker,
                    name=row.name,
                    sector=row.sector,
                    signal_count=row.signal_count or 0,
                )
                for row in rows
            ]

    @app.get("/signals", response_model=list[SignalInfo])
    async def list_signals(
        limit: int = Query(50, ge=1, le=1000),
        ticker: str | None = None,
        analyzed_only: bool = False,
    ):
        """Listet Signals mit Filtern."""
        from stockintel.analysis.entity import RULE_BASED_MODEL

        with db.session() as session:
            stmt = select(Signal, Company.ticker).join(
                Company, Signal.company_id == Company.id
            )
            if ticker:
                stmt = stmt.where(Company.ticker == ticker.upper())
            if analyzed_only:
                stmt = stmt.where(Signal.model != RULE_BASED_MODEL)

            rows = session.execute(
                stmt.order_by(desc(Signal.relevance)).limit(limit)
            ).all()

            return [
                SignalInfo(
                    ticker=row.ticker,
                    title=(row[0].raw_item.title or "")[:80] if row[0].raw_item else None,
                    direction=row[0].direction.value,
                    relevance=row[0].relevance or 0,
                    confidence=row[0].confidence or 0.0,
                )
                for row in rows
            ]

    @app.get("/recommendations", response_model=list[RecommendationInfo])
    async def list_recommendations(limit: int = Query(50, ge=1, le=1000)):
        """Listet aktuelle Recommendations."""
        with db.session() as session:
            rows = session.execute(
                select(Company.ticker, Recommendation.action, Recommendation.confidence, Recommendation.rationale)
                .join(Recommendation, Recommendation.company_id == Company.id)
                .order_by(desc(Recommendation.confidence))
                .limit(limit)
            ).all()

            return [
                RecommendationInfo(
                    ticker=row.ticker,
                    action=row.action.value,
                    confidence=row.confidence,
                    rationale=row.rationale,
                )
                for row in rows
            ]

    @app.post("/analyze")
    async def trigger_analyze(limit: int = Query(20, ge=1, le=100)):
        """Triggert KI-Triage manuell."""
        try:
            stats = analyze_signals(db, settings, limit=limit)
            return {"status": "ok", "stats": stats}
        except RuntimeError as e:
            raise HTTPException(status_code=400, detail=str(e))

    @app.post("/score")
    async def trigger_score():
        """Triggert Buy/Hold/Sell Scoring manuell."""
        try:
            stats = generate_recommendations(db)
            return {"status": "ok", "stats": stats}
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))

    @app.get("/stats")
    async def get_stats():
        """Statistiken: Items, Signals, Companies, Recommendations."""
        from sqlalchemy import func

        with db.session() as session:
            from stockintel.db.models import RawItem

            item_count = session.scalar(select(func.count(RawItem.id)))
            signal_count = session.scalar(select(func.count(Signal.id)))
            company_count = session.scalar(select(func.count(Company.id)))
            rec_count = session.scalar(select(func.count(Recommendation.id)))

            return {
                "items": item_count,
                "signals": signal_count,
                "companies": company_count,
                "recommendations": rec_count,
                "timestamp": datetime.now().isoformat(),
            }

    return app


if __name__ == "__main__":
    import uvicorn

    app = create_app()
    uvicorn.run(app, host="0.0.0.0", port=8000)
