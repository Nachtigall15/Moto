#!/bin/bash
# Startup: wartet auf die Datenbank, legt das Schema an, startet die API.
set -e

echo "[ENTRYPOINT] Waiting for database..."
for attempt in $(seq 1 60); do
    if python -c "
from stockintel.db.database import get_database
get_database().engine.connect().close()
" 2>/dev/null; then
        echo "[ENTRYPOINT] Database is ready."
        break
    fi
    if [ "$attempt" -eq 60 ]; then
        echo "[ENTRYPOINT] ERROR: database not reachable after 60 attempts."
        exit 1
    fi
    sleep 2
done

echo "[ENTRYPOINT] Initializing database schema..."
python -m stockintel.cli init-db

echo "[ENTRYPOINT] Starting API server..."
exec python -m stockintel.api
