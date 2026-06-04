FROM python:3.11-slim

WORKDIR /app

# Systemabhängigkeiten (PostgreSQL client für DB-Befehle, curl für health-checks)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Nur das stockintel-Projekt ins Image kopieren
COPY stockintel/ .

# Paket mit PRODUCTION-Dependencies installieren (PostgreSQL, FastAPI, Collectors, Scheduler).
# Der [prod] Extra beinhaltet: psycopg2, fastapi, uvicorn, apscheduler, collectors
RUN pip install --no-cache-dir -e ".[prod]"

EXPOSE 8000

# Datenbank initialisieren und Web-Server starten (bindet an 0.0.0.0:8000 für Railway).
CMD ["sh", "-c", "stockintel init-db && python -m stockintel.api"]
