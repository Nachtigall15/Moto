#!/bin/bash
# Neue Daten holen & analysieren – einfach doppelklicken.
# (Das Dashboard muss dafür laufen, also vorher 'start.command'.)

cd "$(dirname "$0")" || exit 1

if ! curl -s http://localhost:8000/health >/dev/null 2>&1; then
  echo "❌ Das Dashboard läuft gerade nicht."
  echo "   Bitte zuerst 'start.command' doppelklicken und kurz warten."
  read -r -p "Drücke die Eingabetaste zum Schließen..."
  exit 1
fi

echo "⏳ Hole frische Daten (Nachrichten, Filings, ...) und analysiere sie..."
echo "   Das kann ein, zwei Minuten dauern."
echo ""
docker compose exec stockintel sh -c \
  "stockintel collect && stockintel link && stockintel analyze && stockintel score"

echo ""
echo "✅ Fertig! Lade das Dashboard im Browser neu (Cmd+R)."
echo ""
read -r -p "Dieses Fenster kannst du jetzt schließen (Eingabetaste)..."
