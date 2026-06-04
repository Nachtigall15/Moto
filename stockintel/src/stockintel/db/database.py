"""Engine-/Session-Verwaltung für die Datenbank."""

from __future__ import annotations

from pathlib import Path

from sqlalchemy import create_engine
from sqlalchemy.engine import Engine, make_url
from sqlalchemy.orm import Session, sessionmaker

from stockintel.config import ROOT, Settings, load_settings
from stockintel.db.models import Base


class Database:
    """Kapselt SQLAlchemy-Engine und Session-Factory."""

    def __init__(self, url: str) -> None:
        self.url = url
        self._ensure_sqlite_dir(url)
        self.engine: Engine = create_engine(url, future=True)
        self._session_factory = sessionmaker(bind=self.engine, future=True)

    @staticmethod
    def _ensure_sqlite_dir(url: str) -> None:
        """Legt das Verzeichnis für eine lokale SQLite-Datei an, falls nötig."""
        parsed = make_url(url)
        if parsed.drivername.startswith("sqlite") and parsed.database:
            db_path = Path(parsed.database)
            if not db_path.is_absolute():
                db_path = ROOT / db_path
            db_path.parent.mkdir(parents=True, exist_ok=True)

    def create_all(self) -> None:
        """Erstellt alle Tabellen gemäß den ORM-Modellen."""
        Base.metadata.create_all(self.engine)

    def session(self) -> Session:
        """Liefert eine neue Session."""
        return self._session_factory()


def get_database(settings: Settings | None = None) -> Database:
    settings = settings or load_settings()
    return Database(settings.db_url)
