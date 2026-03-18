"""Tests for HealthBriefBuilder and related dataclasses."""

import pytest
from unittest.mock import AsyncMock, patch
from datetime import date, timedelta, datetime, timezone


@pytest.mark.asyncio
async def test_health_brief_builder_returns_correct_user_id():
    from app.analytics.health_brief_builder import HealthBriefBuilder

    builder = HealthBriefBuilder(user_id="user-1", db=AsyncMock())
    with patch.multiple(
        builder,
        _fetch_daily_metrics=AsyncMock(return_value=[]),
        _fetch_sleep_records=AsyncMock(return_value=[]),
        _fetch_activities=AsyncMock(return_value=[]),
        _fetch_nutrition=AsyncMock(return_value=[]),
        _fetch_weight=AsyncMock(return_value=[]),
        _fetch_quick_logs=AsyncMock(return_value=[]),
        _fetch_goals=AsyncMock(return_value=[]),
        _fetch_streaks=AsyncMock(return_value=[]),
        _fetch_preferences=AsyncMock(return_value=None),
        _fetch_integrations=AsyncMock(return_value=[]),
    ):
        brief = await builder.build()
    assert brief.user_id == "user-1"
    assert brief.daily_metrics == []


def test_integration_status_stale_when_synced_25h_ago():
    from app.analytics.health_brief_builder import IntegrationStatus

    stale_time = datetime.now(timezone.utc) - timedelta(hours=25)
    integration = IntegrationStatus(provider="fitbit", is_active=True, last_synced_at=stale_time)
    assert integration.is_stale is True


def test_integration_status_not_stale_when_synced_1h_ago():
    from app.analytics.health_brief_builder import IntegrationStatus

    fresh_time = datetime.now(timezone.utc) - timedelta(hours=1)
    integration = IntegrationStatus(provider="fitbit", is_active=True, last_synced_at=fresh_time)
    assert integration.is_stale is False


def test_integration_status_stale_when_never_synced():
    from app.analytics.health_brief_builder import IntegrationStatus

    integration = IntegrationStatus(provider="strava", is_active=True, last_synced_at=None)
    assert integration.is_stale is True


def test_tdee_computed_for_80kg_sedentary():
    from app.analytics.health_brief_builder import HealthBriefBuilder

    tdee = HealthBriefBuilder._compute_tdee(
        weight_kg=80.0,
        avg_active_calories=150.0,
        height_cm=170.0,
    )
    assert tdee is not None
    assert 1800 < tdee < 2500


def test_tdee_returns_none_when_no_weight():
    from app.analytics.health_brief_builder import HealthBriefBuilder

    tdee = HealthBriefBuilder._compute_tdee(weight_kg=None, avg_active_calories=300.0)
    assert tdee is None


def test_tdee_higher_multiplier_for_very_active():
    from app.analytics.health_brief_builder import HealthBriefBuilder

    sedentary = HealthBriefBuilder._compute_tdee(weight_kg=75.0, avg_active_calories=100.0)
    very_active = HealthBriefBuilder._compute_tdee(weight_kg=75.0, avg_active_calories=700.0)
    assert very_active > sedentary


def test_dedup_by_source_prefers_oura_over_fitbit():
    from app.analytics.health_brief_builder import DailyMetricsRow, _dedup_by_source

    today = date.today().isoformat()
    rows = [
        DailyMetricsRow(date=today, steps=8000.0, source="fitbit"),
        DailyMetricsRow(date=today, steps=9000.0, source="oura"),
    ]
    result = _dedup_by_source(rows)
    assert len(result) == 1
    assert result[0].source == "oura"
    assert result[0].steps == 9000.0


def test_dedup_by_source_preserves_multiple_dates():
    from app.analytics.health_brief_builder import DailyMetricsRow, _dedup_by_source

    rows = [
        DailyMetricsRow(date="2026-03-17", steps=8000.0, source="fitbit"),
        DailyMetricsRow(date="2026-03-18", steps=9000.0, source="fitbit"),
    ]
    result = _dedup_by_source(rows)
    assert len(result) == 2
