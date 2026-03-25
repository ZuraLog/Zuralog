"""
Tests for GET /api/v1/users/me/export endpoint (GDPR Art. 20 — data portability).

Verifies that the endpoint:
- Returns 200 with a JSON body
- Response contains all expected top-level keys
- User profile fields are present in the 'user' sub-dict
- Returns 404 if the user does not exist in the local DB
"""

from unittest.mock import AsyncMock, MagicMock

import pytest


USER_ID = "export-user-uuid-5678"


def _make_db_user():
    """Return a minimal mock User ORM object."""
    user = MagicMock()
    user.id = USER_ID
    user.email = "export@example.com"
    user.display_name = "Export User"
    user.nickname = "Expy"
    user.created_at = "2024-01-01T00:00:00+00:00"
    return user


def _make_scalar_result(obj):
    """Wrap obj in a mock that mimics scalars().first() / .all()."""
    result = MagicMock()
    result.scalars.return_value.first.return_value = obj
    result.scalars.return_value.all.return_value = []
    return result


@pytest.fixture
def mock_db_with_user():
    """DB session that returns a valid user on first execute, empty lists for health tables."""
    db = AsyncMock()

    call_count = 0

    async def execute_side_effect(*args, **kwargs):
        nonlocal call_count
        call_count += 1
        if call_count == 1:
            # First call: select(User).where(...)
            return _make_scalar_result(_make_db_user())
        # Subsequent calls: health table queries — return empty lists
        result = MagicMock()
        result.scalars.return_value.all.return_value = []
        return result

    db.execute = AsyncMock(side_effect=execute_side_effect)
    return db


@pytest.fixture
def mock_db_no_user():
    """DB session that returns None for the user lookup."""
    db = AsyncMock()
    result = _make_scalar_result(None)
    db.execute = AsyncMock(return_value=result)
    return db


@pytest.mark.asyncio
async def test_export_user_data_returns_dict(mock_db_with_user):
    """export_user_data should return a dict without raising."""
    from app.api.v1.users import export_user_data

    response = await export_user_data(user_id=USER_ID, db=mock_db_with_user)

    assert isinstance(response, dict)


@pytest.mark.asyncio
async def test_export_user_data_contains_required_keys(mock_db_with_user):
    """Response must contain all required GDPR export keys."""
    from app.api.v1.users import export_user_data

    response = await export_user_data(user_id=USER_ID, db=mock_db_with_user)

    expected_keys = {"user", "daily_metrics", "activities", "sleep", "nutrition", "weight", "goals"}
    assert expected_keys.issubset(response.keys()), (
        f"Missing keys: {expected_keys - response.keys()}"
    )


@pytest.mark.asyncio
async def test_export_user_data_user_fields(mock_db_with_user):
    """The 'user' sub-dict must include id and email."""
    from app.api.v1.users import export_user_data

    response = await export_user_data(user_id=USER_ID, db=mock_db_with_user)

    assert response["user"]["id"] == USER_ID
    assert response["user"]["email"] == "export@example.com"
    assert response["user"]["display_name"] == "Export User"
    assert response["user"]["nickname"] == "Expy"


@pytest.mark.asyncio
async def test_export_user_data_health_lists_are_lists(mock_db_with_user):
    """All health data fields should be lists (even if empty)."""
    from app.api.v1.users import export_user_data

    response = await export_user_data(user_id=USER_ID, db=mock_db_with_user)

    for key in ("daily_metrics", "activities", "sleep", "nutrition", "weight", "goals"):
        assert isinstance(response[key], list), f"Expected list for key '{key}'"


@pytest.mark.asyncio
async def test_export_user_data_user_not_found_raises_404(mock_db_no_user):
    """Should raise 404 if user does not exist in local DB."""
    from fastapi import HTTPException

    from app.api.v1.users import export_user_data

    with pytest.raises(HTTPException) as exc_info:
        await export_user_data(user_id="ghost-user", db=mock_db_no_user)

    assert exc_info.value.status_code == 404
    assert "not found" in exc_info.value.detail.lower()
