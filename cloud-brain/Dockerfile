# =============================================================================
# Zuralog Cloud Brain — Production Dockerfile
# =============================================================================
# Multi-stage build: uv install -> slim runtime.
# Compatible with Railway PaaS (respects $PORT env var).
# =============================================================================

# --- Stage 1: Build dependencies ---
FROM python:3.12-slim AS builder

# Install uv for fast dependency resolution
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

WORKDIR /app

# Copy dependency files first for layer caching
COPY pyproject.toml uv.lock ./

# Install ONLY dependencies (not the project itself) into a virtual environment.
# --no-install-project is required because app source isn't copied yet at this
# stage — this is the standard Docker layer-caching pattern for uv.
RUN uv sync --frozen --no-dev --no-install-project

# --- Stage 2: Runtime ---
FROM python:3.12-slim AS runtime

WORKDIR /app

# Copy the virtual environment from builder
COPY --from=builder /app/.venv /app/.venv

# Copy application code and migration files
COPY app/ app/
COPY alembic/ alembic/
COPY alembic.ini .

# Use the virtual environment's Python and binaries
ENV PATH="/app/.venv/bin:$PATH"
ENV VIRTUAL_ENV="/app/.venv"

# Railway injects PORT at runtime; default to 8000 for local Docker usage.
ENV PORT=8000
EXPOSE 8000

# Use shell form so ${PORT} is expanded by the shell at container start.
CMD uvicorn app.main:app --host 0.0.0.0 --port ${PORT}
