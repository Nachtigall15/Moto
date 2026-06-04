#!/usr/bin/env bash
#
# StockIntel — einmaliges Setup für einen frischen Container/Session.
# Idempotent: vorhandene Dateien (config/.env/venv) werden nicht überschrieben.
#
# Aufruf:
#   cd stockintel && ./setup.sh
#
# Optional: SEC-Kontakt-User-Agent vorgeben (sonst Platzhalter aus settings.yaml):
#   STOCKINTEL_SEC_UA="StockIntel research dein@email.de" ./setup.sh

set -euo pipefail

# Ins Verzeichnis dieses Skripts wechseln (= stockintel/), egal von wo aufgerufen.
cd "$(dirname "$0")"

PYTHON="${PYTHON:-python3}"

echo "==> StockIntel Setup"
echo "    Arbeitsverzeichnis: $(pwd)"

# 1) Virtuelle Umgebung
if [ ! -d ".venv" ]; then
  echo "==> Erstelle virtuelle Umgebung (.venv)"
  "$PYTHON" -m venv .venv
else
  echo "==> .venv existiert bereits"
fi
# shellcheck disable=SC1091
. .venv/bin/activate

# 2) Abhängigkeiten (Collectors + KI-Analyse)
echo "==> Installiere Paket + Collector- und Analyse-Abhängigkeiten"
pip install --quiet --upgrade pip
pip install --quiet -e ".[collectors,analysis]"

# 3) Konfiguration (nur anlegen, nie überschreiben)
if [ ! -f "config/settings.yaml" ]; then
  echo "==> Lege config/settings.yaml aus Vorlage an"
  cp config/settings.example.yaml config/settings.yaml
else
  echo "==> config/settings.yaml existiert bereits (unverändert)"
fi

if [ ! -f ".env" ]; then
  echo "==> Lege .env aus Vorlage an"
  cp .env.example .env
else
  echo "==> .env existiert bereits (unverändert)"
fi

# 4) Datenbank-Schema anlegen
echo "==> Initialisiere Datenbank"
stockintel init-db

# 5) Netzwerk-Check (nicht fatal) — zeigt, ob die Hosts erreichbar sind
echo "==> Prüfe Netzwerkzugriff auf externe Quellen"
"$PYTHON" - <<'PY' || true
import httpx
hosts = {
    "StockTwits": "https://api.stocktwits.com/api/2/streams/symbol/NVDA.json",
    "SEC EDGAR":  "https://www.sec.gov/files/company_tickers.json",
}
ok = True
for name, url in hosts.items():
    try:
        code = httpx.get(url, headers={"User-Agent": "stockintel-setup ftrapp@gmx.net"}, timeout=15).status_code
        mark = "OK" if code == 200 else f"BLOCKIERT (HTTP {code})"
        if code != 200:
            ok = False
        print(f"    - {name:10}: {mark}")
    except Exception as exc:  # noqa: BLE001
        ok = False
        print(f"    - {name:10}: FEHLER ({type(exc).__name__})")
if not ok:
    print("    Hinweis: Hosts nicht erreichbar -> Environment mit Full Network Access verwenden.")
PY

echo ""
echo "==> Fertig. Nächste Schritte:"
echo "    1) In config/settings.yaml den EDGAR 'user_agent' auf deinen Namen/Mail setzen"
echo "       (oder STOCKINTEL_SEC_UA in .env). Für Reddit ggf. Credentials in .env."
echo "    2) Aktiviere die Umgebung:  . .venv/bin/activate"
echo "    3) Daten sammeln:           stockintel collect"
echo "    4) Ergebnis ansehen:        stockintel items --limit 20"
