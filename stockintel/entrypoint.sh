#!/bin/bash
# Startup entrypoint: waits for database, initializes schema, starts API

set -e

# Wait for database to be available (with retry logic for Railway)
echo "Waiting for database to be available..."
for i in {1..30}; do
    if python -c "from stockintel.config import load_settings; from stockintel.db.database import get_database; db = get_database(); print('Database connection OK')" 2>/dev/null; then
        break
    fi
    echo "  Attempt $i/30: Retrying in 2 seconds..."
    sleep 2
done

# Initialize database schema (idempotent - safe to run multiple times)
echo "Initializing database schema..."
python -m stockintel.cli init-db

# Start the API server
echo "Starting API server..."
exec python -m stockintel.api
