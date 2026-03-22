"""Tests for supplements list management endpoints."""

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
    db.execute.return_value.scalars = MagicMock(
        return_value=MagicMock(all=MagicMock(return_value=[]))
    )
    db.commit = AsyncMock()
    db.add = MagicMock()
    app.dependency_overrides[get_db] = lambda: db
    yield db
    app.dependency_overrides.pop(get_db, None)


# ── GET /api/v1/supplements ──────────────────────────────────────────────────


def test_get_supplements_returns_200_empty(client):
    resp = client.get("/api/v1/supplements", headers=AUTH_HEADER)
    assert resp.status_code == 200
    data = resp.json()
    assert "supplements" in data
    assert data["supplements"] == []


def test_get_supplements_requires_auth():
    resp = TestClient(app).get("/api/v1/supplements")
    assert resp.status_code in (401, 403)


# ── POST /api/v1/supplements ──────────────────────────────────────────────────


def test_post_supplements_returns_200(client):
    payload = {
        "supplements": [
            {"name": "Vitamin D", "dose": "2000 IU", "timing": "morning"},
            {"name": "Omega-3", "dose": "1000 mg"},
        ]
    }
    resp = client.post("/api/v1/supplements", json=payload, headers=AUTH_HEADER)
    assert resp.status_code == 200
    data = resp.json()
    assert "supplements" in data
    assert len(data["supplements"]) == 2
    assert data["supplements"][0]["name"] == "Vitamin D"
    assert data["supplements"][0]["dose"] == "2000 IU"
    assert data["supplements"][0]["timing"] == "morning"
    assert data["supplements"][1]["name"] == "Omega-3"
    # Each supplement should have a server-assigned id
    for s in data["supplements"]:
        assert "id" in s
        # Validate it's a UUID
        uuid.UUID(s["id"])


def test_post_supplements_requires_auth():
    resp = TestClient(app).post(
        "/api/v1/supplements",
        json={"supplements": [{"name": "Test"}]},
    )
    assert resp.status_code in (401, 403)


def test_post_supplements_rejects_over_50():
    """Supplying more than 50 supplements should be rejected by validation."""
    app.dependency_overrides[get_authenticated_user_id] = lambda: TEST_USER_ID
    db = AsyncMock()
    db.execute = AsyncMock()
    db.commit = AsyncMock()
    db.add = MagicMock()
    app.dependency_overrides[get_db] = lambda: db
    try:
        payload = {
            "supplements": [{"name": f"Supp {i}"} for i in range(51)]
        }
        resp = TestClient(app).post(
            "/api/v1/supplements", json=payload, headers=AUTH_HEADER
        )
        assert resp.status_code == 422
    finally:
        app.dependency_overrides.pop(get_authenticated_user_id, None)
        app.dependency_overrides.pop(get_db, None)


def test_post_supplements_name_max_length():
    """A name longer than 200 chars should be rejected."""
    app.dependency_overrides[get_authenticated_user_id] = lambda: TEST_USER_ID
    db = AsyncMock()
    db.execute = AsyncMock()
    db.commit = AsyncMock()
    db.add = MagicMock()
    app.dependency_overrides[get_db] = lambda: db
    try:
        payload = {"supplements": [{"name": "A" * 201}]}
        resp = TestClient(app).post(
            "/api/v1/supplements", json=payload, headers=AUTH_HEADER
        )
        assert resp.status_code == 422
    finally:
        app.dependency_overrides.pop(get_authenticated_user_id, None)
        app.dependency_overrides.pop(get_db, None)


def test_post_supplements_empty_list(client):
    """An empty supplement list should be accepted (clears all)."""
    resp = client.post(
        "/api/v1/supplements",
        json={"supplements": []},
        headers=AUTH_HEADER,
    )
    assert resp.status_code == 200
    assert resp.json()["supplements"] == []


def test_post_supplements_optional_fields(client):
    """dose and timing are optional."""
    payload = {"supplements": [{"name": "Magnesium"}]}
    resp = client.post("/api/v1/supplements", json=payload, headers=AUTH_HEADER)
    assert resp.status_code == 200
    s = resp.json()["supplements"][0]
    assert s["name"] == "Magnesium"
    assert s["dose"] is None
    assert s["timing"] is None
