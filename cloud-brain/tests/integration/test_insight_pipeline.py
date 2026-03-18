"""
Zuralog Cloud Brain — Integration Tests for the AI Insights Pipeline.

Tests the 5-step pipeline end-to-end using mocked DB sessions and mocked
LLM calls. No real database or network calls are made.

Covered scenarios:
- Full pipeline produces cards and returns status "ok".
- Date-lock prevents a second run for the same day.
- Immature accounts (< 7 days of data) get a welcome card, no LLM call.
- fan_out_daily_insights enqueues tasks only for users whose local time is 6 AM.
"""

import pytest
from datetime import date, datetime, timezone, timedelta
from unittest.mock import AsyncMock, MagicMock, patch


# ---------------------------------------------------------------------------
# test_pipeline_produces_cards_and_returns_ok
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_pipeline_produces_cards_and_returns_ok():
    """Full pipeline: mock brief with 30 days data → cards written → status ok."""
    from app.tasks.insight_tasks import _run_pipeline_async
    from app.analytics.health_brief_builder import (
        HealthBrief,
        DailyMetricsRow,
        SleepRow,
        UserPreferencesSnapshot,
        IntegrationStatus,
    )

    # Build a brief with enough data to pass the maturity check (30 days)
    today = date.today()
    daily = [
        DailyMetricsRow(
            date=(today - timedelta(days=i)).isoformat(),
            steps=8000.0 if i >= 7 else 5000.0,  # declining trend to trigger a signal
            resting_heart_rate=65.0,
            hrv_ms=40.0,
            active_calories=300.0,
        )
        for i in range(30)
    ]
    sleep = [SleepRow(date=(today - timedelta(days=i)).isoformat(), hours=7.5) for i in range(30)]

    brief = HealthBrief(
        user_id="test-user-1",
        generated_at=datetime.now(timezone.utc),
        daily_metrics=list(reversed(daily)),  # oldest first
        sleep_records=list(reversed(sleep)),
        activities=[],
        nutrition=[],
        weight=[],
        quick_logs=[],
        goals=[],
        streaks=[],
        integrations=[],
        preferences=UserPreferencesSnapshot(goals=["fitness"]),
        data_maturity_days=30,
    )

    # Mock the DB session — date-lock returns 0 (no existing cards today)
    mock_db = AsyncMock()
    mock_db.execute = AsyncMock()
    mock_scalar = MagicMock()
    mock_scalar.scalar_one.return_value = 0
    mock_db.execute.return_value = mock_scalar
    mock_db.commit = AsyncMock()

    # Mock the LLM to return a valid JSON card list
    llm_card_json = (
        '[{"type":"trend_decline","title":"Steps dropping",'
        '"body":"Your steps fell 37%.","priority":3,"reasoning":"Detected trend."}]'
    )
    mock_llm_response = MagicMock()
    mock_llm_response.choices = [MagicMock(message=MagicMock(content=llm_card_json))]

    with (
        patch("app.tasks.insight_tasks.HealthBriefBuilder") as MockBuilder,
        patch("app.analytics.insight_card_writer.LLMClient") as MockLLM,
    ):
        MockBuilder.return_value.build = AsyncMock(return_value=brief)
        MockLLM.return_value.chat = AsyncMock(return_value=mock_llm_response)

        result = await _run_pipeline_async(user_id="test-user-1", db=mock_db)

    assert result["status"] == "ok"
    assert result["insights_written"] >= 1


# ---------------------------------------------------------------------------
# test_date_lock_prevents_second_run
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_date_lock_prevents_second_run():
    """Date-lock: if today's cards already exist, return skipped_date_lock immediately."""
    from app.tasks.insight_tasks import _run_pipeline_async

    mock_db = AsyncMock()
    mock_scalar = MagicMock()
    mock_scalar.scalar_one.return_value = 3  # 3 cards already exist for today
    mock_db.execute.return_value = mock_scalar

    result = await _run_pipeline_async(user_id="test-user-1", db=mock_db)

    assert result["status"] == "skipped_date_lock"
    assert result["insights_written"] == 0


# ---------------------------------------------------------------------------
# test_immature_account_gets_welcome_card
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_immature_account_gets_welcome_card():
    """Users with fewer than 7 days of data get a welcome card — no LLM call made."""
    from app.tasks.insight_tasks import _run_pipeline_async
    from app.analytics.health_brief_builder import (
        HealthBrief,
        UserPreferencesSnapshot,
    )

    brief = HealthBrief(
        user_id="test-user-2",
        generated_at=datetime.now(timezone.utc),
        daily_metrics=[],
        sleep_records=[],
        activities=[],
        nutrition=[],
        weight=[],
        quick_logs=[],
        goals=[],
        streaks=[],
        integrations=[],
        preferences=UserPreferencesSnapshot(),
        data_maturity_days=3,  # below MIN_DATA_DAYS_FOR_MATURITY (7)
    )

    mock_db = AsyncMock()
    mock_scalar = MagicMock()
    mock_scalar.scalar_one.return_value = 0
    mock_db.execute.return_value = mock_scalar
    mock_db.commit = AsyncMock()

    with patch("app.tasks.insight_tasks.HealthBriefBuilder") as MockBuilder:
        MockBuilder.return_value.build = AsyncMock(return_value=brief)
        result = await _run_pipeline_async(user_id="test-user-2", db=mock_db)

    assert result["status"] == "ok"
    assert result["insights_written"] == 1


# ---------------------------------------------------------------------------
# test_fan_out_enqueues_users_at_6am
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_fan_out_enqueues_users_at_6am():
    """fan_out_daily_insights only enqueues tasks for users whose local time is 6 AM.

    User 1: UTC timezone, 6 AM UTC  → should be enqueued.
    User 2: Asia/Karachi (UTC+5), so local time is 11 AM → should NOT be enqueued.
    """
    from app.tasks.insight_tasks import _fan_out_async

    # 6:00 AM UTC on a fixed date
    test_utc_now = datetime(2026, 3, 18, 6, 0, 0, tzinfo=timezone.utc)

    mock_rows = [("user-utc", "UTC"), ("user-karachi", "Asia/Karachi")]

    mock_db = AsyncMock()
    mock_result = MagicMock()
    mock_result.all.return_value = mock_rows
    mock_db.execute.return_value = mock_result

    enqueued_users: list[str] = []

    with (
        patch("app.tasks.insight_tasks.async_session") as mock_session_ctx,
        patch("app.tasks.insight_tasks.datetime") as mock_datetime,
        patch("app.tasks.insight_tasks.generate_insights_for_user") as mock_task,
    ):
        mock_session_ctx.return_value.__aenter__ = AsyncMock(return_value=mock_db)
        mock_session_ctx.return_value.__aexit__ = AsyncMock(return_value=None)
        # Patch datetime.now so the fan-out sees our fixed UTC time
        mock_datetime.now.return_value = test_utc_now
        mock_task.delay = MagicMock(side_effect=lambda uid: enqueued_users.append(uid))

        result = await _fan_out_async()

    assert "user-utc" in enqueued_users
    assert "user-karachi" not in enqueued_users
    assert result["enqueued"] == 1
