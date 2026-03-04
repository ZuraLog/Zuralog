"""
Zuralog Cloud Brain — Tests for AnomalyDetector.

Validates the statistical anomaly detection logic, including severity
classification, minimum-data-point gating, multi-metric independence,
and sleep-duration detection.

All database interactions are mocked via AsyncMock — no real DB required.
"""

from __future__ import annotations

import math
from datetime import date, timedelta
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.anomaly_detector import (
    AnomalyDetector,
    AnomalyResult,
    AnomalySeverity,
    _MIN_DATA_POINTS,
    _classify_severity,
    _mean,
    _std,
)


# ---------------------------------------------------------------------------
# Helper factories
# ---------------------------------------------------------------------------


def _make_metric_row(
    metric_date: str,
    steps: float | None = None,
    active_calories: float | None = None,
    resting_heart_rate: float | None = None,
    hrv_ms: float | None = None,
    vo2_max: float | None = None,
    body_fat_percentage: float | None = None,
    respiratory_rate: float | None = None,
    oxygen_saturation: float | None = None,
) -> MagicMock:
    """Build a minimal DailyHealthMetrics-like mock row.

    Args:
        metric_date: ISO date string (YYYY-MM-DD).
        steps: Steps value or None.
        active_calories: Active calories or None.
        resting_heart_rate: RHR or None.
        hrv_ms: HRV ms or None.
        vo2_max: VO2 max or None.
        body_fat_percentage: Body fat % or None.
        respiratory_rate: Respiratory rate or None.
        oxygen_saturation: SpO2 % or None.

    Returns:
        MagicMock with attribute access mirroring the ORM model.
    """
    row = MagicMock()
    row.date = metric_date
    row.steps = steps
    row.active_calories = active_calories
    row.resting_heart_rate = resting_heart_rate
    row.hrv_ms = hrv_ms
    row.vo2_max = vo2_max
    row.body_fat_percentage = body_fat_percentage
    row.respiratory_rate = respiratory_rate
    row.oxygen_saturation = oxygen_saturation
    return row


def _make_sleep_row(sleep_date: str, hours: float) -> MagicMock:
    """Build a minimal SleepRecord-like mock row.

    Args:
        sleep_date: ISO date string.
        hours: Sleep duration in hours.

    Returns:
        MagicMock with date and hours attributes.
    """
    row = MagicMock()
    row.date = sleep_date
    row.hours = hours
    return row


def _build_session_mock(
    daily_rows: list[MagicMock],
    sleep_rows: list[MagicMock] | None = None,
) -> AsyncMock:
    """Create an AsyncMock session that returns pre-canned rows.

    The first ``session.execute()`` call returns daily_rows via
    ``scalars().all()``.  If sleep_rows are provided, the second call
    returns those; otherwise returns an empty list.

    Args:
        daily_rows: Rows to return for the daily_health_metrics query.
        sleep_rows: Rows to return for the sleep_records query (optional).

    Returns:
        AsyncMock configured to simulate AsyncSession.execute().
    """
    session = AsyncMock()
    sleep_rows = sleep_rows or []

    def _make_result(rows: list) -> MagicMock:
        result = MagicMock()
        scalars_mock = MagicMock()
        scalars_mock.all.return_value = rows
        result.scalars.return_value = scalars_mock
        return result

    # execute() is called twice: once for daily metrics, once for sleep
    session.execute.side_effect = [
        _make_result(daily_rows),
        _make_result(sleep_rows),
    ]
    return session


# ---------------------------------------------------------------------------
# Unit tests for pure helper functions
# ---------------------------------------------------------------------------


