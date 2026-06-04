"""Themes (Hypes) erkennen und Beneficiaries (Profiteure) verknüpfen.

Regelbasiert: Keyword-Patterns → Theme. Theme + Company-Sector → Beneficiary.
Beispiel: Signal mit "AI" oder "künstliche Intelligenz" → Theme "AI infrastructure"
         → Beneficiaries: Chip-Hersteller (Sector "Semiconductors"), Energieversorger, Rechenzentren-Betreiber.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import TYPE_CHECKING

from sqlalchemy import select
from sqlalchemy.orm import joinedload

from stockintel.db.models import Company, Signal, Theme, ThemeBeneficiary

if TYPE_CHECKING:
    from stockintel.db.database import Database


@dataclass
class ThemePattern:
    """Pattern zum Erkennen eines Themes aus Text."""
    theme_name: str
    keywords: list[str]  # Case-insensitive Matches
    beneficiary_sectors: list[str]  # Sektoren, die profitieren
    description: str


# Vordefinierte Patterns
THEME_PATTERNS = [
    ThemePattern(
        theme_name="AI Infrastructure",
        keywords=["artificial intelligence", "ai ", "machine learning", "llm", "generative ai", "transformer", "gpt"],
        beneficiary_sectors=["Semiconductors", "Cloud", "Energy", "Data Centers"],
        description="Investitionen in KI-Hardware, Chips und Infrastruktur.",
    ),
    ThemePattern(
        theme_name="Electric Vehicles",
        keywords=["electric vehicle", "ev ", "battery", "tesla", "semiconductor", "ev adoption"],
        beneficiary_sectors=["Semiconductors", "Energy", "Materials"],
        description="Elektromobilität und verwandte Zulieferer.",
    ),
    ThemePattern(
        theme_name="Renewable Energy",
        keywords=["renewable energy", "solar", "wind", "battery", "green energy", "sustainable"],
        beneficiary_sectors=["Energy", "Materials", "Technology"],
        description="Erneuerbare Energien und Infrastruktur.",
    ),
    ThemePattern(
        theme_name="Cloud Computing",
        keywords=["cloud", "aws", "azure", "gcp", "data center", "serverless"],
        beneficiary_sectors=["Cloud", "Semiconductors", "Energy"],
        description="Cloud-Plattformen und verwandte Infrastruktur.",
    ),
]


def extract_themes_from_text(text: str | None) -> list[str]:
    """Erkennt Theme-Namen aus Text via Keyword-Matching."""
    if not text:
        return []

    text_lower = text.lower()
    themes = []

    for pattern in THEME_PATTERNS:
        for keyword in pattern.keywords:
            if re.search(r'\b' + re.escape(keyword) + r'\b', text_lower):
                themes.append(pattern.theme_name)
                break  # Ein Match pro Pattern reicht

    return list(set(themes))  # Deduplizieren


def sync_themes(db: Database, patterns: list[ThemePattern] | None = None) -> int:
    """Stellt sicher, dass alle Themes in der DB existieren. Idempotent.

    Returns: Anzahl neu angelegter Themes.
    """
    patterns = patterns or THEME_PATTERNS
    new_count = 0

    with db.session() as session:
        existing_names = set(
            session.scalars(select(Theme.name)).all()
        )

        for pattern in patterns:
            if pattern.theme_name not in existing_names:
                session.add(Theme(name=pattern.theme_name, description=pattern.description))
                new_count += 1

        session.commit()

    return new_count


def link_themes_to_signals(db: Database) -> dict[str, int]:
    """Analysiert offene Signals, extrahiert Themes, verlinkt Beneficiaries.

    Idempotent: Pro Signal→Theme verlinkt nur einmal (uq_theme_company).
    Returns: {themes_found, beneficiaries_linked}.
    """
    stats = {"themes_found": 0, "beneficiaries_linked": 0}

    with db.session() as session:
        # Alle Signals mit RawItem (eager-loaded) laden
        signals = session.scalars(
            select(Signal).options(joinedload(Signal.raw_item))
        ).all()

        # Theme-Namen und ihre Beneficiary-Patterns
        theme_map: dict[str, ThemePattern] = {
            p.theme_name: p for p in THEME_PATTERNS
        }

        # Theme- und Company-Daten vorladen
        themes_by_name = {
            t.name: t for t in session.scalars(select(Theme)).all()
        }
        companies = {
            c.id: c for c in session.scalars(select(Company)).all()
        }

        # Existing Links vorladen (um Duplikate zu vermeiden)
        existing_links = set(
            session.scalars(
                select(ThemeBeneficiary.theme_id, ThemeBeneficiary.company_id)
            ).all()
        )

        for signal in signals:
            item = signal.raw_item
            # Text aus Item extrahieren
            text = f"{item.title or ''} {item.body or ''}".strip()
            if not text:
                continue

            # Themes erkennen
            theme_names = extract_themes_from_text(text)
            if not theme_names:
                continue

            stats["themes_found"] += len(theme_names)

            # Für jedes Theme: Beneficiaries verlinken
            for theme_name in theme_names:
                theme = themes_by_name.get(theme_name)
                pattern = theme_map.get(theme_name)
                if not theme or not pattern:
                    continue

                # Beneficiary-Sektoren normalisieren (einmal, nicht pro Company)
                target_sectors_lower = {s.lower() for s in pattern.beneficiary_sectors}

                # Finde Companies deren Sektor in Beneficiary-Sektoren liegt
                for company in companies.values():
                    if not company.sector:
                        continue

                    # Match: Sector in pattern.beneficiary_sectors?
                    if not any(s in company.sector.lower() for s in target_sectors_lower):
                        continue

                    # Duplikate meiden
                    if (theme.id, company.id) in existing_links:
                        continue

                    beneficiary = ThemeBeneficiary(
                        theme_id=theme.id,
                        company_id=company.id,
                        strength=0.7,  # Default; später verfeinert
                        rationale=f"Sector '{company.sector}' profitiert von Theme '{theme_name}'.",
                    )
                    session.add(beneficiary)
                    stats["beneficiaries_linked"] += 1
                    existing_links.add((theme.id, company.id))

        session.commit()

    return stats
