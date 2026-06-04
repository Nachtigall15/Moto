# StockIntel — Markt-Intelligence-Engine

> **Eigenständiges Projekt.** Hat **nichts** mit der Motorrad-App im selben Repo zu tun
> und ist bewusst in diesem separaten Verzeichnis `stockintel/` gekapselt.
>
> **Kein Anlageberatungs-Tool.** Persönliches Recherche- und Informationswerkzeug.
> Alle Ausgaben sind informativ, keine Empfehlung im rechtlichen Sinne.

## Idee in einem Satz

Eine Engine, die laufend Finanz-Quellen einsammelt, mit KI bewertet
(Relevanz, Richtung, Kurswirkung, Horizont, Konfidenz), Zusammenhänge
herstellt (Hype → Profiteure, IPO → Investoren) und daraus pro Aktie eine
nachvollziehbare **Buy / Hold / Sell**-Einschätzung mit Quellen erzeugt —
inklusive **historischer Reaktionsvergleiche** ("Event-Study"), um
kurzfristige Strohfeuer ("Hickups") von nachhaltigen Bewegungen zu trennen.

## Architektur — Pipeline

```
1. COLLECTORS    Pro Quelle ein Adapter (RSS, Finnhub, FMP, EDGAR,
                 YouTube, Reddit, StockTwits) -> einheitliches RawItem
2. ENTITY-RESOLVE Text -> Aktie/Ticker ("Marvell" -> MRVL), Sektor, Aliase
3. ANALYSE (KI)  Triage (guenstiges Modell) -> Tiefenanalyse (starkes Modell):
                 Relevanz, Richtung, Kurswirkung, Horizont, Begruendung
4. LINKING       Hype->Profiteure-Graph (KI-Boom -> Chips/Strom/Rechenzentren)
                 IPO->Investoren (EDGAR 13F + S-1-Prospekte)
5. EVENT-STUDY   Historische Kursreaktion je Ereignis + Basisraten je Typ
                 (Hickup-Erkennung: Spike + Rueckkehr)
6. SCORING       Signale je Aktie buendeln -> Buy/Hold/Sell + Konfidenz
7. API (FastAPI) Eine Schnittstelle fuer Web, App und Reports
8. DELIVERY      Taeglicher Report + Event-Alerts
9. FRONTENDS     Web-Dashboard, spaeter Flutter-App (eigenes Projekt)
```

## Datenquellen (Stack "Empfohlen", ohne X/Twitter)

| Zweck | Quelle | Kosten |
|---|---|---|
| Pflichtmeldungen / IPOs / 13F | SEC EDGAR | gratis |
| News + Sentiment | Finnhub | Free-Tier |
| Fundamentaldaten / Historie | FMP / yfinance | gratis/Free |
| Schnelle (laute) Social-Signale | Reddit, StockTwits | gratis |
| CEO-/Analysten-Aussagen | YouTube-Transkripte | gratis |
| High-Profile-Posts (Musk/Trump) | Google-News-RSS + Finnhub-Pickup | gratis |

> Quellen sind **Plug-in-Adapter** — neue Quellen lassen sich ohne Eingriff in
> den Kern ergaenzen.

## Bewertungs-Logik

Jede Information erhaelt:

- **Relevanz** 0–100
- **Richtung** positiv / neutral / negativ
- **Kurswirkung** = Staerke (gering/mittel/hoch) × **Horizont** (Tage/Wochen/Monate)
- **Konfidenz** (Quellenguete + Mehrfachbestaetigung + historische Basisrate)

→ aggregiert pro Aktie → **Buy / Hold / Sell** mit Begruendung und Quell-Links.

## Event-Study / Hickup-Modul (historische Vergleiche)

Jedes erkannte Ereignis bekommt `t0`. Kurs wird an festen Horizonten gemessen:

```
Baseline(t0-) | t0 | +1h | +4h | +1d | +3d | +1w | +1m
```

- **Forward-Tracking:** Live erkanntes Event -> Scheduler plant Snapshots ->
  praezise Echtzeit-Messung der Reaktion. (immer, gratis)
- **Historische Basisraten:** Backfill von Tages-Kurshistorie fuer vergangene
  Events -> Statistik je Ereignistyp. (gratis via yfinance; Stunden-Genauigkeit
  historisch nur ~60 Tage zurueck)
- **Abnormal Return:** Reaktion gegen Index/Sektor-ETF gerechnet -> filtert
  allgemeine Marktbewegung heraus.
- **Hickup-Erkennung:** Spike + Rueckkehr ("+6% in 1h, nach 2 Tagen wieder -4%")
  -> als Strohfeuer markiert.
- **Reaktionsprofil je Ereignistyp** (CEO-Kommentar, Earnings-Beat, FDA,
  Musk-Post, IPO …) -> dient als Basisrate fuer neue, aehnliche Events und
  fliesst in Konfidenz + Buy/Hold/Sell ein.

## Datenmodell (Kern)

- `Source` – Quelle/Adapter
- `RawItem` – eingesammelte Rohinformation
- `Company` – Aktie (Ticker, Name, Sektor, Aliase)
- `Signal` – RawItem -> Company mit Bewertung
- `Theme` / `ThemeBeneficiary` – Hype -> Profiteure
- `IpoEvent` / `IpoInvestor` – IPO -> Investoren
- `Event` – erkanntes kursrelevantes Ereignis (Typ, t0)
- `EventSnapshot` – Kurs zum Offset (+1h, +1d, …)
- `EventOutcome` – berechnete (abnormale) Rendite + Hickup-Klassifikation
- `ReactionProfile` – aggregierte Basisrate je Ereignistyp
- `Recommendation` – Buy/Hold/Sell + Konfidenz + Begruendung + Quellen

## Roadmap

- **Phase 0** – Geruest: Verzeichnis, Python-Setup, DB-Schema, Config *(dieser Stand)*
- **Phase 1** – Collectors (EDGAR + RSS + Finnhub + YouTube + Reddit) -> DB
- **Phase 2** – Entity-Resolution + KI-Bewertung -> erste echte Signale
- **Phase 3** – Linking: Hype->Profiteure & IPO->Investoren
- **Phase 4** – Event-Study + Scoring -> Buy/Hold/Sell + erster Tagesreport
- **Phase 5** – FastAPI + Alerts
- **Phase 6** – Web-Dashboard, danach Flutter-App

## Tech-Stack

- **Python 3.11+**, SQLAlchemy 2.0, SQLite (spaeter optional Postgres)
- Anthropic SDK (Triage: guenstiges Modell, Tiefenanalyse: starkes Modell)
- `feedparser`, `praw` (Reddit), `youtube-transcript-api`, `yfinance`, `httpx`
- FastAPI (ab Phase 5), APScheduler (Scheduling)
