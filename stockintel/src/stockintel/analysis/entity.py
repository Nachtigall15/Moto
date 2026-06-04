"""Entity-Resolution (Phase 2, regelbasierte Vorstufe).

Ordnet eingesammelte ``RawItems`` den Unternehmen aus der Watchlist zu:
erkennt **Ticker** (case-sensitiv, mit/ohne ``$``) und **Firmennamen/Aliase**
(case-insensitiv) per Wort-Grenzen-Match in Titel + Body und legt fuer jeden
Treffer ein ``Signal`` mit neutralen Platzhalter-Bewertungen an.

Die echte Bewertung (Relevanz, Richtung, Kurswirkung, Begruendung) folgt durch
die KI-Triage in Phase 2 — diese Vorstufe liefert deterministisch die
Verkettung RawItem <-> Company, damit ``items --ticker NVDA`` u.ae. sofort
funktioniert.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field

from sqlalchemy import select

from stockintel.db.database import Database
from stockintel.db.models import Company, Direction, Horizon, Impact, RawItem, Signal

#: Marker im ``Signal.model``-Feld für die regelbasierte Vorstufe (noch nicht
#: KI-bewertet). Die KI-Triage selektiert genau diese Signals.
RULE_BASED_MODEL = "rule-based-v1"


@dataclass(slots=True)
class CompanyMatcher:
    """Suchmuster fuer ein Unternehmen, abgeleitet aus Ticker, Name, Aliasen."""

    ticker: str
    name: str
    aliases: tuple[str, ...] = ()
    _patterns: list[tuple[str, re.Pattern]] = field(default_factory=list, init=False, repr=False)

    def __post_init__(self) -> None:
        # Ticker case-sensitiv (Boersentexte schreiben sie konventionell GROSS;
        # Lowercase wuerde zu viele Falschtreffer geben).
        self._patterns.append(
            ("ticker", re.compile(rf"\${re.escape(self.ticker)}\b|\b{re.escape(self.ticker)}\b"))
        )
        self._patterns.append(
            ("name", re.compile(rf"\b{re.escape(self.name)}\b", re.IGNORECASE))
        )
        for alias in self.aliases:
            if not alias:
                continue
            self._patterns.append(
                ("alias", re.compile(rf"\b{re.escape(alias)}\b", re.IGNORECASE))
            )

    @property
    def patterns(self) -> list[tuple[str, re.Pattern]]:
        return self._patterns


@dataclass(slots=True, frozen=True)
class Match:
    """Ein einzelner Treffer: welche Art (ticker/name/alias), ob im Titel."""

    kind: str
    in_title: bool


def find_matches(matcher: CompanyMatcher, title: str | None, body: str | None) -> list[Match]:
    """Pure Funktion: alle Treffer eines Unternehmens in Titel+Body.

    Pro Kind (ticker/name/alias) maximal ein Treffer; in_title gewinnt, falls
    sowohl Titel als auch Body matchen.
    """
    title_text = title or ""
    body_text = body or ""
    seen: dict[str, Match] = {}
    for kind, pattern in matcher.patterns:
        t_hit = bool(pattern.search(title_text))
        b_hit = bool(pattern.search(body_text))
        if not (t_hit or b_hit):
            continue
        existing = seen.get(kind)
        if existing is None or (t_hit and not existing.in_title):
            seen[kind] = Match(kind=kind, in_title=t_hit)
    return list(seen.values())


def score_relevance(matches: list[Match]) -> int:
    """Pure Funktion: regelbasierte Relevanz 0-100.

    Ticker (spezifischer) > Name > Alias. Bonus, wenn der Treffer im Titel
    war oder mehrere unterschiedliche Treffer-Arten zusammenfallen.
    """
    if not matches:
        return 0
    base = 0
    for m in matches:
        if m.kind == "ticker":
            base = max(base, 70)
        elif m.kind == "name":
            base = max(base, 55)
        else:
            base = max(base, 40)
    bonus = 10 if any(m.in_title for m in matches) else 0
    if len({m.kind for m in matches}) >= 2:
        bonus += 5
    return min(100, base + bonus)


def _aliases_from_json(value: str | None) -> tuple[str, ...]:
    if not value:
        return ()
    try:
        parsed = json.loads(value)
    except json.JSONDecodeError:
        return ()
    if isinstance(parsed, list):
        return tuple(str(a) for a in parsed if a)
    return ()


def matcher_from_company(company: Company) -> CompanyMatcher:
    """Baut einen ``CompanyMatcher`` aus einem DB-``Company``-Datensatz."""
    return CompanyMatcher(
        ticker=company.ticker,
        name=company.name,
        aliases=_aliases_from_json(company.aliases),
    )


def sync_companies(db: Database, watchlist: list[dict]) -> int:
    """Spiegelt die Watchlist aus settings.yaml in die ``companies``-Tabelle.

    Idempotent: neue Eintraege werden angelegt, vorhandene aktualisiert
    (Name, Sektor, Aliase, ``on_watchlist=True``). Companies ausserhalb der
    Watchlist (z.B. spaeter via KI entdeckt) bleiben unangetastet.

    Returns:
        Anzahl der **neu** angelegten Companies.
    """
    new = 0
    with db.session() as session:
        for entry in watchlist:
            ticker = str(entry.get("ticker", "")).upper().strip()
            if not ticker:
                continue
            name = str(entry.get("name") or ticker)
            sector = entry.get("sector")
            aliases = entry.get("aliases")
            aliases_json = (
                json.dumps(list(aliases))
                if isinstance(aliases, list) and aliases
                else None
            )

            company = session.scalars(
                select(Company).where(Company.ticker == ticker)
            ).first()
            if company is None:
                session.add(Company(
                    ticker=ticker,
                    name=name,
                    sector=sector,
                    aliases=aliases_json,
                    on_watchlist=True,
                ))
                new += 1
            else:
                company.name = name
                company.sector = sector
                if aliases_json is not None:
                    company.aliases = aliases_json
                company.on_watchlist = True
        session.commit()
    return new


def link_items(db: Database) -> dict[str, int]:
    """Verknuepft RawItems mit Companies (regelbasiert) und legt Signals an.

    Idempotent: fuer jedes (raw_item, company)-Paar wird hoechstens ein Signal
    angelegt. Pro Lauf werden ausschliesslich neue Paare ergaenzt.

    Returns:
        ``{'items_scanned': int, 'signals_created': int}``.
    """
    stats = {"items_scanned": 0, "signals_created": 0}
    with db.session() as session:
        companies = list(session.scalars(select(Company)))
        if not companies:
            return stats
        matchers = [(c.id, matcher_from_company(c)) for c in companies]

        # Bereits verknuepfte (raw_item, company)-Paare einmal vorab laden.
        existing: set[tuple[int, int]] = set(
            session.execute(select(Signal.raw_item_id, Signal.company_id)).all()
        )

        for item in session.scalars(select(RawItem)):
            stats["items_scanned"] += 1
            for company_id, matcher in matchers:
                if (item.id, company_id) in existing:
                    continue
                matches = find_matches(matcher, item.title, item.body)
                if not matches:
                    continue
                kinds = sorted({m.kind for m in matches})
                session.add(Signal(
                    raw_item_id=item.id,
                    company_id=company_id,
                    relevance=score_relevance(matches),
                    direction=Direction.NEUTRAL,    # echte Bewertung -> KI (Phase 2)
                    impact=Impact.LOW,
                    horizon=Horizon.DAYS,
                    confidence=0.0,
                    rationale=f"rule-based match: {', '.join(kinds)}",
                    model=RULE_BASED_MODEL,
                ))
                existing.add((item.id, company_id))
                stats["signals_created"] += 1
        session.commit()
    return stats
