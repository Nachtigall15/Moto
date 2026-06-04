"""Tägliche Reports für StockIntel: HTML-Export mit Top-Signals, Anomalien, Empfehlungen."""

from __future__ import annotations

import datetime as dt
from typing import TYPE_CHECKING

from sqlalchemy import desc, func, select
from sqlalchemy.orm import joinedload

from stockintel.db.models import Company, EventOutcome, Recommendation, Signal

if TYPE_CHECKING:
    from stockintel.db.database import Database


def generate_daily_report_html(db: Database, title: str = "StockIntel Daily Report") -> str:
    """Generiert einen HTML-Report mit Top-Signals, Anomalien, Empfehlungen.

    Args:
        db: Database connection
        title: Report title

    Returns:
        HTML string (ready for file output or email)
    """
    now = dt.datetime.now(dt.timezone.utc)
    date_str = now.strftime("%Y-%m-%d %H:%M UTC")

    with db.session() as session:
        # Top 10 Signals (höchste Relevanz)
        top_signals_data = []
        top_signals = session.execute(
            select(Signal, Company.ticker)
            .join(Company, Signal.company_id == Company.id)
            .options(joinedload(Signal.raw_item))
            .order_by(desc(Signal.relevance))
            .limit(10)
        ).all()
        for signal, ticker in top_signals:
            top_signals_data.append({
                'ticker': ticker,
                'direction': signal.direction.value,
                'relevance': signal.relevance,
                'confidence': signal.confidence,
                'title': (signal.raw_item.title or '')[:60] if signal.raw_item else '',
            })

        # Events mit Anomalien
        anomalies_data = []
        anomalies = session.execute(
            select(EventOutcome)
            .where(EventOutcome.is_anomaly.is_(True))
            .order_by(desc(func.abs(EventOutcome.abnormal_return)))
            .limit(5)
        ).scalars().all()
        for outcome in anomalies:
            anomalies_data.append({
                'event_id': outcome.event_id,
                'abnormal_return': outcome.abnormal_return or 0,
            })

        # Buy/Hold/Sell Recommendations
        recommendations_data = []
        recommendations = session.execute(
            select(Recommendation, Company.ticker)
            .join(Company, Recommendation.company_id == Company.id)
            .order_by(desc(Recommendation.confidence))
            .limit(10)
        ).all()
        for rec, ticker in recommendations:
            recommendations_data.append({
                'ticker': ticker,
                'action': rec.action.value,
                'confidence': rec.confidence,
                'rationale': rec.rationale or '–',
            })

    # HTML Template
    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{title}</title>
    <style>
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: #f5f5f5; color: #333; }}
        .container {{ max-width: 900px; margin: 0 auto; padding: 20px; background: white; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }}
        header {{ border-bottom: 3px solid #0066cc; padding-bottom: 20px; margin-bottom: 30px; }}
        h1 {{ font-size: 2rem; color: #0066cc; margin-bottom: 5px; }}
        .timestamp {{ color: #999; font-size: 0.9rem; }}
        h2 {{ font-size: 1.3rem; color: #0066cc; margin-top: 30px; margin-bottom: 15px; border-bottom: 1px solid #ddd; padding-bottom: 10px; }}
        table {{ width: 100%; border-collapse: collapse; margin-bottom: 20px; }}
        th, td {{ text-align: left; padding: 10px; border-bottom: 1px solid #ddd; }}
        th {{ background: #f0f0f0; font-weight: bold; }}
        tr:hover {{ background: #f9f9f9; }}
        .ticker {{ font-weight: bold; color: #0066cc; }}
        .positive {{ color: #4caf50; font-weight: bold; }}
        .negative {{ color: #f44336; font-weight: bold; }}
        .badge {{ display: inline-block; padding: 3px 8px; border-radius: 4px; font-size: 0.8rem; font-weight: bold; }}
        .badge-buy {{ background: #e8f5e9; color: #2e7d32; }}
        .badge-sell {{ background: #ffebee; color: #c62828; }}
        .badge-hold {{ background: #fff3e0; color: #e65100; }}
        .badge-anomaly {{ background: #fff3e0; color: #e65100; }}
        .alert-box {{ background: #fff3e0; border-left: 4px solid #ff9800; padding: 15px; margin-bottom: 20px; }}
        footer {{ margin-top: 40px; padding-top: 20px; border-top: 1px solid #ddd; color: #999; font-size: 0.85rem; text-align: center; }}
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>📊 {title}</h1>
            <p class="timestamp">Generated: {date_str}</p>
            <p style="margin-top: 10px; color: #666;">Kein Anlageberatungs-Tool — informatives Recherche-Werkzeug.</p>
        </header>

        <h2>🚨 Top Anomalien erkannt</h2>
        {_anomalies_html(anomalies_data) if anomalies_data else '<p style="color: #999;">Keine Anomalien erkannt.</p>'}

        <h2>🎯 Top Recommendations</h2>
        {_recommendations_html(recommendations_data) if recommendations_data else '<p style="color: #999;">Keine Empfehlungen vorhanden.</p>'}

        <h2>📡 Top Signals (nach Relevanz)</h2>
        {_signals_html(top_signals_data) if top_signals_data else '<p style="color: #999;">Keine Signals.</p>'}

        <footer>
            <p>StockIntel Engine v0.0.1 • Market Intelligence Dashboard</p>
        </footer>
    </div>
</body>
</html>"""
    return html


def _anomalies_html(anomalies_data) -> str:
    """Format anomalies into HTML table."""
    if not anomalies_data:
        return '<p style="color: #999;">Keine Anomalien.</p>'

    rows = ""
    for item in anomalies_data:
        abnorm = item['abnormal_return']
        color = "positive" if abnorm > 0 else "negative"
        rows += f"""<tr>
            <td>Event {item['event_id']}</td>
            <td><span class="{color}">{abnorm*100:.2f}%</span></td>
            <td><span class="badge badge-anomaly">⚠️ Outlier</span></td>
        </tr>"""

    return f"""<table>
        <thead>
            <tr><th>Event</th><th>Abnormal Return</th><th>Status</th></tr>
        </thead>
        <tbody>{rows}</tbody>
    </table>"""


def _recommendations_html(recommendations_data) -> str:
    """Format recommendations into HTML table."""
    if not recommendations_data:
        return '<p style="color: #999;">Keine Empfehlungen.</p>'

    rows = ""
    for item in recommendations_data:
        badge_class = f"badge-{item['action']}"
        rows += f"""<tr>
            <td class="ticker">{item['ticker']}</td>
            <td><span class="badge {badge_class}">{item['action'].upper()}</span></td>
            <td>{item['confidence']*100:.0f}%</td>
            <td>{item['rationale']}</td>
        </tr>"""

    return f"""<table>
        <thead>
            <tr><th>Ticker</th><th>Action</th><th>Confidence</th><th>Rationale</th></tr>
        </thead>
        <tbody>{rows}</tbody>
    </table>"""


def _signals_html(signals_data) -> str:
    """Format signals into HTML table."""
    if not signals_data:
        return '<p style="color: #999;">Keine Signals.</p>'

    rows = ""
    for item in signals_data:
        rows += f"""<tr>
            <td class="ticker">{item['ticker']}</td>
            <td><span class="badge" style="background: #e3f2fd; color: #1976d2;">{item['direction']}</span></td>
            <td>{item['relevance']}%</td>
            <td>{item['confidence']*100:.0f}%</td>
            <td>{item['title']}</td>
        </tr>"""

    return f"""<table>
        <thead>
            <tr><th>Ticker</th><th>Direction</th><th>Relevance</th><th>Confidence</th><th>Title</th></tr>
        </thead>
        <tbody>{rows}</tbody>
    </table>"""


def save_report_to_file(html: str, filepath: str) -> None:
    """Speichert HTML-Report in eine Datei.

    Args:
        html: HTML content
        filepath: Zieldatei (z.B. /tmp/report_20260604.html)
    """
    with open(filepath, "w", encoding="utf-8") as f:
        f.write(html)
