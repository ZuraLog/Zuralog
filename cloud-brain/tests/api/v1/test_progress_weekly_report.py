"""Tests for GET /progress/weekly-report.

Verifies:
- Seeded steps + sleep data produces non-empty cards with correct category names.
- Empty summaries returns empty cards list.
- Cards contain expected metric labels and values.
"""

from __future__ import annotations

from datetime import date, timedelta
from unittest.mock import AsyncMock, MagicMock

import pytest


TEST_USER_ID = "weekly-report-test-user-001"


def _make_summary_mock(metric_type: str, value: float, summary_date: date) -> MagicMock:
    """Create a minimal DailySummary mock."""
    s = MagicMock()
    s.metric_type = metric_type
    s.value = value
    s.date = summary_date
    return s


# ---------------------------------------------------------------------------
# Test 1: Empty summaries returns empty cards
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_weekly_report_returns_empty_cards_when_no_data():
    """Returns empty cards list when no daily_summaries exist for the week."""
    from app.api.v1.progress_routes import progress_weekly_report

    mock_db = AsyncMock()
    empty_result = MagicMock()
    empty_result.scalars.return_value.all.return_value = []
    mock_db.execute = AsyncMock(return_value=empty_result)

    mock_request = MagicMock()
    mock_request.headers = {"X-User-Timezone": "UTC"}

    result = await progress_weekly_report(
        request=mock_request,
        user_id=TEST_USER_ID,
        db=mock_db,
    )

    assert result["cards"] == []
    assert result["period_start"] != ""
    assert result["period_end"] != ""


# ---------------------------------------------------------------------------
# Test 2: Steps + sleep data produces Activity and Sleep cards
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_weekly_report_returns_activity_and_sleep_cards():
    """Seeded steps and sleep_hours data produces Activity and Sleep category cards."""
    from app.api.v1.progress_routes import progress_weekly_report

    mock_db = AsyncMock()

    today = date.today()
    summaries = [
        _make_summary_mock("steps", 8000.0, today - timedelta(days=1)),
        _make_summary_mock("steps", 9000.0, today),
        _make_summary_mock("sleep_hours", 7.5, today - timedelta(days=1)),
        _make_summary_mock("sleep_hours", 8.0, today),
    ]

    result_mock = MagicMock()
    result_mock.scalars.return_value.all.return_value = summaries
    mock_db.execute = AsyncMock(return_value=result_mock)

    mock_request = MagicMock()
    mock_request.headers = {"X-User-Timezone": "UTC"}

    result = await progress_weekly_report(
        request=mock_request,
        user_id=TEST_USER_ID,
        db=mock_db,
    )

    assert result["id"] != ""
    assert result["period_start"] != ""
    assert result["period_end"] != ""

    category_names = [c["category"] for c in result["cards"]]
    assert "Activity" in category_names
    assert "Sleep" in category_names


# ---------------------------------------------------------------------------
# Test 3: Metric values are correctly averaged
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_weekly_report_averages_metric_values_correctly():
    """Steps average is (8000 + 9000) / 2 = 8500."""
    from app.api.v1.progress_routes import progress_weekly_report

    mock_db = AsyncMock()

    today = date.today()
    summaries = [
        _make_summary_mock("steps", 8000.0, today - timedelta(days=1)),
        _make_summary_mock("steps", 9000.0, today),
    ]

    result_mock = MagicMock()
    result_mock.scalars.return_value.all.return_value = summaries
    mock_db.execute = AsyncMock(return_value=result_mock)

    mock_request = MagicMock()
    mock_request.headers = {"X-User-Timezone": "UTC"}

    result = await progress_weekly_report(
        request=mock_request,
        user_id=TEST_USER_ID,
        db=mock_db,
    )

    activity_card = next((c for c in result["cards"] if c["category"] == "Activity"), None)
    assert activity_card is not None

    steps_metric = next(
        (m for m in activity_card["metrics"] if m["label"] == "Steps/day"), None
    )
    assert steps_metric is not None
    assert steps_metric["value"] == 8500.0
    assert steps_metric["total"] == 17000.0
    assert steps_metric["days_with_data"] == 2


# ---------------------------------------------------------------------------
# Test 4: Report id contains user_id and monday date
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_weekly_report_id_contains_user_and_week():
    """Report id is formatted as '{user_id}-{monday_date}'."""
    from app.api.v1.progress_routes import progress_weekly_report

    mock_db = AsyncMock()

    today = date.today()
    summaries = [_make_summary_mock("steps", 5000.0, today)]

    result_mock = MagicMock()
    result_mock.scalars.return_value.all.return_value = summaries
    mock_db.execute = AsyncMock(return_value=result_mock)

    mock_request = MagicMock()
    mock_request.headers = {"X-User-Timezone": "UTC"}

    result = await progress_weekly_report(
        request=mock_request,
        user_id=TEST_USER_ID,
        db=mock_db,
    )

    monday = today - timedelta(days=today.weekday())
    expected_id = f"{TEST_USER_ID}-{monday.isoformat()}"
    assert result["id"] == expected_id
