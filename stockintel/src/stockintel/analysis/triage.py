"""KI-Triage (Phase 2) — strukturierte Bewertung via Anthropic-SDK.

Nimmt die regelbasiert erzeugten ``Signal``-Platzhalter (RawItem ⇄ Company) und
ruft je Signal ein günstiges **Triage-Modell** (Claude Haiku, aus
``models.triage`` in settings.yaml) auf. Das Modell liefert über **Tool-Use**
ein typisiertes Ergebnis:

    relevance  0–100        wie relevant ist die Info für das Unternehmen
    direction  positive/neutral/negative
    impact     low/medium/high
    horizon    days/weeks/months
    confidence 0.0–1.0
    rationale  kurze Begründung

Design:
- **Reine Funktionen** (Tool-Schema, Prompt-Aufbau, Antwort-Parsing) sind ohne
  Netzwerk testbar.
- ``anthropic`` wird **lazy** importiert — Modul und reine Funktionen laufen auch
  ohne installiertes SDK; nur der Live-Pfad braucht es (``pip install -e '.[analysis]'``).
- Fehlt ``ANTHROPIC_API_KEY``, wird mit klarer Meldung abgebrochen.
- Der System-Prompt nutzt **Prompt-Caching** (``cache_control``); greift erst ab
  der modellabhängigen Mindest-Prefixlänge, schadet aber nie.

> Kein Anlageberatungs-Tool. Die Ausgaben sind informativ.
"""

from __future__ import annotations

import os
from typing import Any

from sqlalchemy import select

from stockintel.analysis.entity import RULE_BASED_MODEL
from stockintel.config import Settings
from stockintel.db.database import Database
from stockintel.db.models import Company, Direction, Horizon, Impact, RawItem, Signal

DEFAULT_TRIAGE_MODEL = "claude-haiku-4-5-20251001"
TOOL_NAME = "record_evaluation"
MAX_RATIONALE_CHARS = 1000

SYSTEM_PROMPT = (
    "Du bist ein nüchterner Finanz-Analyst. Du bewertest, wie eine einzelne "
    "Markt-Information (News, Filing, Social-Post) auf ein konkretes Unternehmen "
    "wirkt. Du gibst KEINE Anlageberatung, sondern eine sachliche Einschätzung.\n\n"
    "Bewerte ausschließlich anhand des gelieferten Textes. Wenn der Text kaum "
    "Substanz hat (reine Werbung, Smalltalk, Spam), vergib niedrige Relevanz und "
    "niedrige Konfidenz. Sei kalibriert: 'high impact' nur bei klar kursrelevanten "
    "Ereignissen (Earnings, Guidance, M&A, Zulassungen, Großaufträge, "
    "Rechtsstreit). Antworte über das Tool 'record_evaluation' mit:\n"
    "- relevance: 0–100, wie stark die Info dieses Unternehmen betrifft.\n"
    "- direction: positive | neutral | negative (Richtung für den Kurs).\n"
    "- impact: low | medium | high (Stärke der erwartbaren Kurswirkung).\n"
    "- horizon: days | weeks | months (Zeithorizont der Wirkung).\n"
    "- confidence: 0.0–1.0 (wie sicher die Einschätzung ist).\n"
    "- rationale: ein bis zwei knappe Sätze Begründung, auf Deutsch.\n"
    "Gib für jede Information genau einen Tool-Aufruf zurück."
)


def build_triage_tool() -> dict[str, Any]:
    """Liefert die Tool-Definition für die strukturierte Triage (rein, testbar)."""
    return {
        "name": TOOL_NAME,
        "description": (
            "Erfasse die strukturierte Bewertung einer Markt-Information in Bezug "
            "auf ein konkretes Unternehmen."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "relevance": {
                    "type": "integer",
                    "description": "0–100: wie relevant die Info für das Unternehmen ist.",
                },
                "direction": {
                    "type": "string",
                    "enum": [d.value for d in Direction],
                    "description": "Erwartete Kursrichtung.",
                },
                "impact": {
                    "type": "string",
                    "enum": [i.value for i in Impact],
                    "description": "Stärke der erwartbaren Kurswirkung.",
                },
                "horizon": {
                    "type": "string",
                    "enum": [h.value for h in Horizon],
                    "description": "Zeithorizont der Wirkung.",
                },
                "confidence": {
                    "type": "number",
                    "description": "0.0–1.0: Sicherheit der Einschätzung.",
                },
                "rationale": {
                    "type": "string",
                    "description": "Ein bis zwei knappe Sätze Begründung (Deutsch).",
                },
            },
            "required": ["relevance", "direction", "impact", "horizon", "confidence", "rationale"],
        },
    }


def build_user_content(
    title: str | None, body: str | None, ticker: str, name: str
) -> str:
    """Baut den Nutzer-Prompt für ein (RawItem, Company)-Paar (rein, testbar)."""
    parts = [f"Unternehmen: {name} ({ticker})", "", "Information:"]
    if title:
        parts.append(f"Titel: {title}")
    if body:
        parts.append(f"Text: {body}")
    if not title and not body:
        parts.append("(kein Textinhalt)")
    return "\n".join(parts)


_DIRECTIONS = {d.value: d for d in Direction}
_IMPACTS = {i.value: i for i in Impact}
_HORIZONS = {h.value: h for h in Horizon}