class TestStatisticsHelpers:
    """Unit tests for _mean, _std, and _classify_severity."""

    def test_mean_single_value(self) -> None:
        """Mean of a single-element list returns that value."""
        assert _mean([42.0]) == pytest.approx(42.0)

    def test_mean_multiple_values(self) -> None:
        """Mean is computed correctly for a multi-element list."""
        assert _mean([2.0, 4.0, 6.0]) == pytest.approx(4.0)

    def test_std_single_value_returns_zero(self) -> None:
        """Std of a single-element list returns 0.0 (no variance)."""
        assert _std([10.0], mean=10.0) == pytest.approx(0.0)

    def test_std_uniform_list_returns_zero(self) -> None:
        """Std of a uniform list is zero."""
        values = [5.0] * 10
        assert _std(values, mean=5.0) == pytest.approx(0.0)

    def test_std_known_values(self) -> None:
        """Std of [2, 4, 4, 4, 5, 5, 7, 9] is 2.0 (population)."""
        values = [2.0, 4.0, 4.0, 4.0, 5.0, 5.0, 7.0, 9.0]
        m = _mean(values)
        assert _std(values, mean=m) == pytest.approx(2.0)

    def test_classify_below_elevated_is_normal(self) -> None:
        """Deviation < 2.0 → NORMAL."""
        assert _classify_severity(1.99) == AnomalySeverity.NORMAL

    def test_classify_elevated_lower_bound(self) -> None:
        """Deviation == 2.0 → ELEVATED."""
        assert _classify_severity(2.0) == AnomalySeverity.ELEVATED

    def test_classify_elevated_upper_bound(self) -> None:
        """Deviation 2.49 → ELEVATED (just below CRITICAL)."""
        assert _classify_severity(2.49) == AnomalySeverity.ELEVATED

    def test_classify_critical_lower_bound(self) -> None:
        """Deviation == 2.5 → CRITICAL."""
        assert _classify_severity(2.5) == AnomalySeverity.CRITICAL

    def test_classify_critical_high(self) -> None:
        """High deviation → CRITICAL."""
        assert _classify_severity(5.0) == AnomalySeverity.CRITICAL


# ---------------------------------------------------------------------------
# AnomalyDetector integration-style tests
# ---------------------------------------------------------------------------


