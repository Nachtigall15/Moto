#!/bin/bash
# StockIntel starten – einfach doppelklicken.
# (Beim ersten Mal rechtsklick -> "Öffnen", wegen macOS-Sicherheit.)

cd "$(dirname "$0")" || exit 1

echo "============================================"
echo "   StockIntel Dashboard wird gestartet"
echo "============================================"
echo ""

# 1) Läuft Docker?
if ! docker info >/dev/null 2>&1; then
  echo "❌ Docker Desktop läuft noch nicht."
  echo "   Bitte starte zuerst die App 'Docker Desktop',"
  echo "   warte bis das Docker-Symbol oben ruhig ist,"
  echo "   und doppelklicke dann erneut auf 'start.command'."
  echo ""
  read -r -p "Drücke die Eingabetaste zum Schließen..."
  exit 1
fi

# 2) Container bauen & starten
echo "⏳ Baue und starte das Dashboard..."
echo "   (Das ALLERERSTE Mal dauert es ein paar Minuten – danach geht es schnell.)"
echo ""
docker compose up -d --build || {
  echo "❌ Start fehlgeschlagen. Bitte den obigen Text kopieren und mir schicken."
  read -r -p "Drücke die Eingabetaste zum Schließen..."
  exit 1
}

# 3) Auf den Server warten
echo ""
echo "⏳ Warte, bis der Server bereit ist..."
for _ in $(seq 1 90); do
  if curl -s http://localhost:8000/health >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

# 4) Beim ersten Start: Daten im Hintergrund laden, damit das Dashboard
#    nicht leer ist (läuft im Container, blockiert nichts).
docker compose exec -d stockintel sh -c \
  "stockintel collect && stockintel link && stockintel analyze" >/dev/null 2>&1

# 5) Browser öffnen
open http://localhost:8000

echo ""
echo "✅ Fertig! Das Dashboard ist offen im Browser:"
echo "      http://localhost:8000"
echo ""

# iPad-Adresse (gleiches WLAN) anzeigen
IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)
if [ -n "$IP" ]; then
  echo "📱 Auf dem iPad (im gleichen WLAN) im Safari öffnen:"
  echo "      http://$IP:8000"
  echo ""
fi

echo "ℹ️  Die Daten werden gerade im Hintergrund geladen."
echo "    Lade die Seite in 1–2 Minuten einmal neu, dann ist sie gefüllt."
echo ""
echo "    Zum Stoppen: 'stop.command' doppelklicken."
echo "    Daten aktualisieren: 'update-data.command' doppelklicken."
echo ""
read -r -p "Dieses Fenster kannst du jetzt schließen (Eingabetaste)..."