def parse_triage_response(data: dict[str, Any]) -> dict[str, Any]:
    """Validiert und normalisiert die Tool-Ausgabe zu Signal-Feldern (rein, testbar).

    Defensiv: clamped Zahlen, mappt unbekannte/fehlende Enums auf sichere
    Defaults und kürzt die Begründung. Wirft nie — eine schlechte Modellantwort
    soll den Lauf nicht abbrechen.
    """
    try:
        relevance = int(data.get("relevance", 0))
    except (TypeError, ValueError):
        relevance = 0
    relevance = max(0, min(100, relevance))

    try:
        confidence = float(data.get("confidence", 0.0))
    except (TypeError, ValueError):
        confidence = 0.0
    confidence = max(0.0, min(1.0, confidence))

    direction = _DIRECTIONS.get(str(data.get("direction", "")).lower(), Direction.NEUTRAL)
    impact = _IMPACTS.get(str(data.get("impact", "")).lower(), Impact.LOW)
    horizon = _HORIZONS.get(str(data.get("horizon", "")).lower(), Horizon.DAYS)

    rationale = data.get("rationale")
    if rationale is not None:
        rationale = str(rationale).strip()[:MAX_RATIONALE_CHARS] or None

    return {
        "relevance": relevance,
        "direction": direction,
        "impact": impact,
        "horizon": horizon,
        "confidence": confidence,
        "rationale": rationale,
    }


def extract_tool_input(content: Any, tool_name: str = TOOL_NAME) -> dict[str, Any]:
    """Zieht das ``input`` des ersten passenden ``tool_use``-Blocks (rein, testbar)."""
    for block in content:
        if getattr(block, "type", None) == "tool_use" and getattr(block, "name", None) == tool_name:
            return dict(getattr(block, "input", {}) or {})
    raise RuntimeError("Antwort enthält keinen strukturierten 'tool_use'-Block.")


def _system_blocks() -> list[dict[str, Any]]:
    """System-Prompt als cachebarer Block (Prompt-Caching für tools + system)."""
    return [{
        "type": "text",
        "text": SYSTEM_PROMPT,
        "cache_control": {"type": "ephemeral"},
    }]


def _evaluate_one(client: Any, model: str, tool: dict, user_text: str) -> dict[str, Any]:
    """Ein Triage-Aufruf: erzwingt das Tool und gibt dessen Input zurück."""
    resp = client.messages.create(
        model=model,
        max_tokens=512,
        system=_system_blocks(),
        tools=[tool],
        tool_choice={"type": "tool", "name": TOOL_NAME},
        messages=[{"role": "user", "content": user_text}],
    )
    return extract_tool_input(resp.content)


def _build_client(api_key: str) -> Any:
    """Lazy-Import des Anthropic-SDK (nur für den Live-Pfad nötig)."""
    try:
        import anthropic  # lokaler Import: nur wenn Triage tatsächlich läuft
    except ImportError as exc:  # pragma: no cover - hängt von der Umgebung ab
        raise RuntimeError(
            "anthropic-SDK fehlt: pip install -e '.[analysis]' im stockintel-Verzeichnis."
        ) from exc
    return anthropic.Anthropic(api_key=api_key)


def analyze_signals(db: Database, settings: Settings, limit: int = 20) -> dict[str, int]:
    """Bewertet bis zu ``limit`` noch unbewertete Signals mit dem Triage-Modell.

    Selektiert Signals mit ``model == RULE_BASED_MODEL`` (regelbasierte Vorstufe),
    ruft je Signal das Triage-Modell auf und schreibt die KI-Bewertung zurück
    (``model`` wechselt auf die Triage-Modell-ID → wird nicht erneut bewertet).

    Returns:
        ``{'pending': int, 'analyzed': int, 'errors': int}``.

    Raises:
        RuntimeError: wenn ``ANTHROPIC_API_KEY`` fehlt oder das SDK nicht da ist.
    """
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        raise RuntimeError(
            "ANTHROPIC_API_KEY fehlt: in der .env setzen "
            "(https://console.anthropic.com/)."
        )
    models_cfg = settings.section("models")
    model = models_cfg.get("triage") or DEFAULT_TRIAGE_MODEL

    # Arbeit vorab laden, damit keine DB-Session über die Netzwerk-Aufrufe offen bleibt.
    with db.session() as session:
        rows = session.execute(
            select(Signal.id, RawItem.title, RawItem.body, Company.ticker, Company.name)
            .join(RawItem, Signal.raw_item_id == RawItem.id)
            .join(Company, Signal.company_id == Company.id)
            .where(Signal.model == RULE_BASED_MODEL)
            .order_by(Signal.id)
            .limit(limit)
        ).all()

    stats = {"pending": len(rows), "analyzed": 0, "errors": 0}
    if not rows:
        return stats

    client = _build_client(api_key)
    tool = build_triage_tool()

    for signal_id, title, body, ticker, name in rows:
        try:
            tool_input = _evaluate_one(
                client, model, tool, build_user_content(title, body, ticker, name)
            )
            fields = parse_triage_response(tool_input)
        except Exception as exc:  # noqa: BLE001 - pro Signal robust bleiben
            stats["errors"] += 1
            print(f"  Signal {signal_id}: Fehler bei der KI-Bewertung: {exc}")
            continue

        with db.session() as session:
            sig = session.get(Signal, signal_id)
            if sig is None:
                continue
            sig.relevance = fields["relevance"]
            sig.direction = fields["direction"]
            sig.impact = fields["impact"]
            sig.horizon = fields["horizon"]
            sig.confidence = fields["confidence"]
            sig.rationale = fields["rationale"]
            sig.model = model
            session.commit()
        stats["analyzed"] += 1

    return stats
