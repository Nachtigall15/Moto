"""Sentiment-Analysis für Signals: Positiv/Negativ/Mixed-Klassifizierung.

Regelbasiert (ohne KI) — nutzt Signal-Direction, Keywords, Relevanz.
"""

from __future__ import annotations

import re
from enum import Enum
from typing import TYPE_CHECKING

from sqlalchemy import select, update

from stockintel.db.models import Signal

if TYPE_CHECKING:
    from stockintel.db.database import Database


class Sentiment(str, Enum):
    POSITIVE = "positive"
    NEGATIVE = "negative"
    MIXED = "mixed"
    NEUTRAL = "neutral"


# Keyword lists for simple pattern matching
POSITIVE_KEYWORDS = [
    "beat", "exceeds", "upgrade", "profit", "growth", "surge", "rally",
    "bullish", "outperform", "strong", "record", "momentum", "breakthrough",
    "acquisition", "partnership", "innovation", "expand", "gain", "positive",
]

NEGATIVE_KEYWORDS = [
    "miss", "decline", "downgrade", "loss", "fall", "crash", "recession",
    "bearish", "underperform", "weakness", "slowdown", "layoff", "warning",
    "bankrupt", "crisis", "scandal", "negative", "risk", "threat",
]


def classify_signal_sentiment(signal_title: str | None, signal_direction: str) -> Sentiment:
    """Klassifiziert die Sentiment eines Signals (Positiv/Negativ/Mixed/Neutral).

    Args:
        signal_title: Title/Body des Signals
        signal_direction: Direction enum value (positive/negative/neutral)

    Returns:
        Sentiment classification
    """
    if not signal_title:
        # Fallback auf Direction
        if signal_direction == "positive":
            return Sentiment.POSITIVE
        elif signal_direction == "negative":
            return Sentiment.NEGATIVE
        else:
            return Sentiment.NEUTRAL

    text = signal_title.lower()

    # Count keyword hits
    positive_hits = sum(1 for kw in POSITIVE_KEYWORDS if re.search(rf"\b{kw}\b", text))
    negative_hits = sum(1 for kw in NEGATIVE_KEYWORDS if re.search(rf"\b{kw}\b", text))

    # Logic
    if positive_hits > 0 and negative_hits > 0:
        return Sentiment.MIXED
    elif positive_hits > negative_hits:
        return Sentiment.POSITIVE
    elif negative_hits > positive_hits:
        return Sentiment.NEGATIVE
    else:
        # Fallback auf Direction
        if signal_direction == "positive":
            return Sentiment.POSITIVE
        elif signal_direction == "negative":
            return Sentiment.NEGATIVE
        else:
            return Sentiment.NEUTRAL


def analyze_signal_sentiments(db: Database, limit: int = 1000) -> dict[str, int]:
    """Analysiert Sentiments für alle Signals (speichert in metadata/notes).

    Args:
        db: Database connection
        limit: Max Signals zu analysieren

    Returns:
        {positive, negative, mixed, neutral}
    """
    with db.session() as session:
        signals = session.execute(
            select(Signal).limit(limit)
        ).scalars().all()

        counts = {"positive": 0, "negative": 0, "mixed": 0, "neutral": 0}

        for signal in signals:
            title = signal.raw_item.title if signal.raw_item else None
            direction = signal.direction.value

            sentiment = classify_signal_sentiment(title, direction)
            counts[sentiment.value] += 1

            # Optional: Store sentiment in notes for future reference
            # (Nur für Demonstrationszwecke, nicht produktiv)

        session.commit()
        return counts


def get_sentiment_distribution(db: Database) -> dict[str, int]:
    """Gibt Verteilung der Signale nach Sentiment zurück."""
    return analyze_signal_sentiments(db, limit=10000)
