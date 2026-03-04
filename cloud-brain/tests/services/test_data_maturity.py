"""
Tests for DataMaturityService.

Tests cover:
- 3 days → BUILDING level
- 7 days → READY level
- 14 days → STRONG level
- 30 days → EXCELLENT level
- Feature thresholds respected
- Progress percentage calculates correctly
"""

from __future__ import annotations

from unittest.mock import AsyncMock, patch

import pytest

from app.services.data_maturity import DataMaturityResult, DataMaturityService, MaturityLevel


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


async def _run(days: int) -> DataMaturityResult:
    """Run get_maturity with a mocked day count."""
    svc = DataMaturityService()
    db = AsyncMock()
    with patch.object(svc, "_count_days_with_data", return_value=days):
        return await svc.get_maturity("user-001", db)


# ---------------------------------------------------------------------------
# Level tests
# ---------------------------------------------------------------------------


class TestMaturityLevels:
    @pytest.mark.asyncio
    async def test_zero_days_returns_building(self):
        """0 days of data → BUILDING (or edge case below minimum)."""
        result = await _run(0)
        assert result.level == MaturityLevel.BUILDING

    @pytest.mark.asyncio
    async def test_three_days_returns_building(self):
        result = await _run(3)
        assert result.level == MaturityLevel.BUILDING

    @pytest.mark.asyncio
    async def test_six_days_returns_building(self):
        result = await _run(6)
        assert result.level == MaturityLevel.BUILDING

    @pytest.mark.asyncio
    async def test_seven_days_returns_ready(self):
        result = await _run(7)
        assert result.level == MaturityLevel.READY

    @pytest.mark.asyncio
    async def test_thirteen_days_returns_ready(self):
        result = await _run(13)
        assert result.level == MaturityLevel.READY

    @pytest.mark.asyncio
    async def test_fourteen_days_returns_strong(self):
        result = await _run(14)
        assert result.level == MaturityLevel.STRONG

    @pytest.mark.asyncio
    async def test_twenty_nine_days_returns_strong(self):
        result = await _run(29)
        assert result.level == MaturityLevel.STRONG

    @pytest.mark.asyncio
    async def test_thirty_days_returns_excellent(self):
        result = await _run(30)
        assert result.level == MaturityLevel.EXCELLENT

    @pytest.mark.asyncio
    async def test_fifty_days_returns_excellent(self):
        result = await _run(50)
        assert result.level == MaturityLevel.EXCELLENT


# ---------------------------------------------------------------------------
# Feature thresholds
# ---------------------------------------------------------------------------


class TestFeatureThresholds:
    def test_health_score_unlocked_at_7_days(self):
        svc = DataMaturityService()
        assert svc.get_feature_available("health_score_full", 7) is True
        assert svc.get_feature_available("health_score_full", 6) is False

    def test_anomaly_detection_unlocked_at_14_days(self):
        svc = DataMaturityService()
        assert svc.get_feature_available("anomaly_detection", 14) is True
        assert svc.get_feature_available("anomaly_detection", 13) is False

    def test_correlations_unlocked_at_7_days(self):
        svc = DataMaturityService()
        assert svc.get_feature_available("correlations", 7) is True

    def test_weekly_report_unlocked_at_7_days(self):
        svc = DataMaturityService()
        assert svc.get_feature_available("weekly_report", 7) is True

    def test_trend_analysis_unlocked_at_14_days(self):
        svc = DataMaturityService()
        assert svc.get_feature_available("trend_analysis", 14) is True
        assert svc.get_feature_available("trend_analysis", 13) is False

    def test_advanced_insights_unlocked_at_30_days(self):
        svc = DataMaturityService()
        assert svc.get_feature_available("advanced_insights", 30) is True
        assert svc.get_feature_available("advanced_insights", 29) is False

    def test_unknown_feature_returns_true(self):
        """Unknown features fail open (don't block users)."""
        svc = DataMaturityService()
        assert svc.get_feature_available("nonexistent_feature", 0) is True


# ---------------------------------------------------------------------------
# Features unlocked/locked in result
# ---------------------------------------------------------------------------


class TestFeaturesInResult:
    @pytest.mark.asyncio
    async def test_building_level_has_features_locked(self):
        result = await _run(3)
        assert "health_score_full" in result.features_locked
        assert "advanced_insights" in result.features_locked

    @pytest.mark.asyncio
    async def test_ready_level_unlocks_weekly_report(self):
        result = await _run(7)
        assert "weekly_report" in result.features_unlocked
        assert "advanced_insights" in result.features_locked

    @pytest.mark.asyncio
    async def test_excellent_level_unlocks_all_features(self):
        result = await _run(30)
        assert result.features_locked == []
        assert "advanced_insights" in result.features_unlocked


# ---------------------------------------------------------------------------
# Progress percentage
# ---------------------------------------------------------------------------


class TestProgressPercentage:
    @pytest.mark.asyncio
    async def test_progress_at_level_start_is_zero(self):
        """First day of READY level → 0% toward STRONG."""
        result = await _run(7)
        assert result.percentage == 0.0

    @pytest.mark.asyncio
    async def test_progress_halfway_through_level(self):
        """Midpoint of READY (7–14) → ~50%."""
        # Midpoint is day 10 (7 + (14-7)/2 ≈ 10.5)
        result = await _run(10)
        assert 40.0 < result.percentage < 60.0

    @pytest.mark.asyncio
    async def test_excellent_level_percentage_is_100(self):
        result = await _run(30)
        assert result.percentage == 100.0

    @pytest.mark.asyncio
    async def test_progress_does_not_exceed_100(self):
        result = await _run(100)
        assert result.percentage <= 100.0


# ---------------------------------------------------------------------------
# Next milestone days
# ---------------------------------------------------------------------------


class TestNextMilestoneDays:
    @pytest.mark.asyncio
    async def test_building_next_milestone(self):
        """3 days → needs 4 more to reach READY (7)."""
        result = await _run(3)
        assert result.next_milestone_days == 4

    @pytest.mark.asyncio
    async def test_excellent_next_milestone_is_zero(self):
        result = await _run(30)
        assert result.next_milestone_days == 0

    @pytest.mark.asyncio
    async def test_days_with_data_field_matches_input(self):
        result = await _run(15)
        assert result.days_with_data == 15