class TestAnomalyDetector:
    """Tests for AnomalyDetector.check_for_anomalies."""

    def _today(self) -> str:
        return date.today().isoformat()

    def _days_ago(self, n: int) -> str:
        return (date.today() - timedelta(days=n)).isoformat()

    def _build_baseline_rows(
        self,
        metric: str,
        mean: float,
        std: float,
        n: int,
        start_offset: int = 1,
    ) -> list[MagicMock]:
        """Generate n rows with values drawn from a deterministic baseline.

        Alternates values above/below the mean by exactly ``std`` to produce
        a dataset whose actual std converges on ``std``.

        Args:
            metric: Which column to populate.
            mean: Target mean value.
            std: Target standard deviation.
            n: Number of rows to generate.
            start_offset: Day offset from today for the oldest row.

        Returns:
            List of mock rows with the given metric values.
        """
        rows = []
        for i in range(n):
            # Alternate ±std around the mean
            value = mean + std * (1 if i % 2 == 0 else -1)
            day = self._days_ago(start_offset + i)
            rows.append(_make_metric_row(day, steps=value if metric == "steps" else None))
        return rows

    # ------------------------------------------------------------------
    # No anomaly
    # ------------------------------------------------------------------

    @pytest.mark.asyncio
    async def test_no_anomaly_within_one_std(self) -> None:
        """Value within 1 std dev of baseline → empty result list."""
        mean_val = 8000.0
        std_val = 500.0

        # 20 baseline rows at exactly ±std around mean
        baseline = []
        for i in range(20):
            value = mean_val + std_val * (1 if i % 2 == 0 else -1)
            baseline.append(_make_metric_row(self._days_ago(i + 1), steps=value))

        # Today: mean + 0.8 std → well within normal range
        today_value = mean_val + 0.8 * std_val
        today_row = _make_metric_row(self._today(), steps=today_value)

        session = _build_session_mock(baseline + [today_row])
        detector = AnomalyDetector()
        results = await detector.check_for_anomalies("user-001", session)

        assert results == []

    # ------------------------------------------------------------------
    # Elevated anomaly
    # ------------------------------------------------------------------

    @pytest.mark.asyncio
    async def test_elevated_anomaly_2_3_std(self) -> None:
        """Value 2.3 std devs from baseline → AnomalySeverity.ELEVATED."""
        mean_val = 8000.0
        std_val = 1000.0

        baseline = []
        for i in range(20):
            value = mean_val + std_val * (1 if i % 2 == 0 else -1)
            baseline.append(_make_metric_row(self._days_ago(i + 1), steps=value))

        # Today: mean + 2.3 std
        today_value = mean_val + 2.3 * std_val
        today_row = _make_metric_row(self._today(), steps=today_value)

        session = _build_session_mock(baseline + [today_row])
        detector = AnomalyDetector()
        results = await detector.check_for_anomalies("user-001", session)

        steps_results = [r for r in results if r.metric_name == "steps"]
        assert len(steps_results) == 1
        assert steps_results[0].severity == AnomalySeverity.ELEVATED
        assert steps_results[0].current_value == pytest.approx(today_value)

    # ------------------------------------------------------------------
    # Critical anomaly
    # ------------------------------------------------------------------

    @pytest.mark.asyncio
    async def test_critical_anomaly_3_1_std(self) -> None:
        """Value 3.1 std devs from baseline → AnomalySeverity.CRITICAL."""
        mean_val = 8000.0
        std_val = 1000.0

        baseline = []
        for i in range(20):
            value = mean_val + std_val * (1 if i % 2 == 0 else -1)
            baseline.append(_make_metric_row(self._days_ago(i + 1), steps=value))

        # Today: mean + 3.1 std
        today_value = mean_val + 3.1 * std_val
        today_row = _make_metric_row(self._today(), steps=today_value)

        session = _build_session_mock(baseline + [today_row])
        detector = AnomalyDetector()
        results = await detector.check_for_anomalies("user-001", session)

        steps_results = [r for r in results if r.metric_name == "steps"]
        assert len(steps_results) == 1
        assert steps_results[0].severity == AnomalySeverity.CRITICAL
        assert steps_results[0].deviation_magnitude >= 3.0

    # ------------------------------------------------------------------
    # Insufficient data
    # ------------------------------------------------------------------

    @pytest.mark.asyncio
    async def test_insufficient_data_below_14_points(self) -> None:
        """Fewer than 14 data points → anomaly check skipped, empty results."""
        # Only 10 rows total (9 baseline + today)
        baseline = []
        for i in range(9):
            baseline.append(_make_metric_row(self._days_ago(i + 1), steps=8000.0))

        today_row = _make_metric_row(self._today(), steps=99999.0)  # extreme value

        session = _build_session_mock(baseline + [today_row])
        detector = AnomalyDetector()
        results = await detector.check_for_anomalies("user-001", session)

        assert results == []

    @pytest.mark.asyncio
    async def test_exactly_14_points_activates_check(self) -> None:
        """Exactly 14 data points meets the threshold and activates detection."""
        mean_val = 8000.0
        std_val = 400.0

        # 13 baseline rows + today = 14 total
        baseline = []
        for i in range(13):
            value = mean_val + std_val * (1 if i % 2 == 0 else -1)
            baseline.append(_make_metric_row(self._days_ago(i + 1), steps=value))

        # Today: 3 std devs → should trigger CRITICAL
        today_value = mean_val + 3.0 * std_val
        today_row = _make_metric_row(self._today(), steps=today_value)

        session = _build_session_mock(baseline + [today_row])
        detector = AnomalyDetector()
        results = await detector.check_for_anomalies("user-001", session)

        steps_results = [r for r in results if r.metric_name == "steps"]
        assert len(steps_results) == 1
        assert steps_results[0].severity == AnomalySeverity.CRITICAL

    # ------------------------------------------------------------------
    # Multiple metrics are checked independently
    # ------------------------------------------------------------------

    @pytest.mark.asyncio
    async def test_multiple_metrics_checked_independently(self) -> None:
        """Each metric is evaluated independently — anomaly in one does not affect others."""
        mean_steps = 8000.0
        std_steps = 500.0
        mean_hrv = 55.0
        std_hrv = 5.0

        rows = []
        for i in range(20):
            steps_val = mean_steps + std_steps * (1 if i % 2 == 0 else -1)
            hrv_val = mean_hrv + std_hrv * (1 if i % 2 == 0 else -1)
            row = MagicMock()
            row.date = self._days_ago(i + 1)
            row.steps = steps_val
            row.active_calories = None
            row.resting_heart_rate = None
            row.hrv_ms = hrv_val
            row.vo2_max = None
            row.body_fat_percentage = None
            row.respiratory_rate = None
            row.oxygen_saturation = None
            rows.append(row)

        # Today: steps normal, hrv critical
        today = MagicMock()
        today.date = self._today()
        today.steps = mean_steps + 0.5 * std_steps  # normal
        today.active_calories = None
        today.resting_heart_rate = None
        today.hrv_ms = mean_hrv + 3.0 * std_hrv  # critical
        today.vo2_max = None
        today.body_fat_percentage = None
        today.respiratory_rate = None
        today.oxygen_saturation = None
        rows.append(today)

        session = _build_session_mock(rows)
        detector = AnomalyDetector()
        results = await detector.check_for_anomalies("user-001", session)

        metric_names = {r.metric_name for r in results}
        assert "hrv_ms" in metric_names
        assert "steps" not in metric_names

    # ------------------------------------------------------------------
    # AnomalyResult structure
    # ------------------------------------------------------------------

    @pytest.mark.asyncio
    async def test_anomaly_result_fields_populated(self) -> None:
        """AnomalyResult has all required fields populated correctly."""
        mean_val = 8000.0
        std_val = 1000.0

        baseline = []
        for i in range(20):
            value = mean_val + std_val * (1 if i % 2 == 0 else -1)
            baseline.append(_make_metric_row(self._days_ago(i + 1), steps=value))

        today_value = mean_val + 3.0 * std_val
        today_row = _make_metric_row(self._today(), steps=today_value)

        session = _build_session_mock(baseline + [today_row])
        detector = AnomalyDetector()
        results = await detector.check_for_anomalies("user-001", session)

        steps_results = [r for r in results if r.metric_name == "steps"]
        assert len(steps_results) == 1
        r = steps_results[0]

        assert isinstance(r, AnomalyResult)
        assert r.metric_name == "steps"
        assert r.current_value == pytest.approx(today_value)
        assert r.baseline_mean > 0
        assert r.baseline_std > 0
        assert r.deviation_magnitude > 0
        assert r.severity in (AnomalySeverity.ELEVATED, AnomalySeverity.CRITICAL)
        assert r.detected_at is not None

    # ------------------------------------------------------------------
    # No today's data
    # ------------------------------------------------------------------

    @pytest.mark.asyncio
    async def test_no_todays_data_returns_empty(self) -> None:
        """If no row exists for today, no anomaly is reported."""
        baseline = []
        for i in range(20):
            baseline.append(_make_metric_row(self._days_ago(i + 1), steps=8000.0))
        # No today row

        session = _build_session_mock(baseline)
        detector = AnomalyDetector()
        results = await detector.check_for_anomalies("user-001", session)

        assert results == []


