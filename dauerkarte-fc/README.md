# Dauerkarte FC – 1. FC Köln

Autarke, lokale Progressive Web App zur Verwaltung deiner Dauerkarte für
Heimspiele des 1. FC Köln. Kein Backend, kein Login, keine Cloud – alle
Daten liegen lokal im Browser (IndexedDB) und überleben Neuladen,
App-Schließen und Neustart. Installierbar auf dem Handy (Homescreen),
offline lauffähig.

## Features

- Heimspiele werden automatisch von [OpenLigaDB](https://www.openligadb.de/)
  geladen (Saison konfigurierbar über `SEASON` in `src/api.ts`).
- Zwei Tabs: **Spieltage** (Erfassung je Spiel) und **Übersicht**
  (Kennzahlen, Auswertung, Saison-Tabelle).
- Nutzungsarten: Eigennutzung, Sitznachbar, Freundeskreis, Spieltagsbörse –
  inkl. Erstattungs- und Tauschbilanz-Logik.
- Kalender-Erinnerungen als `.ics`-Download (einzeln oder alle Heimspiele).
- JSON-Export/-Import für Backup und Gerätewechsel.
- Vollständig offline nutzbar dank Service Worker (vite-plugin-pwa).

## Setup

```bash
npm install
npm run dev      # Entwicklung, http://localhost:5173
npm run build    # Produktions-Build nach dist/
npm run preview  # Build lokal testen
```

## Auf dem Handy installieren

1. `npm run build` ausführen und `dist/` auf einem HTTPS-Host bereitstellen
   (z. B. GitHub Pages, Netlify, Vercel) – PWAs benötigen HTTPS
   (`localhost` beim Testen ist ausgenommen).
2. Seite auf dem Handy im Browser öffnen.
   - **Android (Chrome):** Menü → „Zum Startbildschirm hinzufügen".
   - **iOS (Safari):** Teilen-Button → „Zum Home-Bildschirm".
3. App-Icon erscheint auf dem Homescreen und startet im Standalone-Modus.
4. Nach dem ersten Laden funktioniert die App auch offline.

## Datenmodell

- **`matches`** (IndexedDB-Store): aus der API geladene Heimspiele, wird bei
  jedem „Aktualisieren" neu geschrieben.
- **`usage`** (IndexedDB-Store): deine Eingaben pro Spiel (Nutzungsart,
  Erstattung, Status, Sitznachbar-Flags). Wird von einem API-Refresh
  **nie** überschrieben – nur neue Spiele bekommen einen Default-Eintrag.

## Projektstruktur

```
src/
  types.ts     Typen (Match, Usage, UsageType, UsageStatus)
  db.ts        IndexedDB-Layer (idb): matches/usage/meta, Merge, Backup
  api.ts       OpenLigaDB-Abruf, Köln-Filter, Caching
  ics.ts       .ics-Kalenderexport
  format.ts    Datums-/Euro-Formatierung
  components/
    MatchCard.tsx       Einzelne Spieltag-Karte
    SpieltageTab.tsx    Tab 1
    UebersichtTab.tsx   Tab 2
    BackupControls.tsx  Export/Import
scripts/
  make-icons.mjs  Generiert Platzhalter-PWA-Icons (public/icons/)
```

## Tech-Stack

React + Vite + TypeScript, `idb` für IndexedDB, `vite-plugin-pwa` für
Manifest und Service Worker. Kein UI-Framework, plain CSS.
