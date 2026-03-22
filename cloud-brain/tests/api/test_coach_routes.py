"""Tests for Coach and Trends endpoints."""
import uuid
from unittest.mock import AsyncMock, MagicMock
import pytest
from fastapi.testclient import TestClient
from app.api.deps import get_authenticated_user_id
from app.database import get_db
from app.main import app

TEST_USER_ID = str(uuid.uuid4())
AUTH_HEADER = {"Authorization": "Bearer test-token"}


@pytest.fixture
def client(mock_db, mock_auth):
    return TestClient(app)


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
    db.execute.return_value.scalar_one_or_none = MagicMock(return_value=None)
    db.execute.return_value.scalars = MagicMock(return_value=MagicMock(all=MagicMock(return_value=[])))
    app.dependency_overrides[get_db] = lambda: db
    yield db
    app.dependency_overrides.pop(get_db, None)


def test_coach_context_returns_200(client):
    resp = client.get("/api/v1/coach/context?days=7", headers=AUTH_HEADER)
    assert resp.status_code == 200
    data = resp.json()
    assert "daily_summaries" in data
    assert "recent_events" in data
    assert "sessions" in data


def test_coach_context_requires_auth():
    resp = TestClient(app).get("/api/v1/coach/context")
    assert resp.status_code in (401, 403)


def test_trends_correlation_returns_200(client):
    resp = client.get(
        "/api/v1/trends/correlation?metric_a=sleep_duration&metric_b=mood&days=30",
        headers=AUTH_HEADER
    )
    assert resp.status_code == 200
    data = resp.json()
    assert "data_points" in data
    assert "correlation" in data
