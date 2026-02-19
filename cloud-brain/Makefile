# =============================================================================
# Life Logger Cloud Brain — Makefile
# =============================================================================
# Common development commands.
# =============================================================================

.PHONY: dev test lint migrate docker-up docker-down

## Start the development server with hot-reload
dev:
	uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

## Run the test suite
test:
	uv run pytest tests/ -v

## Run linting and formatting checks
lint:
	uv run ruff check app/ tests/
	uv run ruff format --check app/ tests/

## Format code
format:
	uv run ruff format app/ tests/

## Run Alembic migrations
migrate:
	uv run alembic upgrade head

## Create a new migration from model changes
migration:
	uv run alembic revision --autogenerate -m "$(msg)"

## Start Docker Compose services (Postgres + Redis)
docker-up:
	docker compose up -d

## Stop Docker Compose services
docker-down:
	docker compose down
