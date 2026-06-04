"""FastAPI REST-Server für StockIntel.

Phase 5: HTTP-API + Scheduling.
Endpoints für Daten-Abfragen, Triage-Trigger, Recommendation-Updates.
"""

from __future__ import annotations

import logging
from contextlib import asynccontextmanager
from datetime import datetime, timedelta
from pathlib import Path
from typing import TYPE_CHECKING

from apscheduler.schedulers.background import BackgroundScheduler
from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from sqlalchemy import desc, func, select

from stockintel.analysis.scoring import generate_recommendations
from stockintel.analysis.triage import analyze_signals
from stockintel.config import load_settings
from stockintel.db.database import get_database
from stockintel.db.models import Company, Event, EventOutcome, EventSnapshot, Recommendation, ReactionProfile, Signal

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


class EventInfo(BaseModel):
    """Event with outcome."""
    ticker: str
    event_type: str
    created_at: str
    peak_return: float | None
    final_return: float | None
    abnormal_return: float | None
    is_hickup: bool


class ReactionProfileInfo(BaseModel):
    """Aggregated reaction statistics per event type."""
    event_type: str
    sample_size: int
    avg_peak_return: float
    avg_final_return: float
    hickup_rate: float


class TrackingStatusInfo(BaseModel):
    """Forward-Tracking status: pending and recent snapshots."""
    ticker: str
    event_type: str
    event_created_at: str
    pending_horizons: list[str]
    recent_snapshots: list[str]


class SnapshotInfo(BaseModel):
    """Price snapshot at event horizon."""
    horizon: str
    price: float


class EventDetailInfo(BaseModel):
    """Event with full details including snapshots."""
    ticker: str
    event_type: str
    created_at: str
    peak_return: float | None
    final_return: float | None
    abnormal_return: float | None
    is_hickup: bool
    snapshots: list[SnapshotInfo]


def schedule_background_tasks(db: Database) -> None:
    """Registriert Background-Tasks."""
    global scheduler
    settings = load_settings()

    if scheduler is None:
        scheduler = BackgroundScheduler()
        scheduler.start()

    # Collection: alle 7 Minuten frische Daten sammeln (Finnhub, RSS, etc.)
    # next_run_time=now sorgt für einen sofortigen ersten Lauf beim Start,
    # damit das Dashboard nicht 7 Minuten lang leer ist.
    scheduler.add_job(
        func=lambda: _background_collect(db, settings),
        trigger="interval",
        minutes=7,
        id="collect_frequent",
        replace_existing=True,
        next_run_time=datetime.now(),
    )

    # Analyze: alle 30 Minuten Signale analysieren
    scheduler.add_job(
        func=lambda: _background_analyze(db, settings),
        trigger="interval",
        minutes=30,
        id="analyze_frequent",
        replace_existing=True,
    )

    # Score: alle 60 Minuten neue Empfehlungen. Erster Lauf nach 2 Minuten,
    # damit der initiale Collect/Link fertig ist und Empfehlungen früh erscheinen.
    scheduler.add_job(
        func=lambda: _background_score(db),
        trigger="interval",
        hours=1,
        id="score_hourly",
        replace_existing=True,
        next_run_time=datetime.now() + timedelta(minutes=2),
    )

    # Forward-Tracking: alle 30 Minuten fällige Kurs-Snapshots erfassen.
    scheduler.add_job(
        func=lambda: _background_track(db, settings),
        trigger="interval",
        minutes=30,
        id="track_frequent",
        replace_existing=True,
    )

    # Event-Study: alle 2 Stunden Snapshots/Outcomes/Profile nachziehen.
    scheduler.add_job(
        func=lambda: _background_event_study(db, settings),
        trigger="interval",
        hours=2,
        id="event_study_frequent",
        replace_existing=True,
    )

    logger.info("Background tasks scheduled")


