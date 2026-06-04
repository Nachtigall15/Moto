"""Konfiguration laden — aus config/settings.yaml plus Umgebungsvariablen.

Bewusst leichtgewichtig (nur PyYAML), damit das Phase-0-Gerüst ohne weitere
Abhängigkeiten läuft.
"""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml

# Projektwurzel = .../stockintel  (drei Ebenen ueber dieser Datei: config.py ->
# stockintel -> src -> Projektwurzel)
ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DB_URL = "sqlite:///data/stockintel.db"


@dataclass
class Settings:
    """Geladene Einstellungen, aufgeloest aus YAML + Umgebung."""

    db_url: str = DEFAULT_DB_URL
    raw: dict[str, Any] = field(default_factory=dict)

    def section(self, name: str) -> dict[str, Any]:
        """Liefert eine Unter-Sektion der YAML-Konfiguration (oder {})."""
        value = self.raw.get(name, {})
        return value if isinstance(value, dict) else {}

    @property
    def watchlist(self) -> list[dict[str, Any]]:
        items = self.raw.get("watchlist", [])
        return items if isinstance(items, list) else []


def _load_dotenv(path: Path) -> None:
    """Minimaler .env-Loader (KEY=VALUE), ohne externe Abhängigkeit."""
    if not path.exists():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        key, value = key.strip(), value.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = value


def load_settings(config_path: Path | None = None) -> Settings:
    """Lädt Einstellungen. Reihenfolge der DB-URL-Priorität:

    1. Umgebungsvariable STOCKINTEL_DB_URL (explicit custom)
    2. Railway-Umgebungsvariablen (DATABASE_URL, POSTGRESQL_URL, etc.)
    3. database.url in settings.yaml
    4. Default (lokales SQLite)
    """
    _load_dotenv(ROOT / ".env")

    path = config_path or (ROOT / "config" / "settings.yaml")
    raw: dict[str, Any] = {}
    if path.exists():
        loaded = yaml.safe_load(path.read_text(encoding="utf-8"))
        if isinstance(loaded, dict):
            raw = loaded

    db_url = (
        os.environ.get("STOCKINTEL_DB_URL")
        or os.environ.get("DATABASE_URL")  # Railway PostgreSQL
        or os.environ.get("POSTGRESQL_URL")  # Railway alt
        or raw.get("database", {}).get("url")
        or DEFAULT_DB_URL
    )

    # SQLAlchemy 2.0 akzeptiert nur "postgresql://", nicht das alte
    # "postgres://" (das Railway/Heroku teils liefern). Normalisieren.
    if db_url.startswith("postgres://"):
        db_url = "postgresql://" + db_url[len("postgres://"):]

    # API-Keys aus Umgebungsvariablen (für Production-Secrets)
    if not os.environ.get("FINNHUB_API_KEY"):
        if raw.get("finnhub", {}).get("api_key"):
            os.environ["FINNHUB_API_KEY"] = raw["finnhub"]["api_key"]

    return Settings(db_url=db_url, raw=raw)
