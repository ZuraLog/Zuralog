"""Tests for quick_log_routes guards and helpers."""

from datetime import timezone
from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi.testclient import TestClient

from app.api.v1.quick_log_routes import _resolve_logged_at


def test_resolve_logged_at_normalizes_offset_to_utc():
    """A timestamp with a non-UTC offset must be returned as UTC ISO 8601."""
    # +05:30 offset → subtract 5h30m → UTC
    result = _resolve_logged_at("2026-03-17T10:00:00+05:30")
    assert result == "2026-03-17T04:30:00+00:00"


def test_resolve_logged_at_utc_input_unchanged():
    """A timestamp already in UTC must round-trip unchanged."""
    result = _resolve_logged_at("2026-03-17T04:30:00+00:00")
    assert result == "2026-03-17T04:30:00+00:00"


def test_resolve_logged_at_z_suffix_normalized():
    """A timestamp ending in Z must be returned as +00:00."""
    result = _resolve_logged_at("2026-03-17T04:30:00Z")
    assert result == "2026-03-17T04:30:00+00:00"


def test_resolve_logged_at_none_returns_utc_now():
    """None input must return a valid UTC ISO 8601 string."""
    result = _resolve_logged_at(None)
    from datetime import datetime, timedelta

    dt = datetime.fromisoformat(result)
    assert dt.tzinfo is not None
    assert dt.utcoffset() == timedelta(0), f"Expected UTC offset (0), got {dt.utcoffset()}"


# ---------------------------------------------------------------------------
# Supplement log — empty taken_supplement_ids guard
# ---------------------------------------------------------------------------

TEST_USER_ID = "test-user-supplement-guard"


def test_supplement_log_rejects_empty_ids(mock_db, auth_headers):
    """POST /quick-log/supplements with an empty ID list must return 422."""
    from app.api.deps import _get_auth_service, get_authenticated_user_id
    from app.database import get_db
    from app.main import app

    app.dependency_overrides[get_authenticated_user_id] = lambda: TEST_USER_ID
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        with TestClient(app, raise_server_exceptions=False) as client:
            response = client.post(
                "/api/v1/quick-log/supplements",
                json={"taken_supplement_ids": []},
                headers=auth_headers,
            )
    finally:
        app.dependency_overrides.pop(get_authenticated_user_id, None)
        app.dependency_overrides.pop(get_db, None)

    assert response.status_code == 422
    body = response.json()
    assert "taken_supplement_ids" in body.get("detail", "").lower()


def test_supplement_log_accepts_nonempty_ids(mock_db, auth_headers):
    """POST /quick-log/supplements with at least one valid ID must not fail the empty-list guard."""
    from app.api.deps import get_authenticated_user_id
    from app.database import get_db
    from app.main import app

    # DB returns the ID as valid so the ownership check passes.
    db_result = MagicMock()
    db_result.all.return_value = [("supp-1",)]
    mock_db.execute = AsyncMock(return_value=db_result)
    mock_db.add = MagicMock()
    mock_db.commit = AsyncMock()
    mock_db.refresh = AsyncMock()

    app.dependency_overrides[get_authenticated_user_id] = lambda: TEST_USER_ID
    app.dependency_overrides[get_db] = lambda: mock_db

    try:
        with TestClient(app, raise_server_exceptions=False) as client:
            response = client.post(
                "/api/v1/quick-log/supplements",
                json={"taken_supplement_ids": ["supp-1"]},
                headers=auth_headers,
            )
    finally:
        app.dependency_overrides.pop(get_authenticated_user_id, None)
        app.dependency_overrides.pop(get_db, None)

    # Must NOT be rejected by the empty-list guard specifically.
    detail = response.json().get("detail", "") if response.status_code == 422 else ""
    assert "taken_supplement_ids must contain" not in detail
