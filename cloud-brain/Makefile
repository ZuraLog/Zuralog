# =============================================================================
# Life Logger Cloud Brain — Makefile
# =============================================================================
# Common development commands.
#
# NOTE (Windows): `make` requires GNU Make. On Windows PowerShell, use the
# direct uv commands instead. See equivalent PowerShell commands below.
# =============================================================================

.PHONY: dev test lint migrate docker-up docker-down

## Start the development server with hot-reload
## Uses port 8001 to avoid conflict with workspace-mcp on port 8000.
## Android emulator connects via http://10.0.2.2:8001
##
## Windows PowerShell equivalent:
##   uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8001
dev:
	uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8001

## Run the test suite
## Windows PowerShell equivalent: uv run pytest tests/ -v
test:
	uv run pytest tests/ -v

## Run linting and formatting checks
## Windows PowerShell equivalent: uv run ruff check app/ tests/
lint:
	uv run ruff check app/ tests/
	uv run ruff format --check app/ tests/

## Format code
## Windows PowerShell equivalent: uv run ruff format app/ tests/
format:
	uv run ruff format app/ tests/

## Run Alembic migrations
## Windows PowerShell equivalent: uv run alembic upgrade head
migrate:
	uv run alembic upgrade head

## Create a new migration from model changes
## Windows PowerShell equivalent: uv run alembic revision --autogenerate -m "description"
migration:
	uv run alembic revision --autogenerate -m "$(msg)"

## Start Docker Compose services (Postgres + Redis)
## Windows PowerShell equivalent: docker compose up -d
docker-up:
	docker compose up -d

## Stop Docker Compose services
## Windows PowerShell equivalent: docker compose down
docker-down:
	docker compose down
