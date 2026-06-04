#!/bin/bash
# StockIntel stoppen – einfach doppelklicken.

cd "$(dirname "$0")" || exit 1

echo "⏹  Stoppe das StockIntel Dashboard..."
docker compose down
echo ""
echo "✅ Gestoppt. Deine Daten bleiben erhalten."
echo "   Zum erneuten Starten: 'start.command' doppelklicken."
echo ""
read -r -p "Dieses Fenster kannst du jetzt schließen (Eingabetaste)..."
