"""Correlation-Analyse: Welche Tickers bewegen sich zusammen?

Berechnet Korrelation basierend auf abnormale Returns von Events.
"""

from __future__ import annotations

import statistics
from collections import defaultdict
from typing import TYPE_CHECKING

from sqlalchemy import select

from stockintel.db.models import Company, Event, EventOutcome

if TYPE_CHECKING:
    from stockintel.db.database import Database


def pearson_correlation(x: list[float], y: list[float]) -> float | None:
    """Berechnet Pearson Korrelationskoeffizient zwischen zwei Listen."""
    if len(x) < 2 or len(y) < 2 or len(x) != len(y):
        return None

    try:
        mean_x = statistics.mean(x)
        mean_y = statistics.mean(y)

        numerator = sum((xi - mean_x) * (yi - mean_y) for xi, yi in zip(x, y))
        denominator = (
            (sum((xi - mean_x) ** 2 for xi in x) ** 0.5)
            * (sum((yi - mean_y) ** 2 for yi in y) ** 0.5)
        )

        if denominator == 0:
            return None

        return numerator / denominator
    except (statistics.StatisticsError, ZeroDivisionError):
        return None


def compute_ticker_correlations(db: Database) -> dict[tuple[str, str], float]:
    """Berechnet Korrelationen zwischen allen Ticker-Paaren (basierend auf Event-Returns).

    Returns:
        {(ticker1, ticker2): correlation_coefficient}
    """
    with db.session() as session:
        # Alle Tickers mit ihren Events laden
        ticker_returns = defaultdict(list)

        events = session.execute(
            select(Event, Company.ticker, EventOutcome)
            .join(Company, Event.company_id == Company.id)
            .outerjoin(EventOutcome, EventOutcome.event_id == Event.id)
            .where(EventOutcome.abnormal_return.isnot(None))
        ).all()

        for event, ticker, outcome in events:
            if outcome and outcome.abnormal_return is not None:
                ticker_returns[ticker].append(outcome.abnormal_return)

        # Korrelationen zwischen allen Paaren
        tickers = sorted(ticker_returns.keys())
        correlations = {}

        for i, ticker1 in enumerate(tickers):
            for ticker2 in tickers[i + 1:]:
                returns1 = ticker_returns[ticker1]
                returns2 = ticker_returns[ticker2]

                # Nur korrelieren wenn beide Tickers mindestens 3 Daten haben
                if len(returns1) >= 3 and len(returns2) >= 3:
                    corr = pearson_correlation(returns1, returns2)
                    if corr is not None:
                        correlations[(ticker1, ticker2)] = corr

        return correlations


def get_correlated_pairs(
    db: Database, min_correlation: float = 0.5
) -> list[dict[str, float]]:
    """Gibt korrelierte Ticker-Paare zurück (Korrelation >= min_correlation).

    Args:
        db: Database connection
        min_correlation: Mindest-Korrelationskoeffizient

    Returns:
        Liste von {ticker1, ticker2, correlation} dicts, sortiert nach Stärke
    """
    correlations = compute_ticker_correlations(db)

    pairs = [
        {"ticker1": t1, "ticker2": t2, "correlation": corr}
        for (t1, t2), corr in correlations.items()
        if abs(corr) >= min_correlation
    ]

    # Sortiere nach abs(correlation) absteigend
    pairs.sort(key=lambda x: abs(x["correlation"]), reverse=True)
    return pairs


def find_sector_correlations(db: Database) -> dict[str, float]:
    """Findet durchschnittliche Korrelation innerhalb von Sektoren."""
    with db.session() as session:
        companies = session.execute(select(Company)).scalars().all()

        sector_tickers = defaultdict(list)
        for company in companies:
            if company.sector:
                sector_tickers[company.sector].append(company.ticker)

        sector_correlations = {}

        for sector, tickers in sector_tickers.items():
            if len(tickers) < 2:
                continue

            correlations = compute_ticker_correlations(db)
            sector_corrs = [
                corr for (t1, t2), corr in correlations.items()
                if t1 in tickers and t2 in tickers
            ]

            if sector_corrs:
                sector_correlations[sector] = statistics.mean(sector_corrs)

        return sector_correlations
