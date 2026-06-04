"""Tests für die CLI — Schwerpunkt: collect-Schleifen-Modus (ohne Netzwerk)."""

import argparse

from stockintel import cli


def _patch_collect(monkeypatch):
    """Ersetzt Settings/DB/Sammellauf/sleep durch Doubles und protokolliert Aufrufe."""
    calls = {"runs": 0, "sleeps": []}
    monkeypatch.setattr(cli, "load_settings", lambda: object())
    monkeypatch.setattr(cli, "get_database", lambda settings: object())

    def fake_once(settings, db):
        calls["runs"] += 1
        return 0

    monkeypatch.setattr(cli, "_collect_once", fake_once)
    monkeypatch.setattr(cli.time, "sleep", lambda s: calls["sleeps"].append(s))
    return calls


def test_collect_single_run(monkeypatch):
    calls = _patch_collect(monkeypatch)
    args = argparse.Namespace(loop=False, interval=600, count=0)
    assert cli.cmd_collect(args) == 0
    assert calls["runs"] == 1
    assert calls["sleeps"] == []          # Einzel-Lauf schläft nie


def test_collect_loop_runs_count_times(monkeypatch):
    calls = _patch_collect(monkeypatch)
    args = argparse.Namespace(loop=True, interval=5, count=3)
    assert cli.cmd_collect(args) == 0
    assert calls["runs"] == 3              # genau count Läufe
    assert calls["sleeps"] == [5, 5]       # zwischen den Läufen, nicht nach dem letzten


def test_collect_loop_resilient_to_errors(monkeypatch):
    calls = _patch_collect(monkeypatch)

    def boom(settings, db):
        calls["runs"] += 1
        raise RuntimeError("Quelle kaputt")

    monkeypatch.setattr(cli, "_collect_once", boom)
    args = argparse.Namespace(loop=True, interval=1, count=2)
    assert cli.cmd_collect(args) == 0     # Fehler bricht die Schleife nicht ab
    assert calls["runs"] == 2
