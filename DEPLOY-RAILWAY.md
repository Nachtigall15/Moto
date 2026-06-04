# 🚀 StockIntel auf Railway.app deployen (Online-Lösung)

Diese Anleitung bringt dein Dashboard mit **automatischen Updates alle 7 Minuten** 
ins Internet auf eine **feste Web-Adresse** (funktioniert auf jedem Gerät, 24/7).

---

## Was du dafür brauchst

1. **GitHub-Konto** (kostenlos auf github.com)
2. **Railway.app-Konto** (kostenlos, kostenlosen Tier anmelden)
3. **Finnhub API-Key** (hast du schon: `d8gj8ehr01qlgcujsthgd8gj8ehr01qlgcujsti0`)

---

## Schritt 1 – Projekt zu GitHub pushen

Das System läuft bereits in deinem Branch `claude/gallant-hamilton-lr5Ud`. 
Falls nicht automatisch gesynct:

```bash
cd /pfad/zum/Moto-Ordner
git push -u origin claude/gallant-hamilton-lr5Ud
```

---

## Schritt 2 – Railway.app Konto erstellen & verbinden

1. Gehe auf **https://railway.app** → **Sign up** mit GitHub
2. Autorisiere Railroad App (es öffnet GitHub)
3. Zurück auf railway.app: **New Project** → **GitHub Repo**
   - Wähle `nachtigall15/moto`
   - Wähle Branch `claude/gallant-hamilton-lr5Ud`

---

## Schritt 3 – PostgreSQL-Datenbank hinzufügen

1. Im Railway-Projekt oben: **+ Add Service** → **Database** → **PostgreSQL**
2. Warte ~30 Sekunden, bis die DB läuft
3. Railway zeigt dir die Connection-Details automatisch

---

## Schritt 4 – Umgebungsvariablen setzen

Im Railway-Projekt → Service `stockintel` → **Variables** → diese hinzufügen:

```
STOCKINTEL_DB_URL=postgresql://...
FINNHUB_API_KEY=d8gj8ehr01qlgcujsthgd8gj8ehr01qlgcujsti0
```

**Für `STOCKINTEL_DB_URL`:**
- Railway zeigt dir die PostgreSQL-Daten unter der Database
- Format: `postgresql://username:password@host:port/dbname`
- Copy-Paste direkt rein

---

## Schritt 5 – Deploy & Online!

1. Railway deployed automatisch nach jedem Push
2. Nach ~2-3 Minuten sieht du: "Deployment Successful" ✅
3. Die URL steht oben im Project (z.B. `https://stockintel-abc123.railway.app`)

**Die Datenbank wird automatisch initialisiert** ✨
- Das System wartet beim Start, bis PostgreSQL verfügbar ist
- Erstellt dann automatisch alle notwendigen Tabellen
- Synchronisiert deine Watchlist
- Startet dann den Server

**Öffne die URL im Browser** → dein Dashboard läuft live!

---

## 📱 Überall verfügbar

- Mac: https://stockintel-abc123.railway.app
- iPad: https://stockintel-abc123.railway.app (gleiche URL, überall verfügbar!)
- Handy: https://stockintel-abc123.railway.app

Keine Port-Nummern, keine Netzwerk-Beschränkungen.

---

## 🔄 Automatische Updates alle 7 Minuten

Der Server hat einen **Scheduler integriert**:
- Alle 7 Min: neue Daten sammeln (Finnhub, RSS, etc.)
- Alle 30 Min: Signale analysieren
- Alle 60 Min: Empfehlungen updaten

Das läuft **komplett automatisch** im Hintergrund.

---

## 💰 Kosten

Mit dem kostenlosen Railway-Tier (5€ Guthaben/Monat):
- **Genug für deine Nutzung** (Server + PostgreSQL kostenlosen verbrauchen weniger)
- Falls du mehr Power brauchst: optional auf Paid upgraden

---

## ✅ Testen, dass alles funktioniert

Nachdem deploy erfolgreich war:

1. Öffne: `https://deine-url.railway.app/health`
   → Sieht du `{"status":"ok"}`? ✅
2. Öffne: `https://deine-url.railway.app`
   → Sieht du das Dashboard? ✅
3. Warte 7 Minuten, refresh → neue Daten? ✅

---

## 🔧 Wenn etwas nicht läuft

1. **"Deployment failed"** → Railway Logs anschauen (unter "Deployments")
2. **"Database connection error"** → `STOCKINTEL_DB_URL` Variable prüfen
3. **Dashboard leer** → 1-2 min warten (erster Collect lädt Daten)

Kopier den Error und schreib mir.

---

## 🔑 Secrets sicher?

- Dein Finnhub-Key ist nur auf Railway, nicht im Repo ✅
- PostgreSQL-Passwort ist nur bei Railway, nicht im Code ✅
- Alle Secrets sind geschützt

---

**Fertig! Dein StockIntel Dashboard ist jetzt online und live.**
