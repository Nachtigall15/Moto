#!/bin/bash
# Startup entrypoint: waits for database, initializes schema, starts API

set -e

echo "[ENTRYPOINT] Starting StockIntel..."
echo "[ENTRYPOINT] DATABASE_URL=${DATABASE_URL:-not set}"

# Wait for database to be available (with retry logic for Railway)
echo "[ENTRYPOINT] Waiting for database to be available..."
max_attempts=60
attempt=0

while [ $attempt -lt $max_attempts ]; do
    attempt=$((attempt + 1))
    if python -c "
from stockintel.config import load_settings
from stockintel.db.database import get_database
try:
    db = get_database()
    db.engine.connect().close()
    print('OK')
except Exception as e:
    exit(1)
" 2>&1 | grep -q OK; then
        echo "[ENTRYPOINT] Database is ready!"
        break
    fi

    if [ $attempt -eq 1 ] || [ $((attempt % 10)) -eq 0 ]; then
        echo "[ENTRYPOINT] Attempt $attempt/$max_attempts: Database not ready yet, retrying in 2 seconds..."
    fi
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    echo "[ENTRYPOINT] ERROR: Database was not ready after $max_attempts attempts"
    exit 1
fi

# Initialize database schema (idempotent - safe to run multiple times)
echo "[ENTRYPOINT] Initializing database schema..."
python -m stockintel.cli init-db 2>&1

# Start the API server
echo "[ENTRYPOINT] Starting API server..."
exec python -m stockintel.api
