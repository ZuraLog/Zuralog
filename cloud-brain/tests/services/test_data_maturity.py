"""
Tests for DataMaturityService.

The service returns a plain dict from get_maturity() with keys:
    - days (int)
    - level (str: "building" | "ready" | "strong" | "excellent")
    - label (str)
    - features (dict[str, bool])

Tests cover:
- 3 days → "building" level
- 7 days → "ready" level
- 14 days → "strong" level
- 30 days → "excellent" level
- Feature gates respected (via get_feature_gates directly)
- Return shape is always correct
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.data_maturity import DataMaturityService


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


async def _run(days: int) -> dict:
    """Run get_maturity with a mocked DB returning a fixed day count."""
    svc = DataMaturityService()
    db = AsyncMock()
    # The service calls db.execute(stmt) then result.scalar_one()
    result_mock = MagicMock()
    result_mock.scalar_one.return_value = days
    db.execute = AsyncMock(return_value=result_mock)
    return await svc.get_maturity("user-001", db)


# ---------------------------------------------------------------------------
# Level tests
# ---------------------------------------------------------------------------


class TestMaturityLevels:
    @pytest.mark.asyncio
    async def test_zero_days_returns_building(self):
        """0 days of data → 'building' level."""
        result = await _run(0)
        assert result["level"] == "building"

    @pytest.mark.asyncio
    async def test_three_days_returns_building(self):
        result = await _run(3)
        assert result["level"] == "building"

    @pytest.mark.asyncio
    async def test_six_days_returns_building(self):
        result = await _run(6)
        assert result["level"] == "building"

    @pytest.mark.asyncio
    async def test_seven_days_returns_ready(self):
        result = await _run(7)
        assert result["level"] == "ready"

    @pytest.mark.asyncio
    async def test_thirteen_days_returns_ready(self):
        result = await _run(13)
        assert result["level"] == "ready"

    @pytest.mark.asyncio
    async def test_fourteen_days_returns_strong(self):
        result = await _run(14)
        assert result["level"] == "strong"

    @pytest.mark.asyncio
    async def test_twenty_nine_days_returns_strong(self):
        result = await _run(29)
        assert result["level"] == "strong"

    @pytest.mark.asyncio
    async def test_thirty_days_returns_excellent(self):
        result = await _run(30)
        assert result["level"] == "excellent"

    @pytest.mark.asyncio
    async def test_fifty_days_returns_excellent(self):
        result = await _run(50)
        assert result["level"] == "excellent"


# ---------------------------------------------------------------------------
# Return shape tests
# ---------------------------------------------------------------------------


class TestReturnShape:
    @pytest.mark.asyncio
    async def test_result_has_required_keys(self):
        """get_maturity always returns the expected dict keys."""
        result = await _run(7)
        assert "days" in result
        assert "level" in result
        assert "label" in result
        assert "features" in result

    @pytest.mark.asyncio
    async def test_days_field_matches_input(self):
        """days field reflects the count returned by the DB query."""
        result = await _run(15)
        assert result["days"] == 15

    @pytest.mark.asyncio
    async def test_label_is_non_empty_string(self):
        """label is a human-readable non-empty string."""
        result = await _run(7)
        assert isinstance(result["label"], str)
        assert len(result["label"]) > 0

    @pytest.mark.asyncio
    async def test_features_is_dict(self):
        """features is a dict of feature gates."""
        result = await _run(7)
        assert isinstance(result["features"], dict)


# ---------------------------------------------------------------------------
# Feature gate tests (via get_feature_gates directly)
# ---------------------------------------------------------------------------


class TestFeatureGates:
    def test_correlations_unlocked_at_7_days(self):
        svc = DataMaturityService()
        gates = svc.get_feature_gates(7)
        assert gates.get("correlations") is True

    def test_correlations_locked_below_7_days(self):
        svc = DataMaturityService()
        gates = svc.get_feature_gates(6)
        assert gates.get("correlations") is False

    def test_anomaly_detection_unlocked_at_14_days(self):
        svc = DataMaturityService()
        gates = svc.get_feature_gates(14)
        assert gates.get("anomaly_detection") is True

    def test_anomaly_detection_locked_below_14_days(self):
        svc = DataMaturityService()
        gates = svc.get_feature_gates(13)
        assert gates.get("anomaly_detection") is False

    def test_key_features_locked_at_0_days(self):
        svc = DataMaturityService()
        gates = svc.get_feature_gates(0)
        # Key features requiring data should be False at zero days
        assert gates.get("correlations") is False
        assert gates.get("anomaly_detection") is False
        assert gates.get("full_insights") is False


# ---------------------------------------------------------------------------
# Classify helper tests
# ---------------------------------------------------------------------------


class TestClassify:
    def test_classify_returns_level_and_label(self):
        svc = DataMaturityService()
        info = svc._classify(7)
        assert "level" in info
        assert "label" in info

    def test_classify_building_level(self):
        svc = DataMaturityService()
        assert svc._classify(3)["level"] == "building"

    def test_classify_excellent_level(self):
        svc = DataMaturityService()
        assert svc._classify(30)["level"] == "excellent"
