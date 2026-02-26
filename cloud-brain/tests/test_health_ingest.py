"""Tests for the health data ingest endpoint.

Verifies that the /api/v1/health/ingest endpoint correctly:
- Accepts valid payloads for all data types
- Returns 200 with counts
- Requires authentication
"""

from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi.testclient import TestClient

from app.api.v1.auth import _get_auth_service
from app.database import get_db
from app.main import app
from app.services.auth_service import AuthService


@pytest.fixture
def client_with_auth():
    """TestClient with mocked auth and DB dependencies."""
    mock_auth_service = AsyncMock(spec=AuthService)
    mock_auth_service.get_user = AsyncMock(return_value={"id": "user-test-123"})

    # Mock DB session with all the async context manager methods
    mock_db = AsyncMock()
    mock_db.execute = AsyncMock(return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=None)))
    mock_db.add = MagicMock()
    mock_db.commit = AsyncMock()

    app.dependency_overrides[_get_auth_service] = lambda: mock_auth_service
    app.dependency_overrides[get_db] = lambda: mock_db

    with TestClient(app, raise_server_exceptions=False) as c:
        yield c, mock_auth_service, mock_db

    app.dependency_overrides.clear()


def test_ingest_daily_metrics(client_with_auth):
    """Ingest daily scalar metrics (steps, HR, HRV, etc.)."""
    client, _, _ = client_with_auth
    payload = {
        "source": "apple_health",
        "daily_metrics": [
            {
                "date": "2026-02-26",
                "steps": 8500,
                "active_calories": 320,
                "resting_heart_rate": 62.5,
                "hrv_ms": 45.0,
                "vo2_max": 42.1,
            }
        ],
    }
    resp = client.post(
        "/api/v1/health/ingest",
        json=payload,
        headers={"Authorization": "Bearer fake-token"},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["success"] is True
    assert data["counts"]["daily_metrics"] == 1


def test_ingest_workouts(client_with_auth):
    """Ingest a workout from Apple Health."""
    client, _, _ = client_with_auth
    payload = {
        "source": "apple_health",
        "workouts": [
            {
                "original_id": "hk-workout-123",
                "activity_type": "running",
                "duration_seconds": 1800,
                "distance_meters": 5000.0,
                "calories": 400,
                "start_time": "2026-02-26T07:00:00",
            }
        ],
    }
    resp = client.post(
        "/api/v1/health/ingest",
        json=payload,
        headers={"Authorization": "Bearer fake-token"},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["counts"]["workouts"] == 1


def test_ingest_sleep(client_with_auth):
    """Ingest a sleep record."""
    client, _, _ = client_with_auth
    payload = {
        "source": "apple_health",
        "sleep": [{"date": "2026-02-26", "hours": 7.5}],
    }
    resp = client.post(
        "/api/v1/health/ingest",
        json=payload,
        headers={"Authorization": "Bearer fake-token"},
    )
    assert resp.status_code == 200
    assert resp.json()["counts"]["sleep"] == 1


def test_ingest_empty_payload(client_with_auth):
    """Empty payload (no data) should succeed with zero counts."""
    client, _, _ = client_with_auth
    resp = client.post(
        "/api/v1/health/ingest",
        json={"source": "apple_health"},
        headers={"Authorization": "Bearer fake-token"},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["success"] is True
    assert all(v == 0 for v in data["counts"].values())


def test_ingest_requires_auth():
    """Without auth header, ingest should return 403."""
    with TestClient(app, raise_server_exceptions=False) as client:
        resp = client.post("/api/v1/health/ingest", json={"source": "apple_health"})
    assert resp.status_code in (401, 403)


def test_ingest_mixed_payload(client_with_auth):
    """Ingest payload with multiple data types at once."""
    client, _, _ = client_with_auth
    payload = {
        "source": "apple_health",
        "daily_metrics": [{"date": "2026-02-26", "steps": 10000}],
        "sleep": [{"date": "2026-02-26", "hours": 8.0}],
        "nutrition": [{"date": "2026-02-26", "calories": 2100}],
        "weight": [{"date": "2026-02-26", "weight_kg": 75.5}],
    }
    resp = client.post(
        "/api/v1/health/ingest",
        json=payload,
        headers={"Authorization": "Bearer fake-token"},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["counts"]["daily_metrics"] == 1
    assert data["counts"]["sleep"] == 1
    assert data["counts"]["nutrition"] == 1
    assert data["counts"]["weight"] == 1