# ---------------------------------------------------------------------------
# store_anomaly_insights tests
# ---------------------------------------------------------------------------


class TestStoreAnomalyInsights:
    """Tests for AnomalyDetector.store_anomaly_insights."""

    @pytest.mark.asyncio
    async def test_empty_anomalies_does_nothing(self) -> None:
        """Passing an empty anomaly list performs no DB writes."""
        session = AsyncMock()
        detector = AnomalyDetector()
        await detector.store_anomaly_insights("user-001", [], session)
        session.add.assert_not_called()
        session.commit.assert_not_called()

    @pytest.mark.asyncio
    async def test_stores_insight_rows_for_anomalies(self) -> None:
        """store_anomaly_insights adds one row per anomaly and commits."""
        session = AsyncMock()
        anomalies = [
            AnomalyResult(
                metric_name="steps",
                current_value=15000.0,
                baseline_mean=8000.0,
                baseline_std=500.0,
                deviation_magnitude=3.0,
                severity=AnomalySeverity.CRITICAL,
            ),
            AnomalyResult(
                metric_name="hrv_ms",
                current_value=20.0,
                baseline_mean=55.0,
                baseline_std=5.0,
                deviation_magnitude=2.1,
                severity=AnomalySeverity.ELEVATED,
            ),
        ]

        detector = AnomalyDetector()
        await detector.store_anomaly_insights("user-001", anomalies, session)

        # Two rows should have been added and session committed once
        assert session.add.call_count == 2
        session.commit.assert_called_once()

    @pytest.mark.asyncio
    async def test_insight_row_type_is_anomaly_alert(self) -> None:
        """Stored Insight rows use the 'anomaly_alert' type string."""
        session = AsyncMock()
        anomaly = AnomalyResult(
            metric_name="steps",
            current_value=15000.0,
            baseline_mean=8000.0,
            baseline_std=500.0,
            deviation_magnitude=3.0,
            severity=AnomalySeverity.CRITICAL,
        )

        detector = AnomalyDetector()
        await detector.store_anomaly_insights("user-001", [anomaly], session)

        added_row = session.add.call_args[0][0]
        assert added_row.type == "anomaly_alert"
        assert added_row.user_id == "user-001"
        # Critical anomaly should get priority 2
        assert added_row.priority == 2

    @pytest.mark.asyncio
    async def test_elevated_anomaly_gets_lower_priority(self) -> None:
        """ELEVATED anomalies are stored with priority 3 (less urgent than CRITICAL)."""
        session = AsyncMock()
        anomaly = AnomalyResult(
            metric_name="hrv_ms",
            current_value=40.0,
            baseline_mean=60.0,
            baseline_std=5.0,
            deviation_magnitude=2.1,
            severity=AnomalySeverity.ELEVATED,
        )

        detector = AnomalyDetector()
        await detector.store_anomaly_insights("user-001", [anomaly], session)

        added_row = session.add.call_args[0][0]
        assert added_row.priority == 3
