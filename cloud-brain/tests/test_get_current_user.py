"""
Life Logger Cloud Brain — get_current_user Dependency Tests.

Tests the shared authentication dependency that validates tokens
and returns the User ORM instance.
"""

from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi import HTTPException

from app.api.deps import get_current_user
from app.models.user import User


@pytest.mark.asyncio
async def test_returns_user_on_valid_token():
    """Valid token returns the matching User from DB."""
    mock_auth = AsyncMock()
    mock_auth.get_user.return_value = {"id": "u-1", "email": "a@b.com"}

    mock_db = AsyncMock()
    mock_result = MagicMock()
    mock_user = User(id="u-1", email="a@b.com", subscription_tier="pro")
    mock_result.scalar_one_or_none.return_value = mock_user
    mock_db.execute.return_value = mock_result

    mock_credentials = MagicMock()
    mock_credentials.credentials = "valid-token"

    user = await get_current_user(
        credentials=mock_credentials,
        auth_service=mock_auth,
        db=mock_db,
    )
    assert user.id == "u-1"
    assert user.subscription_tier == "pro"


@pytest.mark.asyncio
async def test_raises_on_invalid_token():
    """Invalid token raises HTTPException from auth service."""
    mock_auth = AsyncMock()
    mock_auth.get_user.side_effect = HTTPException(status_code=401, detail="Unauthorized")

    mock_db = AsyncMock()
    mock_credentials = MagicMock()
    mock_credentials.credentials = "bad-token"

    with pytest.raises(HTTPException) as exc_info:
        await get_current_user(
            credentials=mock_credentials,
            auth_service=mock_auth,
            db=mock_db,
        )
    assert exc_info.value.status_code == 401


@pytest.mark.asyncio
async def test_raises_404_when_user_not_in_db():
    """Valid Supabase token but user not in local DB raises 404."""
    mock_auth = AsyncMock()
    mock_auth.get_user.return_value = {"id": "u-missing", "email": "x@y.com"}

    mock_db = AsyncMock()
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = None
    mock_db.execute.return_value = mock_result

    mock_credentials = MagicMock()
    mock_credentials.credentials = "valid-token"

    with pytest.raises(HTTPException) as exc_info:
        await get_current_user(
            credentials=mock_credentials,
            auth_service=mock_auth,
            db=mock_db,
        )
    assert exc_info.value.status_code == 404
