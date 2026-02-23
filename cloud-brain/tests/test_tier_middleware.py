"""
Zuralog Cloud Brain — Tier Middleware Tests.

Tests the require_tier dependency factory for subscription enforcement.
"""

import pytest
from fastapi import HTTPException

from app.api.deps import require_tier
from app.models.user import User


@pytest.mark.asyncio
async def test_pro_user_passes_pro_gate():
    """Pro user should pass a pro-tier gate."""
    user = User(id="u-1", email="a@b.com", subscription_tier="pro")
    check = require_tier("pro")
    result = await check(user=user)
    assert result.id == "u-1"


@pytest.mark.asyncio
async def test_free_user_blocked_by_pro_gate():
    """Free user should be blocked by a pro-tier gate."""
    user = User(id="u-2", email="b@c.com", subscription_tier="free")
    check = require_tier("pro")
    with pytest.raises(HTTPException) as exc_info:
        await check(user=user)
    assert exc_info.value.status_code == 403
    assert "pro" in exc_info.value.detail.lower()


@pytest.mark.asyncio
async def test_free_user_passes_free_gate():
    """Free user should pass a free-tier gate."""
    user = User(id="u-3", email="c@d.com", subscription_tier="free")
    check = require_tier("free")
    result = await check(user=user)
    assert result.id == "u-3"


@pytest.mark.asyncio
async def test_pro_user_passes_free_gate():
    """Pro user should pass a free-tier gate (tier hierarchy)."""
    user = User(id="u-4", email="d@e.com", subscription_tier="pro")
    check = require_tier("free")
    result = await check(user=user)
    assert result.id == "u-4"


@pytest.mark.asyncio
async def test_403_detail_includes_current_tier():
    """403 response should mention user's current tier."""
    user = User(id="u-5", email="e@f.com", subscription_tier="free")
    check = require_tier("pro")
    with pytest.raises(HTTPException) as exc_info:
        await check(user=user)
    assert "free" in exc_info.value.detail.lower()
