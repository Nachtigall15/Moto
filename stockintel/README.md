# StockIntel

Markt-Intelligence-Engine — eigenständiges Python-Projekt im Verzeichnis
`stockintel/`. **Unabhängig von der Motorrad-App** im selben Repository.

> Kein Anlageberatungs-Tool. Persönliches Recherche-/Informationswerkzeug.

Konzept, Architektur und Roadmap: siehe [`PROJECT.md`](./PROJECT.md).

## Schnellstart

```bash
cd stockintel
python -m venv .venv && source .venv/bin/activate
pip install -e .[dev]

cp .env.example .env                       # API-Keys eintragen
cp config/settings.example.yaml config/settings.yaml

stockintel init-db                         # Datenbank-Schema anlegen
stockintel info                            # Status anzeigen
```

## Projektstand

**Phase 0 — Gerüst.** Verzeichnisstruktur, Konfiguration, vollständiges
Datenbankschema (inkl. Event-Study) und Modul-Skelette stehen. Die
Daten-Collectors und KI-Analyse folgen in Phase 1/2 (siehe Roadmap).

## Struktur

```
stockintel/
├── PROJECT.md              Konzept, Architektur, Roadmap
├── pyproject.toml          Paket- und Abhängigkeitsdefinition
├── config/                 Konfiguration (settings.yaml)
├── src/stockintel/
│   ├── config.py           Einstellungen laden
│   ├── cli.py              Kommandozeile (init-db, info)
│   ├── db/                 Datenbank: models.py, database.py
│   ├── collectors/         Quellen-Adapter (Phase 1)
│   ├── analysis/           KI-Bewertung (Phase 2)
│   ├── linking/            Hype->Profiteure, IPO->Investoren (Phase 3)
│   ├── eventstudy/         Historische Kursreaktionen / Hickups (Phase 4)
│   ├── scoring/            Buy/Hold/Sell (Phase 4)
│   └── delivery/           Reports & Alerts (Phase 5)
└── tests/
```
