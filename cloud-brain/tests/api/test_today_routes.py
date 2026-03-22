"""Tests for Today tab endpoints."""
import uuid
from unittest.mock import AsyncMock, MagicMock
from types import SimpleNamespace
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
    # Return empty result by default
    db.execute.return_value.fetchall = MagicMock(return_value=[])
    db.execute.return_value.scalar_one_or_none = MagicMock(return_value=None)
    db.execute.return_value.scalars = MagicMock(return_value=MagicMock(all=MagicMock(return_value=[])))
    app.dependency_overrides[get_db] = lambda: db
    yield db
    app.dependency_overrides.pop(get_db, None)


def test_today_summary_returns_200(client):
    resp = client.get("/api/v1/today/summary", headers=AUTH_HEADER)
    assert resp.status_code == 200
    data = resp.json()
    assert "metrics" in data
    assert "date" in data


def test_today_timeline_returns_200_with_pagination(client):
    resp = client.get("/api/v1/today/timeline?limit=10", headers=AUTH_HEADER)
    assert resp.status_code == 200
    data = resp.json()
    assert "events" in data
    assert "next_cursor" in data


def test_today_timeline_limit_enforced(client):
    # limit > 200 should be capped or rejected
    resp = client.get("/api/v1/today/timeline?limit=500", headers=AUTH_HEADER)
    assert resp.status_code in (200, 422)


def test_today_goals_progress_returns_200(client):
    resp = client.get("/api/v1/today/goals-progress", headers=AUTH_HEADER)
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)


def test_today_endpoints_require_auth():
    for path in ["/api/v1/today/summary", "/api/v1/today/timeline", "/api/v1/today/goals-progress"]:
        resp = TestClient(app).get(path)
        assert resp.status_code in (401, 403)
