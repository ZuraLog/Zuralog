"""
Life Logger Cloud Brain — Rate Limit Middleware Tests.
"""

from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi import HTTPException

from app.api.deps import check_rate_limit
from app.services.rate_limiter import RateLimitResult


@pytest.mark.asyncio
async def test_rate_limit_allows_request():
    """Request within limits should pass through."""
    mock_limiter = AsyncMock()
    mock_limiter.check_limit.return_value = RateLimitResult(allowed=True, limit=50, remaining=49, reset_seconds=3600)
    mock_user = {"id": "user-1"}
    mock_db = AsyncMock()
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = False
    mock_db.execute.return_value = mock_result

    result = await check_rate_limit(user=mock_user, limiter=mock_limiter, db=mock_db)
    assert result is None


@pytest.mark.asyncio
async def test_rate_limit_blocks_exceeded():
    """Request exceeding limit should raise 429."""
    mock_limiter = AsyncMock()
    mock_limiter.check_limit.return_value = RateLimitResult(allowed=False, limit=50, remaining=0, reset_seconds=3600)
    mock_user = {"id": "user-1"}
    mock_db = AsyncMock()
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = False
    mock_db.execute.return_value = mock_result

    with pytest.raises(HTTPException) as exc_info:
        await check_rate_limit(user=mock_user, limiter=mock_limiter, db=mock_db)
    assert exc_info.value.status_code == 429
