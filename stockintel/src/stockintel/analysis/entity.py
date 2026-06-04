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

from sqlalchemy import func, select

from stockintel.data import companies as catalog
from stockintel.db.database import Database
from stockintel.db.models import (
    Company,
    Direction,
    Event,
    Horizon,
    Impact,
    RawItem,
    Recommendation,
    Signal,
    ThemeBeneficiary,
)

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


# Muster, die für die Substanz-Messung als "kein Inhalt" entfernt werden:
# Cashtags ($TSLA), @-Mentions, URLs.
_NOISE_RE = re.compile(r"\$[A-Za-z.]{1,6}\b|@\w+|https?://\S+|www\.\S+", re.IGNORECASE)
_WORD_RE = re.compile(r"[A-Za-zÄÖÜäöüß]{3,}")

# Füllwörter + typischer Pump-/Hype-Jargon, die KEINE inhaltliche Substanz
# tragen. So fällt "to the moon, buy buy buy, lfg 🚀" auf Substanz ~0.
_STOPWORDS = {
    # englische Füllwörter
    "the", "and", "for", "are", "you", "this", "that", "with", "from", "have",
    "will", "just", "not", "but", "all", "can", "get", "out", "now", "its",
    "was", "they", "what", "who", "why", "how", "when", "your", "our", "his",
    "her", "she", "him", "them", "any", "one", "two", "too", "lol", "lmao",
    # Pump-/Hype-Slang
    "buy", "sell", "moon", "rocket", "hold", "calls", "puts", "lfg", "hodl",
    "bull", "bear", "pump", "dump", "yolo", "send", "dip", "ath", "squeeze",
    "long", "short", "gonna", "wanna", "guys", "bro", "haha", "omg", "wtf",
    # deutsche Füllwörter
    "und", "der", "die", "das", "ist", "ein", "eine", "mit", "für", "auf",
    "den", "dem", "des", "wird", "sind", "war", "hat", "aber", "auch", "wie",
}


def content_substance(title: str | None, body: str | None, ticker: str, name: str) -> int:
    """Zählt die *bedeutungstragenden* Wörter eines Items (rein, testbar).

    Entfernt Cashtags, @-Mentions, URLs, den Ticker, die Namens-Tokens des
    Unternehmens sowie Füll-/Hype-Wörter und zählt danach die verbleibenden
    Wörter mit >= 3 Buchstaben. Ein reiner "$TSLA"-Meme-Post oder ein
    "to the moon 🚀 buy buy"-Hype hat so Substanz ~0, eine echte Schlagzeile viele.
    """
    text = f"{title or ''} {body or ''}"
    text = _NOISE_RE.sub(" ", text)
    # Firmen-eigene Tokens (Ticker + Namensbestandteile) zählen nicht als Substanz.
    own = {ticker.lower()}
    for part in re.split(r"\s+", name or ""):
        cleaned = part.strip().lower()
        if len(cleaned) >= 3:
            own.add(cleaned)
    words = [
        w for w in _WORD_RE.findall(text)
        if w.lower() not in own and w.lower() not in _STOPWORDS
    ]
    return len(words)


def content_quality_factor(title: str | None, body: str | None, ticker: str, name: str) -> float:
    """Qualitäts-Faktor 0..1 aus der Inhalts-Substanz (rein, testbar).

    Dient als deterministische Qualitätssicherung VOR der KI: substanzlose
    Social-Posts (nur Ticker + Bild) werden stark gedämpft, echte Nachrichten
    bleiben hoch bewertet.
    """
    n = content_substance(title, body, ticker, name)
    if n == 0:
        return 0.2
    if n <= 2:
        return 0.45
    if n <= 5:
        return 0.7
    if n <= 10:
        return 0.9
    return 1.0


def quality_adjusted_relevance(
    matches: list[Match], title: str | None, body: str | None, ticker: str, name: str
) -> int:
    """Regelbasierte Relevanz × Inhalts-Qualität, mit Mindestwert 5 (rein)."""
    base = score_relevance(matches)
    if base == 0:
        return 0
    factor = content_quality_factor(title, body, ticker, name)
    return max(5, round(base * factor))


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


