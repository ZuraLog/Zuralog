"""Tests for the message router."""
import pytest
from unittest.mock import AsyncMock, MagicMock, patch

from app.agent.classifier import MessageTier
from app.agent.router import LimitExhaustedException, RoutingResult, route_message
from app.services.rate_limiter import ModelLimitResult


def _make_limits(
    flash_allowed=True,
    zura_allowed=True,
    burst_allowed=True,
    flash_remaining=10,
    zura_remaining=5,
    burst_remaining=15,
    flash_reset_seconds=86400,
    zura_reset_seconds=86400,
    burst_reset_seconds=18000,
    flash_limit=20,
    zura_limit=5,
    burst_limit=20,
):
    return ModelLimitResult(
        flash_allowed=flash_allowed,
        zura_allowed=zura_allowed,
        burst_allowed=burst_allowed,
        flash_remaining=flash_remaining,
        zura_remaining=zura_remaining,
        burst_remaining=burst_remaining,
        flash_limit=flash_limit,
        zura_limit=zura_limit,
        burst_limit=burst_limit,
        flash_reset_seconds=flash_reset_seconds,
        zura_reset_seconds=zura_reset_seconds,
        burst_reset_seconds=burst_reset_seconds,
    )


def _make_rate_limiter(limits: ModelLimitResult):
    rl = MagicMock()
    rl.check_model_limits = AsyncMock(return_value=limits)
    return rl


class TestRouteMessage:
    @pytest.mark.asyncio
    async def test_burst_exhausted_raises(self):
        """Burst window exhausted → LimitExhaustedException with is_burst=True."""
        limits = _make_limits(burst_allowed=False)
        rl = _make_rate_limiter(limits)
        with pytest.raises(LimitExhaustedException) as exc_info:
            await route_message("hello", "user1", "free", rl)
        assert exc_info.value.is_burst is True

    @pytest.mark.asyncio
    async def test_both_exhausted_raises(self):
        """Both models exhausted → LimitExhaustedException with is_burst=False."""
        limits = _make_limits(flash_allowed=False, zura_allowed=False)
        rl = _make_rate_limiter(limits)
        with pytest.raises(LimitExhaustedException) as exc_info:
            await route_message("hello", "user1", "free", rl)
        assert exc_info.value.is_burst is False

    @pytest.mark.asyncio
    async def test_only_flash_available_skips_classifier(self):
        """Only Zura Flash available → routes to Zura Flash without calling classifier."""
        limits = _make_limits(zura_allowed=False)
        rl = _make_rate_limiter(limits)
        with patch("app.agent.router.classify_message") as mock_classify:
            result = await route_message("complex analysis message", "user1", "free", rl)
            mock_classify.assert_not_called()
        assert result.model_tier == "zura_flash"
        assert result.classifier_result == "skipped"

    @pytest.mark.asyncio
    async def test_both_available_deep_routes_to_zura(self):
        """Both available + deep_analysis → routes to Zura."""
        limits = _make_limits()
        rl = _make_rate_limiter(limits)
        with patch("app.agent.router.classify_message", return_value=MessageTier.deep_analysis):
            result = await route_message("analyze my HRV trends", "user1", "free", rl)
        assert result.model_tier == "zura"
        assert result.classifier_result == "deep_analysis"

    @pytest.mark.asyncio
    async def test_both_available_standard_routes_to_flash(self):
        """Both available + standard → routes to Zura Flash."""
        limits = _make_limits()
        rl = _make_rate_limiter(limits)
        with patch("app.agent.router.classify_message", return_value=MessageTier.standard):
            result = await route_message("good morning", "user1", "free", rl)
        assert result.model_tier == "zura_flash"
        assert result.classifier_result == "standard"

    @pytest.mark.asyncio
    async def test_only_zura_available_deep_routes_to_zura(self):
        """Only Zura available + deep_analysis → routes to Zura."""
        limits = _make_limits(flash_allowed=False)
        rl = _make_rate_limiter(limits)
        with patch("app.agent.router.classify_message", return_value=MessageTier.deep_analysis):
            result = await route_message("analyze my training load", "user1", "free", rl)
        assert result.model_tier == "zura"

    @pytest.mark.asyncio
    async def test_only_zura_available_standard_raises(self):
        """Only Zura available + standard → raises LimitExhaustedException (Flash needed but gone)."""
        limits = _make_limits(flash_allowed=False)
        rl = _make_rate_limiter(limits)
        with patch("app.agent.router.classify_message", return_value=MessageTier.standard):
            with pytest.raises(LimitExhaustedException):
                await route_message("good morning", "user1", "free", rl)
