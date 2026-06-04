FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    && rm -rf /var/lib/apt/lists/*

# Copy the stockintel directory
COPY stockintel/ .

# Install the package
RUN pip install --no-cache-dir -e .

# Expose port
EXPOSE 8000

# Initialize database and start server
CMD sh -c "stockintel init-db && stockintel api"
