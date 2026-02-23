"""
Zuralog Cloud Brain — Correlation Analyzer.

Finds statistical relationships between different health metrics
(e.g., "Does better sleep lead to higher activity the next day?").
Uses numpy for Pearson correlation with support for lag analysis.
"""

import logging
from typing import Any

import numpy as np

logger = logging.getLogger(__name__)


class CorrelationAnalyzer:
    """Computes correlations between health metric time series.

    All methods are pure functions. Data must be pre-fetched by the caller.
    Requires at least 5 overlapping data points for meaningful results.
    """

    MIN_DATA_POINTS = 5

    def calculate_correlation(
        self,
        metric_x: list[float],
        metric_y: list[float],
    ) -> dict[str, Any]:
        """Calculate Pearson correlation between two metric series.

        Args:
            metric_x: First metric values (e.g., sleep hours per day).
            metric_y: Second metric values (e.g., activity calories per day).

        Returns:
            Dict with 'score' (-1.0 to 1.0) and 'message' describing
            the correlation strength. Returns score=0.0 if insufficient data.
        """
        if len(metric_x) != len(metric_y) or len(metric_x) < self.MIN_DATA_POINTS:
            return {"score": 0.0, "message": "Not enough data for correlation analysis."}

        try:
            score = float(np.corrcoef(metric_x, metric_y)[0, 1])
        except (ValueError, FloatingPointError):
            return {"score": 0.0, "message": "Unable to compute correlation."}

        if np.isnan(score):
            return {"score": 0.0, "message": "No variance in data — correlation undefined."}

        message = self._classify_correlation(score)
        return {"score": round(score, 4), "message": message}

    def analyze_sleep_impact_on_activity(
        self,
        sleep_data: list[dict[str, Any]],
        activity_data: list[dict[str, Any]],
        lag: int = 0,
    ) -> dict[str, Any]:
        """Analyze correlation between sleep and activity with optional lag.

        Aligns data by date, optionally shifting activity data by ``lag`` days
        (e.g., lag=1 compares Sleep on Day N with Activity on Day N+1).

        Args:
            sleep_data: List of dicts with 'date' (str) and 'hours' (float).
            activity_data: List of dicts with 'date' (str) and 'calories' (int/float).
            lag: Number of days to shift activity data forward. Default 0.

        Returns:
            Dict with 'score', 'message', 'lag', and 'data_points' count.
        """
        sleep_by_date: dict[str, float] = {s["date"]: s.get("hours", 0) for s in sleep_data}
        activity_by_date: dict[str, float] = {a["date"]: a.get("calories", 0) for a in activity_data}

        if lag == 0:
            common_dates = sorted(set(sleep_by_date.keys()) & set(activity_by_date.keys()))
            sleep_vals = [sleep_by_date[d] for d in common_dates]
            activity_vals = [activity_by_date[d] for d in common_dates]
        else:
            from datetime import date as date_type
            from datetime import timedelta

            paired_sleep: list[float] = []
            paired_activity: list[float] = []
            for date_str in sorted(sleep_by_date.keys()):
                shifted_date = (date_type.fromisoformat(date_str) + timedelta(days=lag)).isoformat()
                if shifted_date in activity_by_date:
                    paired_sleep.append(sleep_by_date[date_str])
                    paired_activity.append(activity_by_date[shifted_date])
            sleep_vals = paired_sleep
            activity_vals = paired_activity

        result = self.calculate_correlation(sleep_vals, activity_vals)
        result["lag"] = lag
        result["data_points"] = min(len(sleep_vals), len(activity_vals))
        return result

    @staticmethod
    def _classify_correlation(score: float) -> str:
        """Classify a Pearson correlation coefficient into a human-readable label.

        Args:
            score: Correlation coefficient (-1.0 to 1.0).

        Returns:
            Human-readable description of correlation strength.
        """
        abs_score = abs(score)
        if abs_score > 0.7:
            strength = "Strong"
        elif abs_score > 0.4:
            strength = "Moderate"
        else:
            return "No meaningful correlation detected."

        direction = "Positive" if score > 0 else "Negative"
        return f"{strength} {direction} Correlation"
