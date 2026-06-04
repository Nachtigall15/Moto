#!/usr/bin/env bash
# StockIntel API Server starten
# Aufruf: cd stockintel && ./run_api.sh [--host 0.0.0.0] [--port 8000]

set -euo pipefail

cd "$(dirname "$0")"

PYTHON="${PYTHON:-python3}"
HOST="${1:---host=0.0.0.0}"
PORT="${2:---port=8000}"

# Virtual environment aktivieren (falls nicht schon)
if [ -d ".venv" ]; then
  . .venv/bin/activate
fi

echo "==> Starte StockIntel API Server"
echo "    Host: ${HOST#--host=}"
echo "    Port: ${PORT#--port=}"

$PYTHON -m uvicorn stockintel.api:create_app "$HOST" "$PORT" --reload --log-level info
