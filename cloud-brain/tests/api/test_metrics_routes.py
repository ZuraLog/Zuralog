"""Tests for GET /api/v1/metrics/latest."""
import uuid
from datetime import date
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi.testclient import TestClient

from app.api.deps import get_authenticated_user_id
from app.database import get_db
from app.main import app

TEST_USER_ID = str(uuid.uuid4())
AUTH_HEADER = {"Authorization": "Bearer test-token"}


@pytest.fixture
def mock_auth():
    app.dependency_overrides[get_authenticated_user_id] = lambda: TEST_USER_ID
    yield
    app.dependency_overrides.pop(get_authenticated_user_id, None)


@pytest.fixture
def mock_db():
    db = AsyncMock()
    db.execute = AsyncMock()
    db.execute.return_value.fetchall = MagicMock(return_value=[])
    app.dependency_overrides[get_db] = lambda: db
    yield db
    app.dependency_overrides.pop(get_db, None)


@pytest.fixture
def client(mock_db, mock_auth):
    return TestClient(app)


def test_metrics_latest_returns_200_empty(client):
    """Endpoint returns 200 with an empty list when no data exists."""
    resp = client.get("/api/v1/metrics/latest?types=weight_kg,steps", headers=AUTH_HEADER)
    assert resp.status_code == 200
    assert resp.json()["metrics"] == []


def test_metrics_latest_returns_data(client, mock_db):
    """Endpoint returns metric data when rows exist."""
    mock_db.execute.return_value.fetchall = MagicMock(return_value=[
        SimpleNamespace(metric_type="weight_kg", value=87.3, unit="kg", date=date(2026, 3, 22)),
        SimpleNamespace(metric_type="steps", value=8432.0, unit="steps", date=date(2026, 3, 25)),
    ])
    resp = client.get("/api/v1/metrics/latest?types=weight_kg,steps", headers=AUTH_HEADER)
    assert resp.status_code == 200
    data = resp.json()
    assert len(data["metrics"]) == 2
    weight = next(m for m in data["metrics"] if m["metric_type"] == "weight_kg")
    assert weight["value"] == 87.3
    assert weight["date"] == "2026-03-22"


def test_metrics_latest_requires_types_param(client):
    resp = client.get("/api/v1/metrics/latest", headers=AUTH_HEADER)
    assert resp.status_code == 422


def test_metrics_latest_requires_auth():
    resp = TestClient(app).get("/api/v1/metrics/latest?types=weight_kg")
    assert resp.status_code in (401, 403)
