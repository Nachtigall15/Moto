FROM python:3.11-slim

WORKDIR /app

# Systemabhängigkeiten (git wird von manchen pip-Paketen erwartet)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl \
    && rm -rf /var/lib/apt/lists/*

# Nur das stockintel-Projekt ins Image kopieren
COPY stockintel/ .

# Paket inkl. API-Server (FastAPI/uvicorn) UND Collectors installieren.
# WICHTIG: Ohne die Extras [api,collectors] fehlen FastAPI/uvicorn und die
# Datenquellen – dann startet der Server nicht.
RUN pip install --no-cache-dir -e ".[api,collectors]"

EXPOSE 8000

# Datenbank anlegen, dann den Web-Server starten (bindet an 0.0.0.0:8000).
CMD ["sh", "-c", "stockintel init-db && python -m stockintel.api"]
