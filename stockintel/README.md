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

### Hype-Erkennung & Profiteure (Phase 3)

Nach `collect` und `analyze` können Hypes erkannt und Beneficiaries verlinkt werden:

```bash
stockintel link-themes          # Themes (AI, EV, Cloud, etc.) erkennen
stockintel themes --limit 30    # Themes und betroffene Companies anzeigen
stockintel themes --theme "AI Infrastructure"  # nur ein Theme
```

**Themes** sind regelbasiert erkannt (Keyword-Matching: "AI", "electric vehicle", etc.)
und ihre **Beneficiaries** werden nach Sektor gefiltert (z.B. "AI Infrastructure"
→ alle Semiconductors-Unternehmen). Die Matches werden in der `theme_beneficiaries`
Tabelle gespeichert mit Strength (0.0–1.0, default 0.7) und Rationale.

Eigene Themes hinzufügen: `src/stockintel/analysis/themes.py` → `THEME_PATTERNS`
liste erweitern mit Keywords, betroffene Sektoren, Beschreibung.

### Event-Study, Hickups & Forward-Tracking (Phase 4)

Aus bewerteten Signals werden **Events** verdichtet, deren Kursreaktion über
feste Horizonte (`1h … 1m`) gemessen wird — historisch via **yfinance** und live
per Forward-Tracking. Daraus entstehen abnormale Renditen (gegen den Benchmark),
**Hickup**-Erkennung (Strohfeuer: Spike + Rückkehr) und **Basisraten je
Ereignistyp**.

```bash
pip install -e .[collectors]          # yfinance (einmalig, für Kursdaten)

stockintel event-study                # Signals -> Events -> Snapshots -> Outcomes
stockintel events --ticker NVDA       # Events + Final/Abnormal-Return + Hickup
stockintel track                      # fällige Horizonte live erfassen (Forward)
stockintel reaction-profiles          # Ø Reaktion + Hickup-Quote je Ereignistyp
```

Ohne Marktdaten (kein Netz/yfinance) entstehen weiterhin Events, nur keine
Snapshots/Outcomes — die Engine bleibt lauffähig. Horizonte, Benchmark und die
Hickup-Schwelle (`hickup_reversal_ratio`) stehen unter `event_study` in
`settings.yaml`.

### IPO → Investoren (13F, Phase 3b)

`stockintel find-ipo` scannt EDGAR-S-1-Filings für IPO-Events **und** gleicht die
Positionen verfolgter institutioneller Manager (13F-HR) gegen sie ab. Die Manager
werden unter `ipo.managers` (CIK + Name) in `settings.yaml` gepflegt; Treffer
erscheinen in `stockintel ipos`.

### REST-API & Web-Dashboard (Phase 5 + 6)

Die Engine bringt eine FastAPI-Schnittstelle und ein Browser-Dashboard mit:

```bash
pip install -e .[api]      # fastapi, uvicorn, apscheduler (einmalig)
./run_api.sh               # Server auf http://0.0.0.0:8000
```

Dann im Browser **http://localhost:8000/** öffnen — das Dashboard zeigt Stats,
Recommendations, Top-Signals (filterbar) und Companies, alles live aus der DB.

**API-Endpoints** (auch direkt nutzbar, z.B. für eigene Frontends):

| Methode | Pfad | Zweck |
|---|---|---|
| GET | `/health` | Health-Check |
| GET | `/stats` | Zähler: Items, Signals, Companies, Recommendations |
| GET | `/companies?limit=` | Companies + Signal-Anzahl |
| GET | `/signals?ticker=&analyzed_only=` | Signals (filterbar) |
| GET | `/recommendations` | Buy/Hold/Sell-Empfehlungen |
| POST | `/analyze?limit=` | KI-Triage anstoßen |
| POST | `/score` | Recommendations neu berechnen |

Die interaktive API-Doku (Swagger) liegt unter **`/docs`**. Ein Background-Scheduler
(APScheduler) führt `analyze` (09:00) und `score` (10:00) täglich aus.

**Alerts** (`src/stockintel/alerts.py`): Log-basiert standardmäßig aktiv; Slack
(`STOCKINTEL_SLACK_WEBHOOK`) und Email (`STOCKINTEL_EMAIL_FROM`/`_TO`) per
Environment-Variable zuschaltbar.

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

