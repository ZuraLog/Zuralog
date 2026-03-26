"""Tests for InsightSignalDetector — all 8 signal categories."""

from __future__ import annotations

from datetime import datetime, timezone, timedelta, date

import pytest

from app.analytics.health_brief_builder import (
    HealthBrief,
    DailyMetricsRow,
    SleepRow,
    ActivityRow,
    NutritionRow,
    WeightRow,
    QuickLogRow,
    GoalRow,
    StreakRow,
    IntegrationStatus,
    UserPreferencesSnapshot,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_NOW = datetime(2026, 3, 18, 12, 0, 0, tzinfo=timezone.utc)
_TODAY = _NOW.date().isoformat()


def _brief(
    *,
    daily_metrics: list[DailyMetricsRow] | None = None,
    sleep_records: list[SleepRow] | None = None,
    activities: list[ActivityRow] | None = None,
    nutrition: list[NutritionRow] | None = None,
    weight: list[WeightRow] | None = None,
    quick_logs: list[QuickLogRow] | None = None,
    goals: list[GoalRow] | None = None,
    streaks: list[StreakRow] | None = None,
    integrations: list[IntegrationStatus] | None = None,
    preferences: UserPreferencesSnapshot | None = None,
    data_maturity_days: int = 30,
    estimated_tdee: float | None = None,
) -> HealthBrief:
    return HealthBrief(
        user_id="u1",
        generated_at=_NOW,
        daily_metrics=daily_metrics or [],
        sleep_records=sleep_records or [],
        activities=activities or [],
        nutrition=nutrition or [],
        weight=weight or [],
        quick_logs=quick_logs or [],
        goals=goals or [],
        streaks=streaks or [],
        integrations=integrations or [],
        preferences=preferences or UserPreferencesSnapshot(),
        data_maturity_days=data_maturity_days,
        estimated_tdee=estimated_tdee,
    )


def _daily_rows(values: list[float | None], attr: str = "steps") -> list[DailyMetricsRow]:
    """Build DailyMetricsRow list with one attr set, oldest first."""
    rows = []
    for i, v in enumerate(values):
        d = (date(2026, 1, 1) + timedelta(days=i)).isoformat()
        kwargs = {"date": d, attr: v}
        rows.append(DailyMetricsRow(**kwargs))
    return rows


def _sleep_rows(hours_list: list[float | None]) -> list[SleepRow]:
    rows = []
    for i, h in enumerate(hours_list):
        d = (date(2026, 1, 1) + timedelta(days=i)).isoformat()
        rows.append(SleepRow(date=d, hours=h, quality_score=None))
    return rows


# ---------------------------------------------------------------------------
# Category A — Single-metric trends
# ---------------------------------------------------------------------------


def test_cat_a_trend_decline_fires():
    """14 values with a clear downward shift must emit trend_decline."""
    from app.analytics.insight_signal_detector import InsightSignalDetector

    # First 7 high, next 7 much lower → clear decline
    values = [10000.0] * 7 + [6000.0] * 7
    rows = _daily_rows(values, "steps")
    # Push the last row date to today so it's included in category C too
    rows[-1] = DailyMetricsRow(date=_TODAY, steps=values[-1])

    brief = _brief(daily_metrics=rows)
    detector = InsightSignalDetector(brief)
    signals = detector.detect_all()

    decline = [s for s in signals if s.signal_type == "trend_decline" and "steps" in s.metrics]
    assert len(decline) >= 1
    assert decline[0].category == "A"
    assert decline[0].severity >= 2


def test_cat_a_trend_decline_does_not_fire_insufficient_data():
    """Fewer than 14 data points must not emit a trend signal."""
    from app.analytics.insight_signal_detector import InsightSignalDetector

    values = [10000.0] * 5 + [5000.0] * 5  # only 10 points
    rows = _daily_rows(values, "steps")
    brief = _brief(daily_metrics=rows)
    detector = InsightSignalDetector(brief)
    signals = detector.detect_all()

    decline = [s for s in signals if s.signal_type == "trend_decline" and "steps" in s.metrics]
    assert len(decline) == 0


def test_cat_a_inverted_rhr_up_is_decline():
    """Rising resting_heart_rate must emit trend_decline (inverted metric)."""
    from app.analytics.insight_signal_detector import InsightSignalDetector

    # Previous 7 days RHR=58, recent 7 days RHR=72 (rising = bad)
    values = [58.0] * 7 + [72.0] * 7
    rows = [
        DailyMetricsRow(
            date=(date(2026, 1, 1) + timedelta(days=i)).isoformat(),
            resting_heart_rate=v,
        )
        for i, v in enumerate(values)
    ]
    brief = _brief(daily_metrics=rows)
    detector = InsightSignalDetector(brief)
    signals = detector.detect_all()

    declines = [s for s in signals if s.signal_type == "trend_decline" and "resting_heart_rate" in s.metrics]
    assert len(declines) >= 1


# ---------------------------------------------------------------------------
# Category B — Goal progress
# ---------------------------------------------------------------------------


def test_cat_b_goal_near_miss_fires():
    """current=8200, target=10000 (82%) must emit goal_near_miss."""
    from app.analytics.insight_signal_detector import InsightSignalDetector

    goal = GoalRow(id="g1", metric="steps", target_value=10000, period="daily", current_value=8200, is_active=True)
    brief = _brief(goals=[goal])
    signals = InsightSignalDetector(brief).detect_all()

    near_miss = [s for s in signals if s.signal_type == "goal_near_miss" and "steps" in s.metrics]
    assert len(near_miss) == 1
    assert near_miss[0].category == "B"


def test_cat_b_goal_near_miss_no_fire_below_80():
    """current=5000, target=10000 (50%) must NOT emit goal_near_miss."""
    from app.analytics.insight_signal_detector import InsightSignalDetector

    goal = GoalRow(id="g1", metric="steps", target_value=10000, period="daily", current_value=5000, is_active=True)
    brief = _brief(goals=[goal])
    signals = InsightSignalDetector(brief).detect_all()

    near_miss = [s for s in signals if s.signal_type == "goal_near_miss" and "steps" in s.metrics]
    assert len(near_miss) == 0


def test_cat_b_goal_met_fires():
    """current=11000, target=10000 must emit goal_met_today."""
    from app.analytics.insight_signal_detector import InsightSignalDetector

    goal = GoalRow(id="g1", metric="steps", target_value=10000, period="daily", current_value=11000, is_active=True)
    brief = _brief(goals=[goal])
    signals = InsightSignalDetector(brief).detect_all()

    met = [s for s in signals if s.signal_type == "goal_met_today" and "steps" in s.metrics]
    assert len(met) == 1


def test_cat_b_inactive_goal_ignored():
    """Inactive goals must not produce any signals."""
    from app.analytics.insight_signal_detector import InsightSignalDetector

    goal = GoalRow(id="g1", metric="steps", target_value=10000, period="daily", current_value=11000, is_active=False)
    brief = _brief(goals=[goal])
    signals = InsightSignalDetector(brief).detect_all()

    b_signals = [s for s in signals if s.category == "B"]
    assert len(b_signals) == 0


# ---------------------------------------------------------------------------
# Category C — Anomaly detection
# ---------------------------------------------------------------------------


def _anomaly_daily_rows(baseline_val: float, today_val: float, metric: str) -> list[DailyMetricsRow]:
    """Build 20 rows with uniform baseline + anomalous today value."""
    rows = []
    for i in range(19):
        d = (date(2026, 2, 26) + timedelta(days=i)).isoformat()
        rows.append(DailyMetricsRow(date=d, **{metric: baseline_val}))
    rows.append(DailyMetricsRow(date=_TODAY, **{metric: today_val}))
    return rows


def test_cat_c_anomaly_fires_elevated_rhr():
    """RHR spike way above baseline (>3 stddev) must emit anomaly severity 5."""
    from app.analytics.insight_signal_detector import InsightSignalDetector

    rows = _anomaly_daily_rows(baseline_val=63.0, today_val=90.0, metric="resting_heart_rate")
    brief = _brief(daily_metrics=rows)
    signals = InsightSignalDetector(brief).detect_all()

    anomalies = [s for s in signals if s.signal_type == "anomaly" and "resting_heart_rate" in s.metrics]
    assert len(anomalies) >= 1
    assert anomalies[0].category == "C"
    assert anomalies[0].severity == 5


def test_cat_c_no_anomaly_uniform_values():
    """All-same values must not produce an anomaly (zero stddev shortcircuit)."""
    from app.analytics.insight_signal_detector import InsightSignalDetector

    rows = _anomaly_daily_rows(baseline_val=63.0, today_val=63.0, metric="resting_heart_rate")
    brief = _brief(daily_metrics=rows)
    signals = InsightSignalDetector(brief).detect_all()

    anomalies = [s for s in signals if s.signal_type == "anomaly" and "resting_heart_rate" in s.metrics]
    assert len(anomalies) == 0


def test_cat_c_anomaly_elevated_fires_severity_3():
    """RHR mildly above baseline (2-3 stddev) must emit anomaly severity 3."""
    from app.analytics.insight_signal_detector import InsightSignalDetector

    # Build a uniform set with std dev ~3 and today slightly above 2*stddev
    baseline = [63.0] * 19
    rows = []
    for i, v in enumerate(baseline):
        d = (date(2026, 2, 26) + timedelta(days=i)).isoformat()
        rows.append(DailyMetricsRow(date=d, resting_heart_rate=v))
    # Today: 63 + small variance to create a defined stddev scenario
    # Instead, build a more realistic baseline with small variance
    rows2 = []
    for i in range(19):
        d = (date(2026, 2, 26) + timedelta(days=i)).isoformat()
        rows2.append(DailyMetricsRow(date=d, resting_heart_rate=63.0 + (i % 3) * 0.5))
    # stddev ≈ 0.5, today = 63 + 2.5 * 0.5 = 64.25 → ~2.5 stddev → severity 3
    rows2.append(DailyMetricsRow(date=_TODAY, resting_heart_rate=64.5))
    brief = _brief(daily_metrics=rows2)
    signals = InsightSignalDetector(brief).detect_all()

    anomalies = [s for s in signals if s.signal_type == "anomaly" and "resting_heart_rate" in s.metrics]
    # severity 3 (2-3 stddev away)
    assert any(a.severity == 3 for a in anomalies)


# ---------------------------------------------------------------------------
# Category D — Correlations
# ---------------------------------------------------------------------------


def _make_correlation_brief(n: int = 20, strong: bool = True) -> HealthBrief:
    """Build a brief with correlated sleep → next-day steps data."""
    sleep_rows = []
    daily_rows = []
    base = date(2026, 1, 1)
    for i in range(n):
        d = (base + timedelta(days=i)).isoformat()
        sleep_hours = 7.0 + (i % 3) * 0.5  # varies 7.0–8.0
        steps = (10000 + (i % 3) * 2000) if strong else 10000.0
        sleep_rows.append(SleepRow(date=d, hours=sleep_hours))
        daily_rows.append(DailyMetricsRow(date=d, steps=float(steps)))
    return _brief(sleep_records=sleep_rows, daily_metrics=daily_rows)


def test_cat_d_correlation_fires_strong_sleep_steps():
    """Strong sleep → next-day steps pattern must emit a correlation_discovery signal."""
    from app.analytics.insight_signal_detector import InsightSignalDetector

    # Build a perfectly correlated sleep → steps series
    base = date(2026, 1, 1)
    sleep_rows = []
    daily_rows = []
    for i in range(20):
        d = (base + timedelta(days=i)).isoformat()
        sleep_hours = 6.0 + i * 0.1  # monotone increase
        sleep_rows.append(SleepRow(date=d, hours=sleep_hours))
        # Next day steps perfectly correlated: higher sleep → more steps
        next_d = (base + timedelta(days=i + 1)).isoformat()
        steps = 8000.0 + i * 200.0
        daily_rows.append(DailyMetricsRow(date=next_d, steps=steps))
    # Add one extra day for the last sleep entry's lag
    brief = _brief(sleep_records=sleep_rows, daily_metrics=daily_rows)
    signals = InsightSignalDetector(brief).detect_all()

    corr = [
        s
        for s in signals
        if s.signal_type == "correlation_discovery" and "sleep_hours" in s.metrics and "steps" in s.metrics
    ]
    assert len(corr) >= 1


def test_cat_d_correlation_no_fire_insufficient_data():
    """Fewer than 14 aligned pairs must not emit correlation signals."""
    from app.analytics.insight_signal_detector import InsightSignalDetector

    # Only 5 days of data
    base = date(2026, 1, 1)
    sleep_rows = [SleepRow(date=(base + timedelta(days=i)).isoformat(), hours=7.0) for i in range(5)]
    daily_rows = [DailyMetricsRow(date=(base + timedelta(days=i)).isoformat(), steps=10000.0) for i in range(5)]
    brief = _brief(sleep_records=sleep_rows, daily_metrics=daily_rows)
    signals = InsightSignalDetector(brief).detect_all()

    corr = [s for s in signals if s.signal_type == "correlation_discovery"]
    assert len(corr) == 0


def test_detect_correlations_returns_only_category_d():
    """detect_correlations() must return only correlation_discovery signals, not other types."""
    from app.analytics.insight_signal_detector import InsightSignalDetector

    # Build a brief with strong sleep/steps correlation AND an anomaly to ensure non-D signals exist
    base = date(2026, 1, 1)
    sleep_rows = []
    daily_rows = []
    for i in range(20):
        d = (base + timedelta(days=i)).isoformat()
        sleep_hours = 6.0 + i * 0.1
        sleep_rows.append(SleepRow(date=d, hours=sleep_hours))
        next_d = (base + timedelta(days=i + 1)).isoformat()
        daily_rows.append(DailyMetricsRow(date=next_d, steps=8000.0 + i * 200.0))
    brief = _brief(sleep_records=sleep_rows, daily_metrics=daily_rows)

    InsightSignalDetector(brief).detect_all()
    corr_only = InsightSignalDetector(brief).detect_correlations()

    # Every signal returned by detect_correlations must be a correlation_discovery
    assert all(s.signal_type == "correlation_discovery" for s in corr_only)
    # detect_correlations must not be empty when strong correlations exist
    assert len(corr_only) >= 1


def test_detect_correlations_empty_on_no_data():
    """detect_correlations() must return an empty list when the brief has no data."""
    from app.analytics.insight_signal_detector import InsightSignalDetector

    brief = _brief()
    signals = InsightSignalDetector(brief).detect_correlations()
    assert signals == []


# ---------------------------------------------------------------------------
# Category E — Compound patterns
# ---------------------------------------------------------------------------


def test_cat_e_overtraining_risk_fires():
    """6 consecutive workout days + declining HRV must emit compound_overtraining_risk."""
    from app.analytics.insight_signal_detector import InsightSignalDetector

    base = date(2026, 3, 11)
    # 6 consecutive workout days ending today
    activities = [
        ActivityRow(
            date=(base + timedelta(days=i)).isoformat(),
            activity_type="run",
            duration_seconds=3600.0,
        )
        for i in range(6)
    ]
    # HRV declining: previous 7 days higher, recent 7 days lower
    daily_rows = []
    for i in range(14):
        d = (date(2026, 3, 4) + timedelta(days=i)).isoformat()
        hrv = 60.0 if i < 7 else 45.0  # clear decline
        rhr = 58.0 if i < 7 else 65.0  # rising rhr
        daily_rows.append(DailyMetricsRow(date=d, hrv_ms=hrv, resting_heart_rate=rhr))

    brief = _brief(activities=activities, daily_metrics=daily_rows)
    signals = InsightSignalDetector(brief).detect_all()

    overtraining = [s for s in signals if s.signal_type == "compound_overtraining_risk"]
    assert len(overtraining) >= 1
    assert overtraining[0].category == "E"
    assert overtraining[0].severity == 4


def test_cat_e_sleep_debt_fires():
    """Average sleep < 6.5h for 7 days with 3+ nights below 6h must emit compound_sleep_debt."""
    from app.analytics.insight_signal_detector import InsightSignalDetector

    base = date(2026, 3, 11)
    sleep_rows = [SleepRow(date=(base + timedelta(days=i)).isoformat(), hours=5.5) for i in range(7)]
    brief = _brief(sleep_records=sleep_rows)
    signals = InsightSignalDetector(brief).detect_all()

    sleep_debt = [s for s in signals if s.signal_type == "compound_sleep_debt"]
    assert len(sleep_debt) >= 1
    assert sleep_debt[0].category == "E"
    assert sleep_debt[0].severity == 3


def test_cat_e_sleep_debt_fires_at_exactly_3_nights():
    """Exactly 3 nights below 6h should trigger the sleep debt signal."""
    from app.analytics.insight_signal_detector import InsightSignalDetector

    brief = _brief()
    today = date.today()
    sleep = []
    for i in range(7):
        d = (today - timedelta(days=i)).isoformat()
        hours = 5.5 if i < 3 else 7.0  # exactly 3 nights under 6h
        sleep.append(SleepRow(date=d, hours=hours))
    brief.sleep_records = sleep
    detector = InsightSignalDetector(brief)
    signals = [s for s in detector.detect_all() if s.signal_type == "compound_sleep_debt"]
    assert len(signals) == 1


def test_cat_e_no_overtraining_without_declining_hrv():
    """6 consecutive workouts with healthy stable HRV must NOT emit overtraining signal."""
    from app.analytics.insight_signal_detector import InsightSignalDetector

    base = date(2026, 3, 11)
    activities = [
        ActivityRow(
            date=(base + timedelta(days=i)).isoformat(),
            activity_type="run",
            duration_seconds=3600.0,
        )
        for i in range(6)
    ]
    # Stable HRV (no decline)
    daily_rows = [
        DailyMetricsRow(
            date=(date(2026, 3, 4) + timedelta(days=i)).isoformat(),
            hrv_ms=60.0,
            resting_heart_rate=58.0,
        )
        for i in range(14)
    ]
    brief = _brief(activities=activities, daily_metrics=daily_rows)
    signals = InsightSignalDetector(brief).detect_all()

    overtraining = [s for s in signals if s.signal_type == "compound_overtraining_risk"]
    assert len(overtraining) == 0


# ---------------------------------------------------------------------------
# Category G — Streaks
# ---------------------------------------------------------------------------


def test_cat_g_streak_at_risk_fires():
    """Streak of 15 with last activity yesterday must emit streak_at_risk."""
    from app.analytics.insight_signal_detector import InsightSignalDetector

    yesterday = (date(2026, 3, 17)).isoformat()
    streak = StreakRow(
        streak_type="steps",
        current_count=15,
        longest_count=15,
        last_activity_date=yesterday,
    )
    brief = _brief(streaks=[streak])
    signals = InsightSignalDetector(brief).detect_all()

    at_risk = [s for s in signals if s.signal_type == "streak_at_risk" and "steps" in s.metrics]
    assert len(at_risk) == 1
    assert at_risk[0].category == "G"
    assert at_risk[0].severity == 4


def test_cat_g_streak_milestone_fires():
    """Streak of 7 with last activity today must emit streak_milestone."""
    from app.analytics.insight_signal_detector import InsightSignalDetector

    streak = StreakRow(
        streak_type="steps",
        current_count=7,
        longest_count=7,
        last_activity_date=_TODAY,
    )
    brief = _brief(streaks=[streak])
    signals = InsightSignalDetector(brief).detect_all()

    milestone = [s for s in signals if s.signal_type == "streak_milestone" and "steps" in s.metrics]
    assert len(milestone) == 1
    assert milestone[0].category == "G"


def test_cat_g_no_milestone_for_non_milestone_count():
    """Streak of 8 (not a milestone) must NOT emit streak_milestone."""
    from app.analytics.insight_signal_detector import InsightSignalDetector

    streak = StreakRow(
        streak_type="steps",
        current_count=8,
        longest_count=8,
        last_activity_date=_TODAY,
    )
    brief = _brief(streaks=[streak])
    signals = InsightSignalDetector(brief).detect_all()

    milestone = [s for s in signals if s.signal_type == "streak_milestone" and "steps" in s.metrics]
    assert len(milestone) == 0


def test_cat_g_milestone_tomorrow_fires():
    """Streak of 6, active today, must emit streak_milestone_tomorrow (7-day)."""
    from app.analytics.insight_signal_detector import InsightSignalDetector

    streak = StreakRow(
        streak_type="steps",
        current_count=6,
        longest_count=6,
        last_activity_date=_TODAY,
    )
    brief = _brief(streaks=[streak])
    signals = InsightSignalDetector(brief).detect_all()

    tomorrow = [s for s in signals if s.signal_type == "streak_milestone_tomorrow" and "steps" in s.metrics]
    assert len(tomorrow) == 1
    assert tomorrow[0].values["next_milestone"] == 7


# ---------------------------------------------------------------------------
# Category H — Data quality
# ---------------------------------------------------------------------------


def test_cat_h_stale_integration_fires():
    """An integration not synced in 25 hours must emit integration_stale."""
    from app.analytics.insight_signal_detector import InsightSignalDetector

    stale_time = datetime.now(timezone.utc) - timedelta(hours=25)
    integration = IntegrationStatus(provider="fitbit", is_active=True, last_synced_at=stale_time)
    brief = _brief(integrations=[integration])
    signals = InsightSignalDetector(brief).detect_all()

    stale = [s for s in signals if s.signal_type == "integration_stale"]
    assert len(stale) == 1
    assert stale[0].category == "H"
    assert "fitbit" in stale[0].values["stale_providers"]


def test_cat_h_fresh_integration_no_fire():
    """An integration synced 1 hour ago must NOT emit integration_stale."""
    from app.analytics.insight_signal_detector import InsightSignalDetector

    fresh_time = datetime.now(timezone.utc) - timedelta(hours=1)
    integration = IntegrationStatus(provider="fitbit", is_active=True, last_synced_at=fresh_time)
    brief = _brief(integrations=[integration])
    signals = InsightSignalDetector(brief).detect_all()

    stale = [s for s in signals if s.signal_type == "integration_stale"]
    assert len(stale) == 0


def test_cat_h_first_week_fires():
    """data_maturity_days=3 must emit first_week signal."""
    from app.analytics.insight_signal_detector import InsightSignalDetector

    brief = _brief(data_maturity_days=3)
    signals = InsightSignalDetector(brief).detect_all()

    first_week = [s for s in signals if s.signal_type == "first_week"]
    assert len(first_week) == 1
    assert first_week[0].category == "H"


def test_cat_h_no_first_week_after_7_days():
    """data_maturity_days=10 must NOT emit first_week."""
    from app.analytics.insight_signal_detector import InsightSignalDetector

    brief = _brief(data_maturity_days=10)
    signals = InsightSignalDetector(brief).detect_all()

    first_week = [s for s in signals if s.signal_type == "first_week"]
    assert len(first_week) == 0


def test_cat_h_missing_sleep_data_fires():
    """3+ consecutive days without sleep records must emit data_quality signal."""
    from app.analytics.insight_signal_detector import InsightSignalDetector

    # Only provide sleep from 10 days ago — today and recent days are missing
    old_sleep = [SleepRow(date=(date(2026, 3, 7) + timedelta(days=i)).isoformat(), hours=7.5) for i in range(5)]
    brief = _brief(sleep_records=old_sleep)
    signals = InsightSignalDetector(brief).detect_all()

    quality = [s for s in signals if s.signal_type == "data_quality" and "sleep" in s.metrics]
    assert len(quality) >= 1


# ---------------------------------------------------------------------------
# Focus boost
# ---------------------------------------------------------------------------


def test_focus_boost_increases_severity():
    """A signal for a metric in the user's focus list must have +1 severity."""
    from app.analytics.insight_signal_detector import InsightSignalDetector

    # steps is in focus_metrics for the "fitness" goal
    prefs = UserPreferencesSnapshot(goals=["fitness"])
    goal = GoalRow(id="g1", metric="steps", target_value=10000, period="daily", current_value=8200, is_active=True)
    brief = _brief(goals=[goal], preferences=prefs)
    signals = InsightSignalDetector(brief).detect_all()

    near_miss = [s for s in signals if s.signal_type == "goal_near_miss" and "steps" in s.metrics]
    assert len(near_miss) >= 1
    # Without focus: severity=4; with focus boost it should be 5 (capped)
    assert near_miss[0].severity == 5
    assert near_miss[0].focus_relevant is True


def test_cat_b_goal_deadline_approaching_fires():
    """Deadline 3 days out with 30% progress must emit goal_deadline_approaching."""
    from app.analytics.insight_signal_detector import InsightSignalDetector
    from datetime import timedelta

    deadline = (date.today() + timedelta(days=3)).isoformat()
    goal = GoalRow(
        id="g1",
        metric="steps",
        target_value=100000.0,
        period="monthly",
        current_value=30000.0,
        deadline=deadline,
        is_active=True,
    )
    brief = _brief(goals=[goal], data_maturity_days=20)
    signals = InsightSignalDetector(brief).detect_all()
    types = [s.signal_type for s in signals]
    assert "goal_deadline_approaching" in types


def test_cat_b_goal_completed_fires_when_deadline_passed_and_met():
    """Deadline yesterday + goal met must emit goal_completed."""
    from app.analytics.insight_signal_detector import InsightSignalDetector
    from datetime import timedelta

    deadline = (date.today() - timedelta(days=1)).isoformat()  # yesterday
    goal = GoalRow(
        id="g1",
        metric="steps",
        target_value=100000.0,
        period="monthly",
        current_value=105000.0,
        deadline=deadline,
        is_active=True,
    )
    brief = _brief(goals=[goal], data_maturity_days=30)
    signals = InsightSignalDetector(brief).detect_all()
    types = [s.signal_type for s in signals]
    assert "goal_completed" in types


def test_cat_b_goal_behind_pace_fires():
    """Weekly goal at ~14% progress after more than half the period must emit goal_behind_pace."""
    from app.analytics.insight_signal_detector import InsightSignalDetector

    goal = GoalRow(
        id="g1", metric="steps", target_value=70000.0, period="weekly", current_value=10000.0, is_active=True
    )
    brief = _brief(goals=[goal], data_maturity_days=10)  # more than 7//2 days
    signals = InsightSignalDetector(brief).detect_all()
    types = [s.signal_type for s in signals]
    # Should fire either goal_at_risk or goal_behind_pace
    assert any(t in types for t in ("goal_at_risk", "goal_behind_pace"))


def test_focus_boost_does_not_exceed_5():
    """Focus boost on an already-severity-5 signal must not push above 5."""
    from app.analytics.insight_signal_detector import InsightSignalDetector

    # steps is a focus metric; create an anomaly which starts at severity 5
    prefs = UserPreferencesSnapshot(goals=["fitness"])
    rows = _anomaly_daily_rows(baseline_val=10000.0, today_val=3000.0, metric="steps")
    brief = _brief(daily_metrics=rows, preferences=prefs)
    signals = InsightSignalDetector(brief).detect_all()

    anomalies = [s for s in signals if s.signal_type == "anomaly" and "steps" in s.metrics]
    if anomalies:
        assert anomalies[0].severity <= 5