def _merge_company(session, source: Company, target: Company) -> None:
    """Verschiebt alle Verknuepfungen von ``source`` auf ``target`` und loescht
    danach ``source``. Signale/Theme-Treffer werden dedupliziert."""
    # Signals: pro raw_item nur eines behalten.
    target_raw_ids = set(
        session.scalars(select(Signal.raw_item_id).where(Signal.company_id == target.id))
    )
    for sig in list(session.scalars(select(Signal).where(Signal.company_id == source.id))):
        if sig.raw_item_id in target_raw_ids:
            session.delete(sig)
        else:
            sig.company_id = target.id
            target_raw_ids.add(sig.raw_item_id)

    # ThemeBeneficiary: pro Theme nur eines (uq_theme_company).
    target_theme_ids = set(
        session.scalars(select(ThemeBeneficiary.theme_id).where(ThemeBeneficiary.company_id == target.id))
    )
    for tb in list(session.scalars(select(ThemeBeneficiary).where(ThemeBeneficiary.company_id == source.id))):
        if tb.theme_id in target_theme_ids:
            session.delete(tb)
        else:
            tb.company_id = target.id
            target_theme_ids.add(tb.theme_id)

    # Events: umhaengen (Snapshots/Outcomes haengen am Event, bleiben intakt).
    for ev in list(session.scalars(select(Event).where(Event.company_id == source.id))):
        ev.company_id = target.id

    # Recommendations der Quelle verwerfen (werden ohnehin neu berechnet).
    for rec in list(session.scalars(select(Recommendation).where(Recommendation.company_id == source.id))):
        session.delete(rec)

    target.on_watchlist = target.on_watchlist or source.on_watchlist
    session.flush()
    session.delete(source)


def _apply_catalog_metadata(company: Company, entry: dict) -> None:
    """Setzt Name/Sektor/Aliase aus dem Katalog auf eine Company."""
    company.name = entry["name"]
    if entry.get("sector"):
        company.sector = entry["sector"]
    if entry.get("aliases"):
        company.aliases = json.dumps(entry["aliases"])


