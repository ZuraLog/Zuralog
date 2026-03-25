"""
Tests for DELETE /api/v1/users/me endpoint (GDPR Art. 17 — right to erasure).

Verifies that the endpoint:
- Returns 204 No Content on success
- Calls db.execute for each health table DELETE and the users DELETE
- Calls db.commit after all deletions
- Calls admin_delete_user as best-effort cleanup
"""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest


USER_ID = "test-user-uuid-1234"
VALID_TOKEN = "valid.jwt.token"


@pytest.fixture
def mock_db():
    """Async DB session mock with execute and commit as coroutines."""
    db = AsyncMock()
    db.execute = AsyncMock(return_value=MagicMock())
    db.commit = AsyncMock()
    return db


@pytest.fixture
def mock_auth_service():
    """AuthService mock returning a valid user dict."""
    svc = AsyncMock()
    svc.get_user = AsyncMock(return_value={"id": USER_ID, "email": "user@example.com"})
    svc.admin_delete_user = AsyncMock()
    return svc


@pytest.mark.asyncio
async def test_delete_account_returns_204(mock_db, mock_auth_service):
    """DELETE /me should return 204 and execute DELETE statements."""
    from app.api.v1.users import delete_account

    mock_request = MagicMock()
    mock_request.app.state.cache_service = None

    mock_credentials = MagicMock()
    mock_credentials.credentials = VALID_TOKEN

    result = await delete_account(
        request=mock_request,
        credentials=mock_credentials,
        auth_service=mock_auth_service,
        db=mock_db,
    )

    # Endpoint returns None (FastAPI converts to 204 No Content)
    assert result is None


@pytest.mark.asyncio
async def test_delete_account_executes_deletes(mock_db, mock_auth_service):
    """delete_account must call db.execute for all health tables + users."""
    from app.api.v1.users import delete_account

    mock_request = MagicMock()
    mock_request.app.state.cache_service = None

    mock_credentials = MagicMock()
    mock_credentials.credentials = VALID_TOKEN

    await delete_account(
        request=mock_request,
        credentials=mock_credentials,
        auth_service=mock_auth_service,
        db=mock_db,
    )

    # 7 health tables + 1 users table = 8 execute calls
    assert mock_db.execute.call_count == 8


@pytest.mark.asyncio
async def test_delete_account_commits(mock_db, mock_auth_service):
    """delete_account must commit after deletions."""
    from app.api.v1.users import delete_account

    mock_request = MagicMock()
    mock_request.app.state.cache_service = None

    mock_credentials = MagicMock()
    mock_credentials.credentials = VALID_TOKEN

    await delete_account(
        request=mock_request,
        credentials=mock_credentials,
        auth_service=mock_auth_service,
        db=mock_db,
    )

    mock_db.commit.assert_awaited_once()


@pytest.mark.asyncio
async def test_delete_account_calls_admin_delete(mock_db, mock_auth_service):
    """delete_account should attempt to delete the user from Supabase Auth."""
    from app.api.v1.users import delete_account

    mock_request = MagicMock()
    mock_request.app.state.cache_service = None

    mock_credentials = MagicMock()
    mock_credentials.credentials = VALID_TOKEN

    await delete_account(
        request=mock_request,
        credentials=mock_credentials,
        auth_service=mock_auth_service,
        db=mock_db,
    )

    mock_auth_service.admin_delete_user.assert_awaited_once_with(USER_ID)


@pytest.mark.asyncio
async def test_delete_account_invalid_token_raises_401(mock_db):
    """If get_user returns a dict without 'id', raise 401."""
    from fastapi import HTTPException

    from app.api.v1.users import delete_account

    bad_auth = AsyncMock()
    bad_auth.get_user = AsyncMock(return_value={"email": "no-id@example.com"})

    mock_request = MagicMock()
    mock_credentials = MagicMock()
    mock_credentials.credentials = "bad.token"

    with pytest.raises(HTTPException) as exc_info:
        await delete_account(
            request=mock_request,
            credentials=mock_credentials,
            auth_service=bad_auth,
            db=mock_db,
        )

    assert exc_info.value.status_code == 401


@pytest.mark.asyncio
async def test_delete_account_supabase_failure_does_not_abort(mock_db, mock_auth_service):
    """If admin_delete_user raises, the endpoint should still complete (best-effort)."""
    from app.api.v1.users import delete_account

    mock_auth_service.admin_delete_user = AsyncMock(side_effect=Exception("Supabase down"))

    mock_request = MagicMock()
    mock_request.app.state.cache_service = None

    mock_credentials = MagicMock()
    mock_credentials.credentials = VALID_TOKEN

    # Should not raise — the exception is caught and logged
    result = await delete_account(
        request=mock_request,
        credentials=mock_credentials,
        auth_service=mock_auth_service,
        db=mock_db,
    )

    assert result is None
    mock_db.commit.assert_awaited_once()


@pytest.mark.asyncio
async def test_delete_account_invalidates_cache(mock_db, mock_auth_service):
    """If cache_service is present, invalidate_pattern must be called."""
    from app.api.v1.users import delete_account

    mock_cache = AsyncMock()
    mock_request = MagicMock()
    mock_request.app.state.cache_service = mock_cache

    mock_credentials = MagicMock()
    mock_credentials.credentials = VALID_TOKEN

    await delete_account(
        request=mock_request,
        credentials=mock_credentials,
        auth_service=mock_auth_service,
        db=mock_db,
    )

    mock_cache.invalidate_pattern.assert_awaited_once_with(f"cache:*{USER_ID}*")
