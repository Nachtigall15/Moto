"""Tests für die KI-Triage — reine Funktionen, ohne Netzwerk/SDK."""

import types

import pytest

from stockintel.analysis import triage
from stockintel.config import Settings
from stockintel.db.models import Direction, Horizon, Impact


def test_build_triage_tool_schema():
    tool = triage.build_triage_tool()
    assert tool["name"] == "record_evaluation"
    props = tool["input_schema"]["properties"]
    # Enums stammen direkt aus den Modell-Enums
    assert set(props["direction"]["enum"]) == {"positive", "neutral", "negative"}
    assert set(props["impact"]["enum"]) == {"low", "medium", "high"}
    assert set(props["horizon"]["enum"]) == {"days", "weeks", "months"}
    assert set(tool["input_schema"]["required"]) == {
        "relevance", "direction", "impact", "horizon", "confidence", "rationale",
    }


def test_build_user_content_includes_company_and_text():
    text = triage.build_user_content("Rekordquartal", "Umsatz über Plan", "NVDA", "NVIDIA")
    assert "NVIDIA (NVDA)" in text
    assert "Rekordquartal" in text
    assert "Umsatz über Plan" in text


def test_build_user_content_handles_missing_text():
    text = triage.build_user_content(None, None, "TSLA", "Tesla")
    assert "(kein Textinhalt)" in text


def test_parse_triage_response_happy_path():
    fields = triage.parse_triage_response({
        "relevance": 80,
        "direction": "positive",
        "impact": "high",
        "horizon": "weeks",
        "confidence": 0.7,
        "rationale": "Starke Zahlen.",
    })
    assert fields["relevance"] == 80
    assert fields["direction"] is Direction.POSITIVE
    assert fields["impact"] is Impact.HIGH
    assert fields["horizon"] is Horizon.WEEKS
    assert fields["confidence"] == 0.7
    assert fields["rationale"] == "Starke Zahlen."


def test_parse_triage_response_clamps_and_defaults():
    fields = triage.parse_triage_response({
        "relevance": 250,          # -> 100
        "direction": "bullish",    # unbekannt -> NEUTRAL
        "impact": None,            # -> LOW
        "horizon": "",             # -> DAYS
        "confidence": 5.0,         # -> 1.0
        # rationale fehlt -> None
    })
    assert fields["relevance"] == 100
    assert fields["direction"] is Direction.NEUTRAL
    assert fields["impact"] is Impact.LOW
    assert fields["horizon"] is Horizon.DAYS
    assert fields["confidence"] == 1.0
    assert fields["rationale"] is None


def test_parse_triage_response_handles_garbage_numbers():
    fields = triage.parse_triage_response({
        "relevance": "n/a",
        "confidence": "hoch",
        "direction": "negative",
    })
    assert fields["relevance"] == 0          # nicht parsebar -> 0
    assert fields["confidence"] == 0.0
    assert fields["direction"] is Direction.NEGATIVE


def test_parse_triage_response_truncates_rationale():
    long_text = "x" * 5000
    fields = triage.parse_triage_response({"rationale": long_text})
    assert len(fields["rationale"]) == triage.MAX_RATIONALE_CHARS


def test_extract_tool_input_finds_block():
    content = [
        types.SimpleNamespace(type="text", text="…"),
        types.SimpleNamespace(
            type="tool_use", name="record_evaluation", input={"relevance": 42},
        ),
    ]
    assert triage.extract_tool_input(content) == {"relevance": 42}


def test_extract_tool_input_raises_without_tool_block():
    content = [types.SimpleNamespace(type="text", text="nur Text")]
    with pytest.raises(RuntimeError):
        triage.extract_tool_input(content)


def test_analyze_signals_requires_api_key(monkeypatch):
    monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
    # Schlüssel-Check läuft vor jeglichem DB-/Netzwerkzugriff -> db darf None sein.
    with pytest.raises(RuntimeError, match="ANTHROPIC_API_KEY"):
        triage.analyze_signals(db=None, settings=Settings(), limit=5)


def test_analyze_signals_end_to_end_with_fakes(tmp_path, monkeypatch):
    """Voller Pfad mit gefälschtem Anthropic-Client (kein Netzwerk)."""
    from stockintel.analysis.entity import link_items, sync_companies
    from stockintel.db.database import Database
    from stockintel.db.models import RawItem, Signal, Source

    db = Database(f"sqlite:///{tmp_path/'t.db'}")
    db.create_all()
    sync_companies(db, [{"ticker": "NVDA", "name": "NVIDIA"}])
    with db.session() as session:
        src = Source(key="t", name="Test", kind="api", enabled=True)
        session.add(src)
        session.flush()
        session.add(RawItem(
            source_id=src.id, external_id="x1",
            title="$NVDA Rekordquartal", body="Umsatz über Plan",
        ))
        session.commit()
    assert link_items(db)["signals_created"] == 1

    # Fake-Client, der das Tool deterministisch "aufruft".
    class _FakeMessages:
        def create(self, **kwargs):
            block = types.SimpleNamespace(
                type="tool_use", name="record_evaluation",
                input={
                    "relevance": 90, "direction": "positive", "impact": "high",
                    "horizon": "weeks", "confidence": 0.8, "rationale": "Top.",
                },
            )
            return types.SimpleNamespace(content=[block])

    fake_client = types.SimpleNamespace(messages=_FakeMessages())
    monkeypatch.setenv("ANTHROPIC_API_KEY", "test-key")
    monkeypatch.setattr(triage, "_build_client", lambda api_key: fake_client)

    stats = triage.analyze_signals(db, Settings(), limit=10)
    assert stats == {"pending": 1, "analyzed": 1, "errors": 0}

    # Signal wurde KI-bewertet (model != rule-based, Felder gesetzt).
    from sqlalchemy import select
    with db.session() as session:
        sig = session.scalars(select(Signal)).one()
        assert sig.direction is Direction.POSITIVE
        assert sig.relevance == 90
        assert sig.model != "rule-based-v1"

    # Erneuter Lauf: nichts mehr offen.
    assert triage.analyze_signals(db, Settings(), limit=10)["pending"] == 0