def _background_collect(db: Database, settings) -> None:
    """Background: Sammelt neue Daten von allen aktiven Collectors."""
    try:
        from stockintel.analysis.entity import link_items, sync_companies
        from stockintel.collectors import build_collectors
        from stockintel.ingestion import ingest

        collectors = build_collectors(settings)
        if not collectors:
            logger.warning("No active collectors configured")
            return

        total_items = 0
        for collector in collectors:
            try:
                count = ingest(db, collector)
                total_items += count
                if count > 0:
                    logger.info(f"Collected {count} items from {collector.source_key}")
            except Exception as e:
                logger.warning(f"Collection from {collector.source_key} failed: {e}")
                continue

        # Link new items to companies and create signals
        sync_companies(db, settings.watchlist)
        link_stats = link_items(db)
        logger.info(
            f"Background collect: {total_items} items, "
            f"{link_stats['signals_created']} signals created"
        )
    except Exception as e:
        logger.error(f"Background collect failed: {e}")


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


def _background_track(db: Database, settings) -> None:
    """Background: fällige Forward-Tracking-Snapshots erfassen."""
    try:
        from stockintel.analysis.eventstudy import capture_due_snapshots

        count = capture_due_snapshots(db, settings)
        logger.info(f"Background track: {count} snapshots captured")
    except Exception as e:
        logger.error(f"Background track failed: {e}")


