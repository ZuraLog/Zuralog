"""Tests for unified ingest endpoints."""
import uuid
from datetime import date, datetime, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

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
    db.commit = AsyncMock()
    db.refresh = AsyncMock()

    metric_row = SimpleNamespace(
        metric_type="steps", unit="steps", aggregation_fn="sum",
        min_value=0.0, max_value=100000.0, is_active=True
    )

    # Each db.execute() call returns a different mock result object.
    # Call order for the 201 path (with idempotency_key):
    #   1. Idempotency check → scalar_one_or_none = None
    #   2. Metric def lookup → scalar_one_or_none = metric_row
    #   3. flush (implicit)
    #   4. Recompute select events → fetchall = []
    #   5. Delete daily_summaries (text SQL) → no result needed
    # We use side_effect to return fresh result mocks for each call.
    call_count = {"n": 0}
    idempotency_result = MagicMock()
    idempotency_result.scalar_one_or_none = MagicMock(return_value=None)

    metric_def_result = MagicMock()
    metric_def_result.scalar_one_or_none = MagicMock(return_value=metric_row)

    events_result = MagicMock()
    events_result.fetchall = MagicMock(return_value=[])

    generic_result = MagicMock()

    results = [idempotency_result, metric_def_result, events_result, generic_result, generic_result]

    async def execute_side_effect(*args, **kwargs):
        idx = min(call_count["n"], len(results) - 1)
        call_count["n"] += 1
        return results[idx]

    db.execute = AsyncMock(side_effect=execute_side_effect)

    app.dependency_overrides[get_db] = lambda: db
    yield db
    app.dependency_overrides.pop(get_db, None)


def test_single_ingest_returns_201(client):
    payload = {
        "metric_type": "steps",
        "value": 5000,
        "unit": "steps",
        "source": "manual",
        "recorded_at": "2026-03-22T14:30:00+05:00",
        "idempotency_key": str(uuid.uuid4()),
    }
    resp = client.post("/api/v1/ingest", json=payload, headers=AUTH_HEADER)
    assert resp.status_code == 201
    data = resp.json()
    assert "event_id" in data
    assert data["date"] == "2026-03-22"


def test_single_ingest_missing_offset_returns_422(client):
    payload = {
        "metric_type": "steps",
        "value": 5000,
        "unit": "steps",
        "source": "manual",
        "recorded_at": "2026-03-22T14:30:00",  # no offset
    }
    resp = client.post("/api/v1/ingest", json=payload, headers=AUTH_HEADER)
    assert resp.status_code == 422


def test_single_ingest_no_auth_returns_401():
    payload = {
        "metric_type": "steps", "value": 5000, "unit": "steps",
        "source": "manual", "recorded_at": "2026-03-22T14:30:00+00:00",
    }
    resp = TestClient(app).post("/api/v1/ingest", json=payload)
    assert resp.status_code in (401, 403)
