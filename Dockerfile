FROM python:3.11-slim

WORKDIR /app

# Systemabhängigkeiten (PostgreSQL client für DB-Befehle, curl für health-checks)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Nur das stockintel-Projekt ins Image kopieren
COPY stockintel/ .

# Explizit config/settings.yaml kopieren, damit watchlist geladen wird
COPY stockintel/config/settings.yaml config/settings.yaml

# Paket mit PRODUCTION-Dependencies installieren (PostgreSQL, FastAPI, Collectors, Scheduler).
# Der [prod] Extra beinhaltet: psycopg2, fastapi, uvicorn, apscheduler, collectors
RUN pip install --no-cache-dir -e ".[prod]"

EXPOSE 8000

# Copy entrypoint script
COPY stockintel/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Entrypoint: waits for DB, initializes schema, starts API (für Railway deployment)
ENTRYPOINT ["/app/entrypoint.sh"]