def _background_event_study(db: Database, settings) -> None:
    """Background: Event-Study (Snapshots/Outcomes/Profile) aktualisieren."""
    try:
        from stockintel.analysis.eventstudy import run_event_study

        stats = run_event_study(db, settings, limit=100)
        logger.info(f"Background event-study: {stats}")
    except Exception as e:
        logger.error(f"Background event-study failed: {e}")


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

    @app.get("/events", response_model=list[EventInfo])
    async def list_events(limit: int = Query(50, ge=1, le=1000), ticker: str | None = None):
        """Listet Events mit Outcomes."""
        with db.session() as session:
            stmt = select(Event, Company.ticker, EventOutcome).join(
                Company, Event.company_id == Company.id
            ).outerjoin(EventOutcome, EventOutcome.event_id == Event.id)
            if ticker:
                stmt = stmt.where(Company.ticker == ticker.upper())
            stmt = stmt.order_by(desc(Event.created_at)).limit(limit)
            rows = session.execute(stmt).all()

            return [
                EventInfo(
                    ticker=row.ticker,
                    event_type=row[0].event_type.value if row[0].event_type else "unknown",
                    created_at=row[0].created_at.isoformat() if row[0].created_at else "",
                    peak_return=row[2].peak_return if row[2] else None,
                    final_return=row[2].final_return if row[2] else None,
                    abnormal_return=row[2].abnormal_return if row[2] else None,
                    is_hickup=row[2].is_hickup if row[2] else False,
                )
                for row in rows
            ]

    @app.get("/reaction-profiles", response_model=list[ReactionProfileInfo])
    async def list_reaction_profiles():
        """Listet aggregierte Reaction-Profiles pro Event-Typ."""
        with db.session() as session:
            rows = session.execute(select(ReactionProfile)).all()

            return [
                ReactionProfileInfo(
                    event_type=row[0].event_type.value if row[0].event_type else "unknown",
                    sample_size=row[0].sample_size or 0,
                    avg_peak_return=row[0].avg_peak_return or 0.0,
                    avg_final_return=row[0].avg_final_return or 0.0,
                    hickup_rate=row[0].hickup_rate or 0.0,
                )
                for row in rows
            ]

    @app.get("/tracking-status", response_model=list[TrackingStatusInfo])
    async def get_tracking_status(limit: int = Query(20, ge=1, le=100)):
        """Forward-Tracking Status: Events mit ausstehenden Snapshots."""
        from sqlalchemy import func

        with db.session() as session:
            # Events mit weniger Snapshots als erwartet (braucht Horizon-Info aus settings)
            events_with_snapshots = session.execute(
                select(
                    Event.id,
                    Company.ticker,
                    Event.event_type,
                    Event.created_at,
                    func.count(EventSnapshot.id).label("snapshot_count"),
                )
                .join(Company, Event.company_id == Company.id)
                .outerjoin(EventSnapshot, EventSnapshot.event_id == Event.id)
                .group_by(Event.id, Company.ticker, Event.event_type, Event.created_at)
                .order_by(desc(Event.created_at))
                .limit(limit)
            ).all()

            result = []
            for event_id, ticker, event_type, created_at, snap_count in events_with_snapshots:
                # Snapshots für dieses Event laden
                snapshots = session.execute(
                    select(EventSnapshot.horizon).where(EventSnapshot.event_id == event_id)
                ).scalars().all()

                recent = list(snapshots[-3:]) if snapshots else []
                pending_count = max(0, 6 - len(snapshots))  # Annahme: 6 Horizonte
                pending = [f"h{i+1}" for i in range(pending_count)]

                result.append(
                    TrackingStatusInfo(
                        ticker=ticker,
                        event_type=event_type.value if event_type else "unknown",
                        event_created_at=created_at.isoformat() if created_at else "",
                        pending_horizons=pending,
                        recent_snapshots=recent,
                    )
                )

            return result

    @app.get("/event/{event_id}", response_model=EventDetailInfo)
    async def get_event_detail(event_id: int):
        """Event-Details mit allen Snapshots für Zeitreihen-Visualisierung."""
        with db.session() as session:
            event = session.execute(
                select(Event, Company.ticker)
                .join(Company, Event.company_id == Company.id)
                .where(Event.id == event_id)
            ).first()

            if not event:
                raise HTTPException(status_code=404, detail="Event not found")

            evt, ticker = event
            snapshots = session.execute(
                select(EventSnapshot.horizon, EventSnapshot.price)
                .where(EventSnapshot.event_id == event_id)
                .order_by(EventSnapshot.horizon)
            ).all()

            outcome = session.execute(
                select(EventOutcome).where(EventOutcome.event_id == event_id)
            ).first()

            return EventDetailInfo(
                ticker=ticker,
                event_type=evt.event_type.value if evt.event_type else "unknown",
                created_at=evt.created_at.isoformat() if evt.created_at else "",
                peak_return=outcome[0].peak_return if outcome else None,
                final_return=outcome[0].final_return if outcome else None,
                abnormal_return=outcome[0].abnormal_return if outcome else None,
                is_hickup=outcome[0].is_hickup if outcome else False,
                snapshots=[
                    SnapshotInfo(horizon=snap[0], price=snap[1])
                    for snap in snapshots
                ],
            )

    @app.get("/abnormal-returns-ranking", response_model=list[EventInfo])
    async def abnormal_returns_ranking(limit: int = Query(30, ge=1, le=100)):
        """Abnormal Returns Ranking: Events sortiert nach abnormalem Einfluss."""
        with db.session() as session:
            rows = session.execute(
                select(Event, Company.ticker, EventOutcome)
                .join(Company, Event.company_id == Company.id)
                .outerjoin(EventOutcome, EventOutcome.event_id == Event.id)
                .where(EventOutcome.abnormal_return.isnot(None))
                .order_by(desc(func.abs(EventOutcome.abnormal_return)))
                .limit(limit)
            ).all()

            return [
                EventInfo(
                    ticker=row.ticker,
                    event_type=row[0].event_type.value if row[0].event_type else "unknown",
                    created_at=row[0].created_at.isoformat() if row[0].created_at else "",
                    peak_return=row[2].peak_return if row[2] else None,
                    final_return=row[2].final_return if row[2] else None,
                    abnormal_return=row[2].abnormal_return if row[2] else None,
                    is_hickup=row[2].is_hickup if row[2] else False,
                )
                for row in rows
            ]

    @app.get("/sentiment-distribution")
    async def get_sentiment_distribution():
        """Sentiment-Verteilung der Signals (Positiv/Negativ/Mixed/Neutral)."""
        from stockintel.analysis.sentiment import get_sentiment_distribution

        distribution = get_sentiment_distribution(db)
        return {
            "positive": distribution.get("positive", 0),
            "negative": distribution.get("negative", 0),
            "mixed": distribution.get("mixed", 0),
            "neutral": distribution.get("neutral", 0),
            "total": sum(distribution.values()),
        }

    @app.get("/export/signals.csv")
    async def export_signals_csv():
        """Export alle Signals als CSV."""
        from stockintel.delivery.exporters import export_signals_csv

        csv_data = export_signals_csv(db)
        return {
            "format": "text/csv",
            "data": csv_data,
        }

    @app.get("/export/events.csv")
    async def export_events_csv():
        """Export alle Events als CSV."""
        from stockintel.delivery.exporters import export_events_csv

        csv_data = export_events_csv(db)
        return {
            "format": "text/csv",
            "data": csv_data,
        }

    @app.get("/export/recommendations.json")
    async def export_recommendations_json():
        """Export alle Recommendations als JSON."""
        from stockintel.delivery.exporters import export_recommendations_json

        json_data = export_recommendations_json(db)
        return {
            "format": "application/json",
            "data": json_data,
        }

    @app.get("/correlations")
    async def get_correlations(min_correlation: float = Query(0.5, ge=0.0, le=1.0)):
        """Korrelierte Ticker-Paare (basierend auf Event-Returns)."""
        from stockintel.analysis.correlation import get_correlated_pairs

        pairs = get_correlated_pairs(db, min_correlation)
        return {
            "pairs": pairs,
            "min_threshold": min_correlation,
            "count": len(pairs),
        }

    @app.get("/sector-correlations")
    async def get_sector_correlations():
        """Durchschnittliche Korrelation innerhalb von Sektoren."""
        from stockintel.analysis.correlation import find_sector_correlations

        sector_corrs = find_sector_correlations(db)
        return {
            "sector_correlations": sector_corrs,
        }

    @app.get("/alerts/evaluate-default")
    async def evaluate_default_alerts():
        """Evaluiert vordefinierte Alert-Regeln."""
        from stockintel.delivery.alerts_custom import DEFAULT_RULES, evaluate_rules

        alerts = evaluate_rules(db, DEFAULT_RULES)
        return {
            "alerts_triggered": alerts,
            "total_matches": sum(len(v) for v in alerts.values()),
        }

    @app.get("/ticker/{ticker}")
    async def get_ticker_detail(ticker: str):
        """Ticker-Detailseite: Signals, Events, Recommendations."""
        from sqlalchemy.orm import joinedload

        with db.session() as session:
            company = session.execute(
                select(Company).where(Company.ticker == ticker.upper())
            ).first()

            if not company:
                raise HTTPException(status_code=404, detail=f"Ticker {ticker} not found")

            company = company[0]

            # Signals für diese Company
            signals = session.execute(
                select(Signal)
                .where(Signal.company_id == company.id)
                .options(joinedload(Signal.raw_item))
                .order_by(desc(Signal.relevance))
                .limit(20)
            ).scalars().all()

            # Events für diese Company
            events = session.execute(
                select(Event, EventOutcome)
                .where(Event.company_id == company.id)
                .outerjoin(EventOutcome, EventOutcome.event_id == Event.id)
                .order_by(desc(Event.created_at))
                .limit(10)
            ).all()

            # Recommendation für diese Company
            recommendation = session.execute(
                select(Recommendation).where(Recommendation.company_id == company.id)
            ).first()

            return {
                "ticker": company.ticker,
                "name": company.name,
                "sector": company.sector,
                "signal_count": len(signals),
                "event_count": len(events),
                "signals": [
                    {
                        "relevance": s.relevance,
                        "direction": s.direction.value,
                        "confidence": s.confidence,
                        "title": (s.raw_item.title or "")[:100] if s.raw_item else "",
                        "published_at": s.raw_item.published_at.isoformat() if s.raw_item and s.raw_item.published_at else "",
                    }
                    for s in signals
                ],
                "events": [
                    {
                        "event_type": row[0].event_type.value,
                        "created_at": row[0].created_at.isoformat(),
                        "peak_return": row[1].peak_return if row[1] else None,
                        "abnormal_return": row[1].abnormal_return if row[1] else None,
                        "is_hickup": row[1].is_hickup if row[1] else False,
                    }
                    for row in events
                ],
                "recommendation": {
                    "action": recommendation[0].action.value,
                    "confidence": recommendation[0].confidence,
                    "rationale": recommendation[0].rationale,
                } if recommendation else None,
            }

    # --- Web-Dashboard (Phase 6) ---------------------------------------- #
    web_dir = Path(__file__).resolve().parent / "web"
    if web_dir.is_dir():
        app.mount("/static", StaticFiles(directory=str(web_dir)), name="static")

        @app.get("/", include_in_schema=False)
        async def dashboard():
            """Liefert das Web-Dashboard aus."""
            return FileResponse(str(web_dir / "index.html"))

    return app


if __name__ == "__main__":
    import uvicorn

    app = create_app()
    uvicorn.run(app, host="0.0.0.0", port=8000)
