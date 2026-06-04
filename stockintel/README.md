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
stockintel collect                  # aktive Quellen abrufen + automatisch verknüpfen
stockintel items --limit 20         # zuletzt gespeicherte Items anzeigen
stockintel items --ticker NVDA      # nur Items, die NVDA betreffen
stockintel items --source edgar     # nur Items aus einer Quelle
stockintel companies                # Companies + Signal-Anzahl je Aktie
stockintel analyze --limit 20       # offene Signals mit KI bewerten (braucht Key)
stockintel signals --ticker NVDA    # Bewertungen ansehen
```

### Was passiert beim `collect`?

1. Alle aktivierten Collectors holen neue Items und speichern sie als `RawItem`.
2. Die Watchlist aus `settings.yaml` wird in die `companies`-Tabelle gespiegelt.
3. **Entity-Resolution** (regelbasiert): Jedes neue Item wird auf Ticker und
   Firmennamen durchsucht; pro Treffer entsteht ein `Signal` (RawItem ⇄ Company).
   So funktionieren Filter wie `items --ticker NVDA` sofort.

Die regelbasiert erzeugten Signale tragen neutrale Platzhalter und
`model="rule-based-v1"`. Manuelles Re-Linking ohne neuen Sammellauf:
`stockintel link`.

### KI-Bewertung (Triage)

`stockintel analyze` bewertet die offenen Signals mit einem günstigen
**Triage-Modell** (Claude Haiku, aus `models.triage` in `settings.yaml`). Je
Signal liefert das Modell per Tool-Use strukturiert: **Relevanz** (0–100),
**Richtung** (positive/neutral/negative), **Kurswirkung** (low/medium/high),
**Horizont** (days/weeks/months), **Konfidenz** (0–1) und eine kurze Begründung.

```bash
# in stockintel/.env
ANTHROPIC_API_KEY=sk-ant-...

stockintel analyze --limit 50     # bis zu 50 offene Signals bewerten
stockintel signals --analyzed     # nur KI-bewertete Signals anzeigen
```

Ohne `ANTHROPIC_API_KEY` bricht `analyze` mit einem klaren Hinweis ab (kein
Crash). Jeder Lauf verarbeitet bis zu `--limit` noch offene Signals; bereits
bewertete (`model` = Triage-Modell) werden übersprungen. Das nötige Anthropic-SDK
installiert `setup.sh` mit (Extra `analysis`).

> Kein Anlageberatungs-Tool. Die Bewertungen sind informativ.

### Laufend sammeln (Schleifen-Modus)

Für wiederkehrende Läufe sammelt `collect` auf Wunsch in einer Schleife — ideal,
um über die Zeit Daten anzuhäufen:

```bash
stockintel collect --loop                       # alle 600s, bis Strg-C
stockintel collect --loop --interval 300        # alle 5 Minuten
stockintel collect --loop --interval 300 --count 12   # 12 Läufe, dann Stopp
```

> **Hinweis:** In einer kurzlebigen Web-Session läuft die Schleife nur, solange
> die Session aktiv ist; die lokale SQLite-DB ist nicht eingecheckt. Für dauerhaft
> automatisierte Läufe eignet sich ein Cron-Job/Scheduler auf einer persistenten
> Maschine (oder später APScheduler, siehe Roadmap).

### Finnhub aktivieren

Finnhub (Unternehmens-News, Free-Tier) ist standardmäßig in `settings.yaml`
aktiv, braucht aber einen Key:

```bash
# in stockintel/.env
FINNHUB_API_KEY=dein_key_von_finnhub.io
```

Ohne Key überspringt `collect` nur Finnhub (mit Hinweis) und sammelt die übrigen
Quellen normal weiter.

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

**Phase 2 — Entity-Resolution + KI-Triage.** Eine **regelbasierte** Verknüpfung
(`analysis/entity.py`) ordnet jeden neuen `RawItem` per Ticker-/Namens-Match
einem Unternehmen aus der Watchlist zu und legt ein `Signal` (mit neutralen
Platzhaltern) an — läuft automatisch nach jedem `collect`. Die **KI-Triage**
(`analysis/triage.py`) bewertet diese Signals anschließend mit einem günstigen
Claude-Modell (strukturiert via Tool-Use, mit Prompt-Caching): Relevanz,
Richtung, Kurswirkung, Horizont, Konfidenz, Begründung. Anzeige über
`stockintel signals`. Tiefenanalyse mit einem stärkeren Modell folgt.

**Phase 1 — Daten-Collectors.** Aktiv: **EDGAR**, **RSS**, **StockTwits**
(alle schlüssellos), **Finnhub** (Unternehmens-News, Free-Tier-Key) sowie
**Reddit** (braucht API-Credentials). Eingesammelte Informationen werden
dedupliziert als `RawItem` gespeichert. `collect` kann per `--loop` wiederkehrend
sammeln. YouTube folgt (siehe Roadmap).

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
│   ├── analysis/           Entity-Resolution + KI-Bewertung (Phase 2)
│   ├── linking/            Hype->Profiteure, IPO->Investoren (Phase 3)
│   ├── eventstudy/         Historische Kursreaktionen / Hickups (Phase 4)
│   ├── scoring/            Buy/Hold/Sell (Phase 4)
│   └── delivery/           Reports & Alerts (Phase 5)
└── tests/
```
