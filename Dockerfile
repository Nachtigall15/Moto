FROM python:3.11-slim

WORKDIR /app

# Systemabhängigkeiten (PostgreSQL client für DB-Befehle, curl für health-checks)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Das stockintel-Projekt ins Image kopieren (inkl. config/settings.yaml).
COPY stockintel/ .

# Paket mit PRODUCTION-Dependencies installieren (PostgreSQL, FastAPI, Collectors, Scheduler).
# Der [prod] Extra beinhaltet: psycopg2, fastapi, uvicorn, apscheduler, collectors
RUN pip install --no-cache-dir -e ".[prod]"

EXPOSE 8000

# Entrypoint: wartet auf die DB, legt das Schema an, startet dann die API.
RUN chmod +x /app/entrypoint.sh
ENTRYPOINT ["/app/entrypoint.sh"]
