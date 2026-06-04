"""ORM-Datenmodell der StockIntel-Engine (SQLAlchemy 2.0).

Bildet die in PROJECT.md beschriebene Pipeline ab: von der eingesammelten
Rohinformation (RawItem) über bewertete Signale bis zu Empfehlungen, inklusive
des Event-Study-/Hickup-Moduls für historische Kursreaktionen.
"""

from __future__ import annotations

import datetime as dt
import enum

from sqlalchemy import (
    DateTime,
    Enum,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    pass


def _now() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


# --------------------------------------------------------------------------- #
# Enums — kontrollierte Vokabulare für Bewertung und Event-Study
# --------------------------------------------------------------------------- #
class Direction(enum.Enum):
    POSITIVE = "positive"
    NEUTRAL = "neutral"
    NEGATIVE = "negative"


class Impact(enum.Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"


class Horizon(enum.Enum):
    DAYS = "days"
    WEEKS = "weeks"
    MONTHS = "months"


class Action(enum.Enum):
    BUY = "buy"
    HOLD = "hold"
    SELL = "sell"


class EventType(enum.Enum):
    """Ereignistypen für historische Basisraten (Reaktionsprofile)."""

    CEO_COMMENT = "ceo_comment"
    EARNINGS = "earnings"
    GUIDANCE = "guidance"
    FDA = "fda"
    MA = "m_and_a"            # Merger & Acquisition
    IPO = "ipo"
    INSIDER = "insider"
    HIGH_PROFILE_POST = "high_profile_post"  # z.B. Musk/Trump
    OTHER = "other"


# --------------------------------------------------------------------------- #
# Stammdaten
# --------------------------------------------------------------------------- #
class Source(Base):
    """Eine Datenquelle / ein Collector-Adapter."""

    __tablename__ = "sources"

    id: Mapped[int] = mapped_column(primary_key=True)
    key: Mapped[str] = mapped_column(String(64), unique=True)   # z.B. "edgar"
    name: Mapped[str] = mapped_column(String(128))
    kind: Mapped[str] = mapped_column(String(32))               # rss/api/social/filing
    enabled: Mapped[bool] = mapped_column(default=True)
    created_at: Mapped[dt.datetime] = mapped_column(DateTime(timezone=True), default=_now)

    raw_items: Mapped[list["RawItem"]] = relationship(back_populates="source")


class Company(Base):
    """Ein Unternehmen / eine Aktie."""

    __tablename__ = "companies"

    id: Mapped[int] = mapped_column(primary_key=True)
    ticker: Mapped[str] = mapped_column(String(16), unique=True)
    name: Mapped[str] = mapped_column(String(256))
    sector: Mapped[str | None] = mapped_column(String(128), nullable=True)
    # Alternative Schreibweisen für die Entity-Resolution, als JSON-Text.
    aliases: Mapped[str | None] = mapped_column(Text, nullable=True)
    on_watchlist: Mapped[bool] = mapped_column(default=False)
    created_at: Mapped[dt.datetime] = mapped_column(DateTime(timezone=True), default=_now)

    signals: Mapped[list["Signal"]] = relationship(back_populates="company")
    events: Mapped[list["Event"]] = relationship(back_populates="company")
    recommendations: Mapped[list["Recommendation"]] = relationship(back_populates="company")


# --------------------------------------------------------------------------- #
# Ingestion & Bewertung
# --------------------------------------------------------------------------- #
class RawItem(Base):
    """Eingesammelte Rohinformation aus einer Quelle."""

    __tablename__ = "raw_items"
    __table_args__ = (UniqueConstraint("source_id", "external_id", name="uq_source_external"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    source_id: Mapped[int] = mapped_column(ForeignKey("sources.id"))
    external_id: Mapped[str | None] = mapped_column(String(256), nullable=True)
    url: Mapped[str | None] = mapped_column(Text, nullable=True)
    title: Mapped[str | None] = mapped_column(Text, nullable=True)
    body: Mapped[str | None] = mapped_column(Text, nullable=True)
    published_at: Mapped[dt.datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    fetched_at: Mapped[dt.datetime] = mapped_column(DateTime(timezone=True), default=_now)
    # Triage-Status: pending -> analyzed / skipped
    status: Mapped[str] = mapped_column(String(16), default="pending")

    source: Mapped["Source"] = relationship(back_populates="raw_items")
    signals: Mapped[list["Signal"]] = relationship(back_populates="raw_item")


class Signal(Base):
    """KI-Bewertung einer RawItem in Bezug auf ein Unternehmen."""

    __tablename__ = "signals"

    id: Mapped[int] = mapped_column(primary_key=True)
    raw_item_id: Mapped[int] = mapped_column(ForeignKey("raw_items.id"))
    company_id: Mapped[int] = mapped_column(ForeignKey("companies.id"))

    relevance: Mapped[int] = mapped_column(Integer)            # 0–100
    direction: Mapped[Direction] = mapped_column(Enum(Direction))
    impact: Mapped[Impact] = mapped_column(Enum(Impact))
    horizon: Mapped[Horizon] = mapped_column(Enum(Horizon))
    confidence: Mapped[float] = mapped_column(Float)           # 0.0–1.0
    rationale: Mapped[str | None] = mapped_column(Text, nullable=True)
    model: Mapped[str | None] = mapped_column(String(64), nullable=True)
    created_at: Mapped[dt.datetime] = mapped_column(DateTime(timezone=True), default=_now)

    raw_item: Mapped["RawItem"] = relationship(back_populates="signals")
    company: Mapped["Company"] = relationship(back_populates="signals")


# --------------------------------------------------------------------------- #
# Linking: Hype -> Profiteure, IPO -> Investoren
# --------------------------------------------------------------------------- #
class Theme(Base):
    """Ein Trend/Hype (z.B. 'KI-Infrastruktur')."""

    __tablename__ = "themes"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(128), unique=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[dt.datetime] = mapped_column(DateTime(timezone=True), default=_now)

    beneficiaries: Mapped[list["ThemeBeneficiary"]] = relationship(back_populates="theme")


class ThemeBeneficiary(Base):
    """Verbindung Hype -> profitierendes Unternehmen, mit Begründung."""

    __tablename__ = "theme_beneficiaries"
    __table_args__ = (UniqueConstraint("theme_id", "company_id", name="uq_theme_company"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    theme_id: Mapped[int] = mapped_column(ForeignKey("themes.id"))
    company_id: Mapped[int] = mapped_column(ForeignKey("companies.id"))
    strength: Mapped[float] = mapped_column(Float, default=0.0)   # 0.0–1.0
    rationale: Mapped[str | None] = mapped_column(Text, nullable=True)

    theme: Mapped["Theme"] = relationship(back_populates="beneficiaries")
    company: Mapped["Company"] = relationship()


class IpoEvent(Base):
    """Ein IPO/Börsengang."""

    __tablename__ = "ipo_events"

    id: Mapped[int] = mapped_column(primary_key=True)
    company_name: Mapped[str] = mapped_column(String(256))
    ticker: Mapped[str | None] = mapped_column(String(16), nullable=True)
    expected_date: Mapped[dt.datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    source_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[dt.datetime] = mapped_column(DateTime(timezone=True), default=_now)

    investors: Mapped[list["IpoInvestor"]] = relationship(back_populates="ipo")


class IpoInvestor(Base):
    """Bekannter Investor/Halter im Umfeld eines IPO (z.B. via S-1 / 13F)."""

    __tablename__ = "ipo_investors"

    id: Mapped[int] = mapped_column(primary_key=True)
    ipo_id: Mapped[int] = mapped_column(ForeignKey("ipo_events.id"))
    investor_name: Mapped[str] = mapped_column(String(256))
    stake_note: Mapped[str | None] = mapped_column(Text, nullable=True)

    ipo: Mapped["IpoEvent"] = relationship(back_populates="investors")


# --------------------------------------------------------------------------- #
# Event-Study / Hickup-Modul (historische Kursreaktionen)
# --------------------------------------------------------------------------- #
class Event(Base):
    """Ein kursrelevantes Ereignis mit Zeitstempel t0 für die Event-Study."""

    __tablename__ = "events"

    id: Mapped[int] = mapped_column(primary_key=True)
    company_id: Mapped[int] = mapped_column(ForeignKey("companies.id"))
    raw_item_id: Mapped[int | None] = mapped_column(ForeignKey("raw_items.id"), nullable=True)
    event_type: Mapped[EventType] = mapped_column(Enum(EventType), default=EventType.OTHER)
    t0: Mapped[dt.datetime] = mapped_column(DateTime(timezone=True))
    summary: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[dt.datetime] = mapped_column(DateTime(timezone=True), default=_now)

    company: Mapped["Company"] = relationship(back_populates="events")
    snapshots: Mapped[list["EventSnapshot"]] = relationship(back_populates="event")
    outcome: Mapped["EventOutcome | None"] = relationship(
        back_populates="event", uselist=False
    )


class EventSnapshot(Base):
    """Kursmesswert zu einem Offset nach t0 (+1h, +1d, …)."""

    __tablename__ = "event_snapshots"
    __table_args__ = (UniqueConstraint("event_id", "horizon", name="uq_event_horizon"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    event_id: Mapped[int] = mapped_column(ForeignKey("events.id"))
    horizon: Mapped[str] = mapped_column(String(8))           # "1h","4h","1d",...
    price: Mapped[float | None] = mapped_column(Float, nullable=True)
    benchmark_price: Mapped[float | None] = mapped_column(Float, nullable=True)
    captured_at: Mapped[dt.datetime] = mapped_column(DateTime(timezone=True), default=_now)

    event: Mapped["Event"] = relationship(back_populates="snapshots")


class EventOutcome(Base):
    """Berechnetes Ergebnis einer Event-Study inkl. Hickup-Klassifikation."""

    __tablename__ = "event_outcomes"

    id: Mapped[int] = mapped_column(primary_key=True)
    event_id: Mapped[int] = mapped_column(ForeignKey("events.id"), unique=True)
    baseline_price: Mapped[float | None] = mapped_column(Float, nullable=True)
    peak_return: Mapped[float | None] = mapped_column(Float, nullable=True)        # max Bewegung
    final_return: Mapped[float | None] = mapped_column(Float, nullable=True)       # am letzten Horizont
    abnormal_return: Mapped[float | None] = mapped_column(Float, nullable=True)    # vs. Benchmark
    # Strohfeuer: kurzfristiger Spike, der wieder abgegeben wird.
    is_hickup: Mapped[bool] = mapped_column(default=False)
    # ML-erkannte statistische Anomalie (Z-Score-basiert)
    is_anomaly: Mapped[bool] = mapped_column(default=False)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    computed_at: Mapped[dt.datetime] = mapped_column(DateTime(timezone=True), default=_now)

    event: Mapped["Event"] = relationship(back_populates="outcome")


class ReactionProfile(Base):
    """Aggregierte Basisrate je Ereignistyp (über viele Events gelernt)."""

    __tablename__ = "reaction_profiles"

    id: Mapped[int] = mapped_column(primary_key=True)
    event_type: Mapped[EventType] = mapped_column(Enum(EventType), unique=True)
    sample_size: Mapped[int] = mapped_column(Integer, default=0)
    avg_peak_return: Mapped[float | None] = mapped_column(Float, nullable=True)
    avg_final_return: Mapped[float | None] = mapped_column(Float, nullable=True)
    hickup_rate: Mapped[float | None] = mapped_column(Float, nullable=True)   # Anteil Strohfeuer
    updated_at: Mapped[dt.datetime] = mapped_column(DateTime(timezone=True), default=_now)


# --------------------------------------------------------------------------- #
# Empfehlung
# --------------------------------------------------------------------------- #
class Recommendation(Base):
    """Aggregierte Buy/Hold/Sell-Einschätzung pro Unternehmen."""

    __tablename__ = "recommendations"

    id: Mapped[int] = mapped_column(primary_key=True)
    company_id: Mapped[int] = mapped_column(ForeignKey("companies.id"))
    action: Mapped[Action] = mapped_column(Enum(Action))
    confidence: Mapped[float] = mapped_column(Float)          # 0.0–1.0
    score: Mapped[float | None] = mapped_column(Float, nullable=True)
    rationale: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[dt.datetime] = mapped_column(DateTime(timezone=True), default=_now)

    company: Mapped["Company"] = relationship(back_populates="recommendations")
