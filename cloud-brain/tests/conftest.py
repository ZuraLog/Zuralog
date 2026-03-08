"""
Zuralog Cloud Brain — Shared Test Fixtures.

Provides reusable pytest fixtures for integration and new unit tests.
Existing per-file fixtures (e.g. ``client`` in ``test_auth.py``) take
priority via pytest scoping rules, so these shared fixtures are safe
to add without breaking existing tests.

Fixtures:
    mock_db: AsyncMock for SQLAlchemy AsyncSession.
    mock_auth_service: AsyncMock(spec=AuthService).
    test_user_data: Dict with credentials and auth response.
    auth_headers: Dict with Bearer token Authorization header.
    integration_client: TestClient with dependency overrides
        (yields tuple of client, mock_auth, mock_db).
"""

import sys
import types
from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi.testclient import TestClient

# ---------------------------------------------------------------------------
# Pre-import stubs for Phase-2 routes that are incompatible with Python 3.14.
# These stubs must be inserted before ``app.main`` is imported so that the
# dynamic module loader does not attempt to evaluate the broken annotations.
# ---------------------------------------------------------------------------


def _stub(module_path: str) -> None:
    """Insert a lightweight stub into sys.modules if not already present.

    The stub provides a real ``fastapi.APIRouter`` so that ``app.main``
    can call ``app.include_router()`` without installing a mock lifespan
    that breaks ``TestClient`` startup.
    """
    if module_path not in sys.modules:
        from fastapi import APIRouter  # noqa: PLC0415 — local import to keep stub minimal

        stub = types.ModuleType(module_path)
        stub.router = APIRouter()
        sys.modules[module_path] = stub


for _broken in (
    "app.api.v1.journal_routes",
    "app.api.v1.achievement_routes",
    "app.api.v1.streak_routes",
    "app.api.v1.quick_log_routes",
    "app.api.v1.emergency_card_routes",
):
    _stub(_broken)

from app.api.deps import _get_auth_service
from app.database import get_db
from app.main import app
from app.services.auth_service import AuthService


@pytest.fixture
def mock_db():
    """Create an AsyncMock for SQLAlchemy AsyncSession.

    Returns:
        AsyncMock: A mock database session.
    """
    return AsyncMock()


@pytest.fixture
def mock_auth_service():
    """Create an AsyncMock with AuthService spec.

    The spec ensures only real AuthService methods can be called,
    catching typos and API drift at test time.

    Returns:
        AsyncMock: A mock AuthService instance.
    """
    return AsyncMock(spec=AuthService)


@pytest.fixture
def test_user_data():
    """Standard user credentials and expected auth response.

    Returns:
        dict: Contains ``email``, ``password``, and ``auth_response``
            with user_id, tokens, and expiry.
    """
    return {
        "email": "integration@example.com",
        "password": "IntegrationTest1!",
        "auth_response": {
            "user_id": "int-user-001",
            "access_token": "int-at-abc",
            "refresh_token": "int-rt-xyz",
            "expires_in": 3600,
        },
    }


@pytest.fixture
def auth_headers():
    """Authorization header dict with a Bearer token.

    Returns:
        dict: ``{"Authorization": "Bearer test-integration-token"}``.
    """
    return {"Authorization": "Bearer test-integration-token"}


@pytest.fixture
def integration_client(mock_auth_service, mock_db):
    """TestClient with mocked AuthService and DB dependencies.

    Designed for integration tests that need the full FastAPI app
    with external dependencies replaced by mocks. Named
    ``integration_client`` to avoid collisions with per-file
    ``client`` fixtures in existing unit tests.

    Yields:
        tuple: (TestClient, mock_auth_service, mock_db).
    """
    app.dependency_overrides[_get_auth_service] = lambda: mock_auth_service
    app.dependency_overrides[get_db] = lambda: mock_db

    with TestClient(app, raise_server_exceptions=False) as c:
        yield c, mock_auth_service, mock_db

    app.dependency_overrides.clear()
