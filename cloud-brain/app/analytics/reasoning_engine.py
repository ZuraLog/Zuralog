"""
Life Logger Cloud Brain — Cross-App Reasoning Engine.

Provides deterministic analytical helpers that synthesize data from
multiple MCP sources (Apple Health, Strava, CalAI) into higher-order
insights. These helpers can be called by the Orchestrator proactively
or registered as MCP tools.

The engine performs the *calculation* — the LLM provides the *narration*.
"""

import logging
import statistics
from typing import Any

logger = logging.getLogger(__name__)


class ReasoningEngine:
    """Analyzes cross-app data to generate higher-order insights.

    All methods are pure functions operating on provided data.
    No database or API calls — data must be pre-fetched by the caller.
    """

    def analyze_deficit(
        self,
        nutrition_calories: int,
        active_burn: int,
        bmr: int = 1800,
    ) -> dict[str, Any]:
        """Calculate caloric deficit or surplus.

        Computes net calories as intake minus total expenditure
        (BMR + active burn) and classifies the result.

        Args:
            nutrition_calories: Total calories consumed (from CalAI/Health).
            active_burn: Calories burned through exercise (from Strava/Health).
            bmr: Basal metabolic rate estimate. Defaults to 1800.

        Returns:
            A dict with keys: net_calories, status ('deficit'/'surplus'),
            magnitude (absolute value), and recommendation string.
        """
        total_out = bmr + active_burn
        net = nutrition_calories - total_out
        status = "deficit" if net < 0 else "surplus"
        magnitude = abs(net)

        if net < -500:
            recommendation = (
                "You're under-eating significantly. Eat more to sustain "
                "your activity level and avoid metabolic slowdown."
            )
        elif net < -200:
            recommendation = "You're in a healthy deficit. Keep it up for steady, sustainable fat loss."
        elif net <= 200:
            recommendation = (
                "You're roughly at maintenance. If your goal is weight loss, "
                "consider a moderate 300-500 cal/day deficit."
            )
        else:
            recommendation = (
                f"You're in a {magnitude} cal surplus. If weight loss is the goal, "
                "reduce portion sizes or increase activity."
            )

        return {
            "net_calories": net,
            "status": status,
            "magnitude": magnitude,
            "recommendation": recommendation,
        }

    def correlate_sleep_and_activity(
        self,
        sleep_data: list[dict[str, Any]],
        activity_data: list[dict[str, Any]],
    ) -> str:
        """Analyze correlation between sleep quality and activity levels.

        Aligns data by date and computes a simple Pearson correlation
        between sleep hours and activity calories burned.

        Args:
            sleep_data: List of dicts with 'date' and 'hours' keys.
            activity_data: List of dicts with 'date' and 'calories_burned' keys.

        Returns:
            A human-readable summary of the correlation finding.
        """
        if not sleep_data or not activity_data:
            return "Not enough data yet. Keep tracking sleep and activity for meaningful correlations."

        # Build lookup by date
        sleep_by_date = {s["date"]: s.get("hours", 0) for s in sleep_data}
        activity_by_date = {a["date"]: a.get("calories_burned", 0) for a in activity_data}

        # Find overlapping dates
        common_dates = sorted(set(sleep_by_date.keys()) & set(activity_by_date.keys()))

        if len(common_dates) < 3:
            return "Not enough overlapping data points. Keep tracking for at least a week."

        sleep_vals = [sleep_by_date[d] for d in common_dates]
        activity_vals = [activity_by_date[d] for d in common_dates]

        # Simple Pearson-like correlation
        try:
            correlation = statistics.correlation(sleep_vals, activity_vals)
        except (statistics.StatisticsError, ZeroDivisionError):
            return "Unable to compute correlation — not enough variance in the data."

        if correlation > 0.5:
            return (
                f"Moderate positive correlation ({correlation:.2f}): You tend to sleep "
                "more on days you're more active. Exercise seems to help your sleep!"
            )
        elif correlation < -0.5:
            return (
                f"Moderate negative correlation ({correlation:.2f}): You sleep less on "
                "high-activity days. Consider earlier workout times."
            )
        else:
            return (
                f"Weak correlation ({correlation:.2f}): No strong pattern between "
                "sleep and activity yet. Keep tracking!"
            )

    def analyze_activity_trend(
        self,
        this_month: list[dict[str, Any]],
        last_month: list[dict[str, Any]],
    ) -> dict[str, Any]:
        """Compare activity frequency between current and previous month.

        Args:
            this_month: List of activity dicts for the current month.
            last_month: List of activity dicts for the previous month.

        Returns:
            A dict with trend ('improving'/'declining'/'stable'),
            counts, and percentage change.
        """
        this_count = len(this_month)
        last_count = len(last_month)

        if last_count == 0:
            pct_change = 100.0 if this_count > 0 else 0.0
        else:
            pct_change = ((this_count - last_count) / last_count) * 100

        if pct_change > 10:
            trend = "improving"
        elif pct_change < -10:
            trend = "declining"
        else:
            trend = "stable"

        return {
            "trend": trend,
            "this_month_count": this_count,
            "last_month_count": last_count,
            "percent_change": round(pct_change, 1),
        }