def normalize_companies(db: Database) -> dict[str, list[str] | int]:
    """Raeumt die ``companies``-Tabelle auf: dedupliziert und entfernt Muell.

    Schritte (idempotent):

    1. **Merge/Rename** – jede Company wird ueber den Katalog auf ihren
       kanonischen Ticker aufgeloest (Ticker -> WKN -> ISIN -> Name/Alias).
       Mehrere Eintraege derselben Firma (z.B. ``AAPL`` + ``APPLE``) werden zu
       einem zusammengefuehrt; Signale/Events wandern mit.
    2. **Metadaten** – kanonische Companies bekommen Name/Sektor/Aliase aus dem
       Katalog (so matcht ``AAPL`` kuenftig auch reine "Apple"-News).
    3. **Muell entfernen** – Eintraege ohne Watchlist-Flag, ohne Signale und
       ohne Events werden geloescht (Phantom-Firmen wie ``PENIS``/``MTL`` und
       leere Katalog-Reste).

    Returns: Report mit den Listen ``merged``/``renamed``/``deleted`` und
    ``kept`` (Anzahl unveraenderter Companies).
    """
    report: dict[str, list[str] | int] = {"merged": [], "renamed": [], "deleted": [], "kept": 0}

    with db.session() as session:
        companies = list(session.scalars(select(Company)))
        by_ticker: dict[str, Company] = {c.ticker: c for c in companies}

        # --- Schritt 1 & 2: Merge / Rename / Metadaten ---
        for company in companies:
            canonical = catalog.resolve_ticker(company.ticker) or catalog.resolve_ticker(company.name)
            if canonical is None:
                continue  # unbekannt -> Schritt 3 entscheidet

            entry = catalog.get(canonical)
            if canonical == company.ticker:
                _apply_catalog_metadata(company, entry)
                continue

            target = by_ticker.get(canonical)
            if target is None or target is company:
                old = company.ticker
                company.ticker = canonical
                _apply_catalog_metadata(company, entry)
                by_ticker[canonical] = company
                report["renamed"].append(f"{old} -> {canonical}")
            else:
                _apply_catalog_metadata(target, entry)
                _merge_company(session, source=company, target=target)
                by_ticker.pop(company.ticker, None)
                report["merged"].append(f"{company.ticker} -> {canonical}")
        session.flush()

        # --- Schritt 3: leere/Muell-Eintraege entfernen ---
        for company in list(session.scalars(select(Company))):
            sig_count = session.scalar(
                select(func.count()).select_from(Signal).where(Signal.company_id == company.id)
            )
            ev_count = session.scalar(
                select(func.count()).select_from(Event).where(Event.company_id == company.id)
            )
            if not company.on_watchlist and not sig_count and not ev_count:
                report["deleted"].append(company.ticker)
                # restliche Recommendations entfernen, dann Company loeschen
                for rec in list(session.scalars(select(Recommendation).where(Recommendation.company_id == company.id))):
                    session.delete(rec)
                session.delete(company)
            else:
                report["kept"] = int(report["kept"]) + 1  # type: ignore[arg-type]

        session.commit()

    return report


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

        # Company-Metadaten (Ticker/Name) für die Substanz-Messung vorhalten.
        meta = {c.id: (c.ticker, c.name) for c in companies}

        for item in session.scalars(select(RawItem)):
            stats["items_scanned"] += 1
            for company_id, matcher in matchers:
                if (item.id, company_id) in existing:
                    continue
                matches = find_matches(matcher, item.title, item.body)
                if not matches:
                    continue
                kinds = sorted({m.kind for m in matches})
                ticker, name = meta[company_id]
                # Qualitätssicherung: substanzlose Posts (nur Ticker/Bild)
                # werden hier schon gedämpft, lange vor der KI-Triage.
                relevance = quality_adjusted_relevance(matches, item.title, item.body, ticker, name)
                session.add(Signal(
                    raw_item_id=item.id,
                    company_id=company_id,
                    relevance=relevance,
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


def rescore_rule_based(db: Database) -> dict[str, int]:
    """Berechnet die Relevanz aller noch regelbasierten Signals neu — inkl.
    der Inhalts-Qualitätssicherung. So werden auch bereits gesammelte
    Müll-Posts (z.B. ``$TSLA`` ohne Text) nachträglich runtergestuft.

    KI-bewertete Signals (``model != RULE_BASED_MODEL``) bleiben unberührt.

    Returns: ``{'rescored': int, 'downgraded': int}``.
    """
    stats = {"rescored": 0, "downgraded": 0}
    with db.session() as session:
        rows = session.execute(
            select(
                Signal.id, Signal.relevance, Signal.rationale,
                RawItem.title, RawItem.body, Company.ticker, Company.name,
            )
            .join(RawItem, Signal.raw_item_id == RawItem.id)
            .join(Company, Signal.company_id == Company.id)
            .where(Signal.model == RULE_BASED_MODEL)
        ).all()

        for sig_id, old_rel, rationale, title, body, ticker, name in rows:
            # Treffer-Arten aus der gespeicherten Begründung ableiten (ticker/name/alias).
            title_l = (title or "").lower()
            in_title = bool(ticker and ticker.lower() in title_l) or bool(name and name.lower() in title_l)
            matches: list[Match] = [
                Match(kind=kind, in_title=in_title)
                for kind in ("ticker", "name", "alias")
                if rationale and kind in rationale
            ]
            if not matches:
                matches = [Match(kind="ticker", in_title=in_title)]
            new_rel = quality_adjusted_relevance(matches, title, body, ticker, name)
            if new_rel != old_rel:
                sig = session.get(Signal, sig_id)
                sig.relevance = new_rel
                stats["rescored"] += 1
                if new_rel < old_rel:
                    stats["downgraded"] += 1
        session.commit()
    return stats
