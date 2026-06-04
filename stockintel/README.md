# StockIntel

Markt-Intelligence-Engine — eigenständiges Python-Projekt im Verzeichnis
`stockintel/`. **Unabhängig von der Motorrad-App** im selben Repository.

> Kein Anlageberatungs-Tool. Persönliches Recherche-/Informationswerkzeug.

Konzept, Architektur und Roadmap: siehe [`PROJECT.md`](./PROJECT.md).

## Schnellstart

In einem frischen Container/Session genügt ein Befehl:

```bash
cd stockintel
./setup.sh          # venv + Abhängigkeiten + config/.env + DB + Netzwerk-Check
```

Danach EDGAR-`user_agent` in `config/settings.yaml` setzen, dann:

```bash
. .venv/bin/activate
stockintel collect              # aktive Quellen abrufen (EDGAR, RSS, StockTwits)
stockintel items --limit 20     # zuletzt gespeicherte Items anzeigen
```

<details>
<summary>Manuelles Setup (statt setup.sh)</summary>

```bash
cd stockintel
python -m venv .venv && source .venv/bin/activate
pip install -e .[dev,collectors]

cp .env.example .env                       # API-Keys eintragen
cp config/settings.example.yaml config/settings.yaml

stockintel init-db                         # Datenbank-Schema anlegen
stockintel info                            # Status anzeigen
stockintel collect                         # aktive Quellen abrufen
stockintel items --limit 20                # zuletzt gespeicherte Items anzeigen
```
</details>

> **Netzwerk-Hinweis:** `collect` ruft externe Hosts ab (`sec.gov`,
> `data.sec.gov`, RSS-Feeds). In einer Sandbox mit Host-Allowlist müssen diese
> Hosts freigegeben sein, sonst meldet der Collector „Host not in allowlist".
> Die SEC verlangt zudem einen Kontakt-`User-Agent` (in `settings.yaml` oder
> via `STOCKINTEL_SEC_UA`).

## Projektstand

**Phase 1 — Daten-Collectors.** Aktiv: **EDGAR**, **RSS**, **StockTwits**
(alle schlüssellos) sowie **Reddit** (braucht API-Credentials). Eingesammelte
Informationen werden dedupliziert als `RawItem` gespeichert. Finnhub, YouTube
und die KI-Bewertung folgen (siehe Roadmap).

Frühere Stände:
- **Phase 0 — Gerüst.** Verzeichnisstruktur, Konfiguration, vollständiges
  Datenbankschema (inkl. Event-Study) und Modul-Skelette.

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