**Phase 6 — Web-Dashboard.** Ein leichtgewichtiges Browser-Dashboard (`web/`,
Vanilla-JS, ohne Build-Step) zeigt Stats, Recommendations, filterbare Top-Signals
und Companies — ausgeliefert direkt von FastAPI unter `/`. Siehe Abschnitt oben.

**Phase 5 — REST-API + Alerts.** FastAPI-Server (`api.py`) mit Endpoints für
Stats, Companies, Signals, Recommendations sowie Trigger für `analyze`/`score`.
Background-Scheduler (APScheduler) für tägliche Läufe. Alert-System (`alerts.py`)
mit Log/Slack/Email-Handlern.

**Phase 4 — Event-Study + Scoring.** `analysis/eventstudy.py` verdichtet Signals
zu Events, lädt Kursreaktionen (historisch via **yfinance**, live per
**Forward-Tracking**), rechnet abnormale Renditen gegen den Benchmark, erkennt
Hickups (Spike + Rückkehr) und aggregiert **Basisraten je Ereignistyp**
(`ReactionProfile`). CLI: `event-study`, `events`, `track`, `reaction-profiles`.
`analysis/scoring.py` aggregiert Signals zu **Buy/Hold/Sell**-Empfehlungen
(`stockintel score` / `recommendations`).

**Phase 3 — Linking.** `analysis/themes.py` erkennt Hypes (AI, EV, Cloud, …) und
verknüpft Profiteure nach Sektor. `analysis/ipo.py` scannt EDGAR-S-1-Filings für
IPO-Events und verknüpft institutionelle Halter aus **13F-Filings**
(`analysis/thirteenf.py`). CLI: `link-themes`, `themes`, `find-ipo`, `ipos`.

**Phase 2 — Entity-Resolution + KI-Triage.** Eine **regelbasierte** Verknüpfung
(`analysis/entity.py`) ordnet jeden neuen `RawItem` per Ticker-/Namens-Match
einem Unternehmen aus der Watchlist zu und legt ein `Signal` (mit neutralen
Platzhaltern) an — läuft automatisch nach jedem `collect`. Die **KI-Triage**
(`analysis/triage.py`) bewertet diese Signals anschließend mit einem günstigen
Claude-Modell (strukturiert via Tool-Use, mit Prompt-Caching): Relevanz,
Richtung, Kurswirkung, Horizont, Konfidenz, Begründung. Anzeige über
`stockintel signals`.

**Phase 1 — Daten-Collectors.** Aktiv: **EDGAR**, **RSS**, **StockTwits**,
**YouTube** (Channel-RSS + Transkripte, alle schlüssellos), **Finnhub**
(Unternehmens-News, Free-Tier-Key) sowie **Reddit** (braucht API-Credentials).
Eingesammelte Informationen werden dedupliziert als `RawItem` gespeichert.
`collect` kann per `--loop` wiederkehrend sammeln.

Frühere Stände:
- **Phase 0 — Gerüst.** Verzeichnisstruktur, Konfiguration, vollständiges
  Datenbankschema (inkl. Event-Study) und Modul-Skelette.

## Struktur

```
stockintel/
├── PROJECT.md              Konzept, Architektur, Roadmap
├── pyproject.toml          Paket- und Abhängigkeitsdefinition
├── run_api.sh              API-Server starten (Phase 5/6)
├── config/                 Konfiguration (settings.yaml)
├── src/stockintel/
│   ├── config.py           Einstellungen laden
│   ├── cli.py              Kommandozeile (collect, analyze, score, …)
│   ├── api.py              FastAPI REST-Server (Phase 5)
│   ├── alerts.py           Alert-Handler: Log/Slack/Email (Phase 5)
│   ├── web/                Web-Dashboard: HTML/CSS/JS (Phase 6)
│   ├── db/                 Datenbank: models.py, database.py
│   ├── collectors/         Quellen-Adapter inkl. YouTube (Phase 1)
│   ├── analysis/           Entity, Triage, Themes, IPO/13F, Eventstudy, Prices, Scoring
│   ├── linking/            Hype->Profiteure, IPO->Investoren (Phase 3)
│   ├── eventstudy/         Historische Kursreaktionen / Hickups (Phase 4)
│   ├── scoring/            Buy/Hold/Sell (Phase 4)
│   └── delivery/           Reports & Alerts (Phase 5)
└── tests/
```
