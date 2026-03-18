"""InsightSignalDetector — detects health signals from a HealthBrief.

Converts a fully assembled ``HealthBrief`` (Chunk 3) into a prioritised list
of ``InsightSignal`` objects.  Each signal represents a meaningful health
observation in one of 8 categories:

  A — Single-metric trends (14+ data points, 7-day window comparison)
  B — Goal progress (met / near-miss / at-risk / streak)
  C — Anomaly detection (z-score ≥ 2.0 from 14-day baseline)
  D — Cross-metric correlations (Pearson |r| > 0.4, 14+ paired points)
  E — Compound patterns (overtraining, sleep debt, etc.)
  F — User-focus pre-processing (done in __init__, drives focus boost)
  G — Streak events (at-risk / milestone / milestone-tomorrow)
  H — Data quality (stale integrations, new user, missing sleep)

After detection, every signal goes through ``_apply_focus_boost``:
if any of the signal's metrics are in the user's ``focus_metrics`` list,
severity is raised by 1 (capped at 5) and ``focus_relevant`` is set to True.
"""

from __future__ import annotations

import math
import logging
from dataclasses import dataclass, field, replace
from datetime import date as date_type, timedelta
from typing import Any

from app.analytics.health_brief_builder import HealthBrief
from app.analytics.trend_detector import TrendDetector
from app.analytics.goal_tracker import GoalTracker
from app.analytics.correlation_analyzer import CorrelationAnalyzer
from app.analytics.user_focus_profile import UserFocusProfileBuilder

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# InsightSignal dataclass
# ---------------------------------------------------------------------------


@dataclass
class InsightSignal:
    """A single detected health insight ready for the LLM reasoning layer.

    Attributes:
        signal_type: Machine-readable event type, e.g. ``"trend_decline"``.
        category: Letter code A–H matching the detector category.
        metrics: Which metric keys this signal is about.
        values: Numeric context (pct_change, baseline, current, etc.).
        severity: 1 (lowest) – 5 (most urgent).
        actionable: True if the user can take a clear corrective action.
        focus_relevant: True when any metric is in the user's focus_metrics.
        title_hint: Short human-readable label for the insight title.
        data_payload: Dict passed to the LLM and stored in Insight.data.
    """

    signal_type: str
    category: str
    metrics: list[str]
    values: dict[str, Any]
    severity: int
    actionable: bool
    focus_relevant: bool
    title_hint: str
    data_payload: dict = field(default_factory=dict)


# ---------------------------------------------------------------------------
# Detector
# ---------------------------------------------------------------------------


class InsightSignalDetector:
    """Detects all 8 categories of health signals from a ``HealthBrief``.

    Parameters
    ----------
    brief:
        A fully assembled :class:`~app.analytics.health_brief_builder.HealthBrief`.
    """

    def __init__(self, brief: HealthBrief) -> None:
        self.brief = brief
        self._focus = UserFocusProfileBuilder(
            goals=brief.preferences.goals,
            dashboard_layout=brief.preferences.dashboard_layout,
            coach_persona=brief.preferences.coach_persona,
            fitness_level=brief.preferences.fitness_level,
            units_system=brief.preferences.units_system,
        ).build()

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def detect_all(self) -> list[InsightSignal]:
        """Run all detection categories and return focus-boosted signals."""
        signals: list[InsightSignal] = []
        signals.extend(self._detect_category_a())
        signals.extend(self._detect_category_b())
        signals.extend(self._detect_category_c())
        signals.extend(self._detect_category_d())
        signals.extend(self._detect_category_e())
        # Category F is preprocessing (done in __init__)
        signals.extend(self._detect_category_g())
        signals.extend(self._detect_category_h())
        return [self._apply_focus_boost(s) for s in signals]

    # ------------------------------------------------------------------
    # Focus boost
    # ------------------------------------------------------------------

    def _apply_focus_boost(self, signal: InsightSignal) -> InsightSignal:
        """Boost severity by 1 (max 5) when any metric is a user focus metric."""
        focus_metrics = set(self._focus.focus_metrics)
        is_focus = any(m in focus_metrics for m in signal.metrics)
        if is_focus and signal.severity < 5:
            return replace(signal, severity=signal.severity + 1, focus_relevant=True)
        return replace(signal, focus_relevant=is_focus)

    # ------------------------------------------------------------------
    # Category A — Single-metric trends
    # ------------------------------------------------------------------

    def _detect_category_a(self) -> list[InsightSignal]:
        """Detect improving or declining trends across 15 health metrics."""
        signals: list[InsightSignal] = []
        detector = TrendDetector()

        metric_series: dict[str, list[float]] = {}

        for row in self.brief.daily_metrics:
            for attr in (
                "steps",
                "active_calories",
                "distance_meters",
                "resting_heart_rate",
                "hrv_ms",
                "heart_rate_avg",
                "vo2_max",
                "respiratory_rate",
                "oxygen_saturation",
                "body_fat_percentage",
                "flights_climbed",
            ):
                v = getattr(row, attr, None)
                if v is not None:
                    metric_series.setdefault(attr, []).append(v)

        for row in self.brief.sleep_records:
            if row.hours is not None:
                metric_series.setdefault("sleep_hours", []).append(row.hours)
            if row.quality_score is not None:
                metric_series.setdefault("sleep_quality", []).append(row.quality_score)

        for row in self.brief.weight:
            if row.weight_kg is not None:
                metric_series.setdefault("weight_kg", []).append(row.weight_kg)

        for row in self.brief.nutrition:
            if row.calories is not None:
                metric_series.setdefault("calorie_intake", []).append(row.calories)

        # Metrics where "up" is bad (higher value = worse)
        inverted_metrics = {"resting_heart_rate", "body_fat_percentage"}

        for metric, values in metric_series.items():
            if len(values) < 14:
                continue
            result = detector.detect_trend(values)
            if result["trend"] == "insufficient_data":
                continue

            direction = result["trend"]
            pct = abs(result.get("percent_change", 0))

            # For inverted metrics, swap up/down for severity classification
            is_bad_direction = (direction == "down" and metric not in inverted_metrics) or (
                direction == "up" and metric in inverted_metrics
            )

            if is_bad_direction:
                if pct > 30:
                    severity = 4
                elif pct > 15:
                    severity = 3
                else:
                    severity = 2
                signals.append(
                    InsightSignal(
                        signal_type="trend_decline",
                        category="A",
                        metrics=[metric],
                        values={
                            "recent_avg": result["recent_avg"],
                            "previous_avg": result["previous_avg"],
                            "pct_change": -pct,
                        },
                        severity=severity,
                        actionable=True,
                        focus_relevant=False,
                        title_hint=f"{metric.replace('_', ' ').title()} declining",
                        data_payload={
                            "metric": metric,
                            "recent_avg": result["recent_avg"],
                            "pct_change": -pct,
                        },
                    )
                )
            elif (direction == "up" and metric not in inverted_metrics) or (
                direction == "down" and metric in inverted_metrics
            ):
                signals.append(
                    InsightSignal(
                        signal_type="trend_improvement",
                        category="A",
                        metrics=[metric],
                        values={
                            "recent_avg": result["recent_avg"],
                            "previous_avg": result["previous_avg"],
                            "pct_change": pct,
                        },
                        severity=2,
                        actionable=False,
                        focus_relevant=False,
                        title_hint=f"{metric.replace('_', ' ').title()} improving",
                        data_payload={
                            "metric": metric,
                            "recent_avg": result["recent_avg"],
                            "pct_change": pct,
                        },
                    )
                )

        return signals

    # ------------------------------------------------------------------
    # Category B — Goal progress
    # ------------------------------------------------------------------

    def _detect_category_b(self) -> list[InsightSignal]:
        """Detect goal met, near-miss, at-risk, and streak signals."""
        signals: list[InsightSignal] = []
        tracker = GoalTracker()

        for goal in self.brief.goals:
            if not goal.is_active or goal.target_value <= 0:
                continue
            current = goal.current_value or 0.0
            progress = tracker.check_progress(
                metric=goal.metric,
                current_value=current,
                target_value=goal.target_value,
                period=goal.period,
            )
            pct = progress["progress_pct"]

            if progress["is_met"]:
                signals.append(
                    InsightSignal(
                        signal_type="goal_met_today",
                        category="B",
                        metrics=[goal.metric],
                        values={
                            "current": current,
                            "target": goal.target_value,
                            "progress_pct": pct,
                        },
                        severity=3,
                        actionable=False,
                        focus_relevant=False,
                        title_hint=f"{goal.metric} goal hit",
                        data_payload={
                            "metric": goal.metric,
                            "current": current,
                            "target": goal.target_value,
                        },
                    )
                )
            elif pct >= 80:
                signals.append(
                    InsightSignal(
                        signal_type="goal_near_miss",
                        category="B",
                        metrics=[goal.metric],
                        values={
                            "current": current,
                            "target": goal.target_value,
                            "progress_pct": pct,
                            "remaining": progress["remaining"],
                        },
                        severity=4,
                        actionable=True,
                        focus_relevant=False,
                        title_hint=f"Almost at {goal.metric} goal",
                        data_payload={
                            "metric": goal.metric,
                            "current": current,
                            "remaining": progress["remaining"],
                        },
                    )
                )
            elif pct < 20:
                signals.append(
                    InsightSignal(
                        signal_type="goal_at_risk",
                        category="B",
                        metrics=[goal.metric],
                        values={
                            "current": current,
                            "target": goal.target_value,
                            "progress_pct": pct,
                        },
                        severity=4,
                        actionable=True,
                        focus_relevant=False,
                        title_hint=f"{goal.metric} goal at risk",
                        data_payload={
                            "metric": goal.metric,
                            "current": current,
                            "target": goal.target_value,
                            "progress_pct": pct,
                        },
                    )
                )
            # Goal behind pace: 20–79% progress AND behind schedule
            # Only applies to weekly/monthly goals with time context
            elif 20 <= pct < 80 and goal.period in ("weekly", "monthly", "custom"):
                # For weekly: 7 days in period, for monthly: 30 days
                period_days = 7 if goal.period == "weekly" else 30
                # If the user has been tracking for more than half the period and is < 50% done
                if pct < 50 and self.brief.data_maturity_days > period_days // 2:
                    signals.append(
                        InsightSignal(
                            signal_type="goal_behind_pace",
                            category="B",
                            metrics=[goal.metric],
                            values={"current": current, "target": goal.target_value, "progress_pct": pct},
                            severity=3,
                            actionable=True,
                            focus_relevant=False,
                            title_hint=f"{goal.metric} goal behind pace",
                            data_payload={
                                "metric": goal.metric,
                                "current": current,
                                "target": goal.target_value,
                                "progress_pct": pct,
                            },
                        )
                    )
                elif pct >= 50 and pct < 80 and self.brief.data_maturity_days > period_days // 2:
                    signals.append(
                        InsightSignal(
                            signal_type="goal_ahead_of_pace",
                            category="B",
                            metrics=[goal.metric],
                            values={"current": current, "target": goal.target_value, "progress_pct": pct},
                            severity=2,
                            actionable=False,
                            focus_relevant=False,
                            title_hint=f"{goal.metric} goal ahead of pace",
                            data_payload={
                                "metric": goal.metric,
                                "current": current,
                                "target": goal.target_value,
                                "progress_pct": pct,
                            },
                        )
                    )

            # Goal deadline approaching (within 7 days)
            if goal.deadline:
                from datetime import date as date_type

                try:
                    deadline_date = date_type.fromisoformat(str(goal.deadline)[:10])
                    days_remaining = (deadline_date - self.brief.generated_at.date()).days
                    if 0 < days_remaining <= 7 and not progress["is_met"]:
                        signals.append(
                            InsightSignal(
                                signal_type="goal_deadline_approaching",
                                category="B",
                                metrics=[goal.metric],
                                values={
                                    "current": current,
                                    "target": goal.target_value,
                                    "days_remaining": days_remaining,
                                    "progress_pct": pct,
                                },
                                severity=4 if days_remaining <= 3 else 3,
                                actionable=True,
                                focus_relevant=False,
                                title_hint=f"{goal.metric} deadline in {days_remaining}d",
                                data_payload={
                                    "metric": goal.metric,
                                    "days_remaining": days_remaining,
                                    "progress_pct": pct,
                                },
                            )
                        )
                    # Goal completed (deadline goal that is now met)
                    if days_remaining <= 0 and progress["is_met"]:
                        signals.append(
                            InsightSignal(
                                signal_type="goal_completed",
                                category="B",
                                metrics=[goal.metric],
                                values={"current": current, "target": goal.target_value},
                                severity=4,
                                actionable=False,
                                focus_relevant=False,
                                title_hint=f"{goal.metric} goal completed!",
                                data_payload={"metric": goal.metric, "current": current, "target": goal.target_value},
                            )
                        )
                except (ValueError, TypeError):
                    pass  # Invalid deadline — skip

            # Streak for this goal
            goal_daily_values = self._get_metric_values(goal.metric)
            if goal_daily_values and goal.target_value > 0:
                streak_result = tracker.calculate_streak(goal_daily_values, goal.target_value)
                if streak_result["streak_days"] >= 3 and streak_result["is_active"]:
                    signals.append(
                        InsightSignal(
                            signal_type="goal_streak",
                            category="B",
                            metrics=[goal.metric],
                            values={"streak_days": streak_result["streak_days"]},
                            severity=3,
                            actionable=False,
                            focus_relevant=False,
                            title_hint=f"{streak_result['streak_days']}-day {goal.metric} streak",
                            data_payload={
                                "metric": goal.metric,
                                "streak_days": streak_result["streak_days"],
                            },
                        )
                    )

        return signals

    def _get_metric_values(self, metric: str) -> list[float]:
        """Extract ordered daily values for a named metric from the brief."""
        if metric in ("steps", "active_calories", "resting_heart_rate", "hrv_ms"):
            return [v for r in self.brief.daily_metrics for v in [getattr(r, metric, None)] if v is not None]
        if metric == "sleep_hours":
            return [r.hours for r in self.brief.sleep_records if r.hours is not None]
        if metric == "weight_kg":
            return [r.weight_kg for r in self.brief.weight if r.weight_kg is not None]
        return []

    # ------------------------------------------------------------------
    # Category C — Anomaly detection
    # ------------------------------------------------------------------

    def _detect_category_c(self) -> list[InsightSignal]:
        """Detect anomalous metric values using z-score against 14-day baseline."""
        signals: list[InsightSignal] = []
        today = self.brief.generated_at.date().isoformat()

        daily_metric_names = [
            "resting_heart_rate",
            "hrv_ms",
            "steps",
            "active_calories",
            "heart_rate_avg",
            "vo2_max",
            "respiratory_rate",
            "oxygen_saturation",
            "body_fat_percentage",
        ]
        for metric in daily_metric_names:
            by_date = {r.date: getattr(r, metric) for r in self.brief.daily_metrics if getattr(r, metric) is not None}
            signal = self._compute_anomaly_signal(metric, by_date, today)
            if signal:
                signals.append(signal)

        # Sleep anomalies
        sleep_hours_by_date = {r.date: r.hours for r in self.brief.sleep_records if r.hours is not None}
        s = self._compute_anomaly_signal("sleep_hours", sleep_hours_by_date, today)
        if s:
            signals.append(s)

        sleep_quality_by_date = {
            r.date: r.quality_score for r in self.brief.sleep_records if r.quality_score is not None
        }
        s = self._compute_anomaly_signal("sleep_quality", sleep_quality_by_date, today)
        if s:
            signals.append(s)

        # Weight spike (special rule: ≥2 kg from 7-day average)
        weight_by_date = {r.date: r.weight_kg for r in self.brief.weight if r.weight_kg is not None}
        if today in weight_by_date:
            recent_weights = sorted([(d, v) for d, v in weight_by_date.items() if d != today])[-7:]
            if len(recent_weights) >= 7:
                avg = sum(v for _, v in recent_weights) / len(recent_weights)
                diff = abs(weight_by_date[today] - avg)
                if diff >= 2.0:
                    signals.append(
                        InsightSignal(
                            signal_type="anomaly",
                            category="C",
                            metrics=["weight_kg"],
                            values={
                                "current": weight_by_date[today],
                                "baseline_avg": round(avg, 1),
                                "diff_kg": round(diff, 1),
                            },
                            severity=4 if diff >= 3 else 3,
                            actionable=True,
                            focus_relevant=False,
                            title_hint="Unusual weight change",
                            data_payload={
                                "metric": "weight_kg",
                                "current": weight_by_date[today],
                                "diff_kg": round(diff, 1),
                            },
                        )
                    )

        return signals

    def _compute_anomaly_signal(self, metric: str, date_values: dict, today: str) -> InsightSignal | None:
        """Compute a z-score anomaly signal, or return None if no anomaly."""
        current = date_values.get(today)
        if current is None:
            return None
        historical = [v for d, v in date_values.items() if d != today]
        if len(historical) < 14:
            return None
        mean = sum(historical) / len(historical)
        variance = sum((v - mean) ** 2 for v in historical) / len(historical)
        stddev = math.sqrt(variance)
        if stddev == 0.0:
            deviation = 0.0 if current == mean else float("inf")
        else:
            deviation = abs(current - mean) / stddev
        if deviation < 2.0:
            return None
        severity = 5 if deviation >= 3.0 else 3
        direction = "high" if current > mean else "low"
        return InsightSignal(
            signal_type="anomaly",
            category="C",
            metrics=[metric],
            values={
                "current": round(current, 2),
                "baseline_mean": round(mean, 2),
                "deviation": round(deviation, 2),
                "direction": direction,
            },
            severity=severity,
            actionable=True,
            focus_relevant=False,
            title_hint=f"Unusual {metric.replace('_', ' ')}",
            data_payload={
                "metric": metric,
                "current": round(current, 2),
                "baseline_mean": round(mean, 2),
                "direction": direction,
            },
        )

    # ------------------------------------------------------------------
    # Category D — Correlations
    # ------------------------------------------------------------------

    def _detect_category_d(self) -> list[InsightSignal]:
        """Detect cross-metric correlations across 14 defined pairs."""
        signals: list[InsightSignal] = []
        analyzer = CorrelationAnalyzer()

        sleep_by_date = {r.date: r.hours for r in self.brief.sleep_records if r.hours is not None}
        sleep_qual_by_date = {r.date: r.quality_score for r in self.brief.sleep_records if r.quality_score is not None}
        daily_by_date: dict[str, Any] = {}
        for r in self.brief.daily_metrics:
            daily_by_date[r.date] = r

        hrv_by_date = {d: r.hrv_ms for d, r in daily_by_date.items() if r.hrv_ms is not None}
        steps_by_date = {d: r.steps for d, r in daily_by_date.items() if r.steps is not None}
        cals_by_date = {d: r.active_calories for d, r in daily_by_date.items() if r.active_calories is not None}
        rhr_by_date = {d: r.resting_heart_rate for d, r in daily_by_date.items() if r.resting_heart_rate is not None}
        nutrition_by_date = {r.date: r.calories for r in self.brief.nutrition if r.calories is not None}
        weight_by_date = {r.date: r.weight_kg for r in self.brief.weight if r.weight_kg is not None}

        pairs = [
            ("sleep_hours", sleep_by_date, "steps", steps_by_date, 1),
            ("sleep_hours", sleep_by_date, "active_calories", cals_by_date, 1),
            ("sleep_hours", sleep_by_date, "hrv_ms", hrv_by_date, 0),
            ("sleep_quality", sleep_qual_by_date, "resting_heart_rate", rhr_by_date, 0),
            ("sleep_quality", sleep_qual_by_date, "steps", steps_by_date, 1),
            ("hrv_ms", hrv_by_date, "active_calories", cals_by_date, 1),
            ("hrv_ms", hrv_by_date, "resting_heart_rate", rhr_by_date, 0),
            ("steps", steps_by_date, "sleep_hours", sleep_by_date, 1),
            ("active_calories", cals_by_date, "sleep_quality", sleep_qual_by_date, 1),
            ("resting_heart_rate", rhr_by_date, "sleep_hours", sleep_by_date, 1),
            ("calorie_intake", nutrition_by_date, "weight_kg", weight_by_date, 3),
            ("calorie_intake", nutrition_by_date, "active_calories", cals_by_date, 0),
            ("sleep_hours", sleep_by_date, "calorie_intake", nutrition_by_date, 0),
            ("hrv_ms", hrv_by_date, "steps", steps_by_date, 0),
        ]

        for x_name, x_map, y_name, y_map, lag in pairs:
            try:
                x_vals, y_vals = self._align_with_lag(x_map, y_map, lag)
                if len(x_vals) < 14:
                    continue
                result = analyzer.calculate_correlation(x_vals, y_vals)
                score = abs(result.get("score", 0.0))
                if score < 0.4:
                    continue
                severity = 3 if score > 0.7 else 2
                signals.append(
                    InsightSignal(
                        signal_type="correlation_discovery",
                        category="D",
                        metrics=[x_name, y_name],
                        values={"correlation": round(result["score"], 3), "lag_days": lag},
                        severity=severity,
                        actionable=False,
                        focus_relevant=False,
                        title_hint=f"{x_name.replace('_', ' ')} linked to {y_name.replace('_', ' ')}",
                        data_payload={
                            "x": x_name,
                            "y": y_name,
                            "r": round(result["score"], 3),
                            "lag_days": lag,
                        },
                    )
                )
            except Exception as exc:  # noqa: BLE001
                logger.debug("Correlation pair (%s, %s) failed: %s", x_name, y_name, exc)

        return signals

    def _align_with_lag(self, x_map: dict, y_map: dict, lag: int) -> tuple[list[float], list[float]]:
        """Align two date-keyed dicts with an optional forward lag."""
        if lag == 0:
            common = sorted(set(x_map.keys()) & set(y_map.keys()))
            return [x_map[d] for d in common], [y_map[d] for d in common]
        x_vals: list[float] = []
        y_vals: list[float] = []
        for d in sorted(x_map.keys()):
            shifted = (date_type.fromisoformat(d) + timedelta(days=lag)).isoformat()
            if shifted in y_map:
                x_vals.append(x_map[d])
                y_vals.append(y_map[shifted])
        return x_vals, y_vals

    # ------------------------------------------------------------------
    # Category E — Compound patterns
    # ------------------------------------------------------------------

    def _detect_category_e(self) -> list[InsightSignal]:
        """Detect all 10 compound multi-metric patterns."""
        signals: list[InsightSignal] = []
        signals.extend(self._detect_compound_weight_plateau())
        signals.extend(self._detect_compound_overtraining_risk())
        signals.extend(self._detect_compound_sleep_debt())
        signals.extend(self._detect_compound_deficit_too_deep())
        signals.extend(self._detect_compound_workout_collapse())
        signals.extend(self._detect_compound_recovery_peak())
        signals.extend(self._detect_compound_stress_cascade())
        signals.extend(self._detect_compound_dehydration_pattern())
        signals.extend(self._detect_compound_weekend_gap())
        signals.extend(self._detect_compound_event_on_track())
        return signals

    def _detect_compound_weight_plateau(self) -> list[InsightSignal]:
        """Fire if weight std dev < 0.3 kg over 14 days AND user has weight-loss goal."""
        try:
            weight_values = [r.weight_kg for r in self.brief.weight if r.weight_kg is not None]
            if len(weight_values) < 14:
                return []

            recent = weight_values[-14:]
            mean = sum(recent) / len(recent)
            variance = sum((v - mean) ** 2 for v in recent) / len(recent)
            stddev = math.sqrt(variance)
            if stddev >= 0.3:
                return []

            has_weight_loss_goal = any(
                g.is_active and g.metric in ("weight_kg", "body_fat_percentage") for g in self.brief.goals
            ) or "weight_loss" in (self.brief.preferences.goals or [])

            if not has_weight_loss_goal:
                return []

            # Check calories in < TDEE (if available)
            recent_nutrition = self.brief.nutrition[-14:]
            avg_calories_in = (
                sum(r.calories for r in recent_nutrition if r.calories is not None)
                / max(1, sum(1 for r in recent_nutrition if r.calories is not None))
                if recent_nutrition
                else None
            )

            if avg_calories_in is None or (
                self.brief.estimated_tdee is not None and avg_calories_in >= self.brief.estimated_tdee
            ):
                return []

            return [
                InsightSignal(
                    signal_type="compound_weight_plateau",
                    category="E",
                    metrics=["weight_kg"],
                    values={"stddev_kg": round(stddev, 3), "mean_kg": round(mean, 1)},
                    severity=4,
                    actionable=True,
                    focus_relevant=False,
                    title_hint="Weight plateau despite deficit",
                    data_payload={
                        "stddev_kg": round(stddev, 3),
                        "mean_kg": round(mean, 1),
                        "avg_calories_in": round(avg_calories_in, 0) if avg_calories_in else None,
                    },
                )
            ]
        except Exception as exc:  # noqa: BLE001
            logger.debug("compound_weight_plateau failed: %s", exc)
            return []

    def _detect_compound_overtraining_risk(self) -> list[InsightSignal]:
        """Fire if ≥5 consecutive workout days AND HRV declining AND RHR rising."""
        try:
            if not self.brief.activities:
                return []

            # Count consecutive workout days ending at the most recent activity
            activity_dates = sorted({a.date for a in self.brief.activities if a.date}, reverse=True)
            if not activity_dates:
                return []

            consecutive = 1
            for i in range(1, len(activity_dates)):
                expected_prev = (date_type.fromisoformat(activity_dates[i - 1]) - timedelta(days=1)).isoformat()
                if activity_dates[i] == expected_prev:
                    consecutive += 1
                else:
                    break

            if consecutive < 5:
                return []

            # HRV: recent 7-day avg < previous 7-day avg
            hrv_values = [r.hrv_ms for r in self.brief.daily_metrics if r.hrv_ms is not None]
            if len(hrv_values) < 14:
                return []
            hrv_recent_avg = sum(hrv_values[-7:]) / 7
            hrv_prev_avg = sum(hrv_values[-14:-7]) / 7
            if hrv_recent_avg >= hrv_prev_avg:
                return []

            # RHR: recent 7-day avg > previous 7-day avg
            rhr_values = [r.resting_heart_rate for r in self.brief.daily_metrics if r.resting_heart_rate is not None]
            if len(rhr_values) < 14:
                return []
            rhr_recent_avg = sum(rhr_values[-7:]) / 7
            rhr_prev_avg = sum(rhr_values[-14:-7]) / 7
            if rhr_recent_avg <= rhr_prev_avg:
                return []

            return [
                InsightSignal(
                    signal_type="compound_overtraining_risk",
                    category="E",
                    metrics=["hrv_ms", "resting_heart_rate"],
                    values={
                        "consecutive_workout_days": consecutive,
                        "hrv_recent_avg": round(hrv_recent_avg, 1),
                        "hrv_prev_avg": round(hrv_prev_avg, 1),
                        "rhr_recent_avg": round(rhr_recent_avg, 1),
                        "rhr_prev_avg": round(rhr_prev_avg, 1),
                    },
                    severity=4,
                    actionable=True,
                    focus_relevant=False,
                    title_hint="Overtraining risk detected",
                    data_payload={
                        "consecutive_days": consecutive,
                        "hrv_pct_change": round((hrv_recent_avg - hrv_prev_avg) / hrv_prev_avg * 100, 1)
                        if hrv_prev_avg
                        else 0,
                        "rhr_increase": round(rhr_recent_avg - rhr_prev_avg, 1),
                    },
                )
            ]
        except Exception as exc:  # noqa: BLE001
            logger.debug("compound_overtraining_risk failed: %s", exc)
            return []

    def _detect_compound_sleep_debt(self) -> list[InsightSignal]:
        """Fire if avg sleep < 6.5h over last 7 days AND >3 nights below 6h."""
        try:
            recent_sleep = [r.hours for r in self.brief.sleep_records[-7:] if r.hours is not None]
            if len(recent_sleep) < 7:
                return []
            avg = sum(recent_sleep) / len(recent_sleep)
            nights_under_6 = sum(1 for h in recent_sleep if h < 6.0)
            if avg >= 6.5 or nights_under_6 <= 3:
                return []
            return [
                InsightSignal(
                    signal_type="compound_sleep_debt",
                    category="E",
                    metrics=["sleep_hours"],
                    values={"avg_sleep_hours": round(avg, 1), "nights_under_6h": nights_under_6},
                    severity=3,
                    actionable=True,
                    focus_relevant=False,
                    title_hint="Sleep debt accumulating",
                    data_payload={
                        "avg_sleep_hours": round(avg, 1),
                        "nights_under_6h": nights_under_6,
                    },
                )
            ]
        except Exception as exc:  # noqa: BLE001
            logger.debug("compound_sleep_debt failed: %s", exc)
            return []

    def _detect_compound_deficit_too_deep(self) -> list[InsightSignal]:
        """Fire if avg calories_in < TDEE * 0.6 over last 7 days."""
        try:
            if self.brief.estimated_tdee is None:
                return []
            recent_nutrition = [r.calories for r in self.brief.nutrition[-7:] if r.calories is not None]
            if len(recent_nutrition) < 5:
                return []
            avg_calories = sum(recent_nutrition) / len(recent_nutrition)
            threshold = self.brief.estimated_tdee * 0.6
            if avg_calories >= threshold:
                return []
            return [
                InsightSignal(
                    signal_type="compound_deficit_too_deep",
                    category="E",
                    metrics=["calorie_intake"],
                    values={
                        "avg_calories": round(avg_calories, 0),
                        "tdee": self.brief.estimated_tdee,
                        "threshold": round(threshold, 0),
                    },
                    severity=4,
                    actionable=True,
                    focus_relevant=False,
                    title_hint="Calorie deficit too aggressive",
                    data_payload={
                        "avg_calories": round(avg_calories, 0),
                        "tdee": self.brief.estimated_tdee,
                        "pct_of_tdee": round(avg_calories / self.brief.estimated_tdee * 100, 1),
                    },
                )
            ]
        except Exception as exc:  # noqa: BLE001
            logger.debug("compound_deficit_too_deep failed: %s", exc)
            return []

    def _detect_compound_workout_collapse(self) -> list[InsightSignal]:
        """Fire if workout count drops ≥50% in last 7 days vs prior 14 days."""
        try:
            if not self.brief.activities:
                return []

            all_dates = sorted({a.date for a in self.brief.activities if a.date})
            if len(all_dates) < 7:
                return []

            today = self.brief.generated_at.date()
            seven_days_ago = (today - timedelta(days=7)).isoformat()
            fourteen_days_ago = (today - timedelta(days=14)).isoformat()

            recent_count = sum(1 for d in all_dates if d > seven_days_ago)
            prior_count = sum(1 for d in all_dates if fourteen_days_ago < d <= seven_days_ago)

            # Need prior data to compare; skip if no prior workouts
            if prior_count == 0:
                return []

            drop_pct = (prior_count - recent_count) / prior_count * 100
            if drop_pct < 50:
                return []

            return [
                InsightSignal(
                    signal_type="compound_workout_collapse",
                    category="E",
                    metrics=["workout_frequency"],
                    values={
                        "recent_count": recent_count,
                        "prior_count": prior_count,
                        "drop_pct": round(drop_pct, 1),
                    },
                    severity=3,
                    actionable=True,
                    focus_relevant=False,
                    title_hint="Workout frequency dropped sharply",
                    data_payload={
                        "recent_7d_workouts": recent_count,
                        "prior_7d_workouts": prior_count,
                        "drop_pct": round(drop_pct, 1),
                    },
                )
            ]
        except Exception as exc:  # noqa: BLE001
            logger.debug("compound_workout_collapse failed: %s", exc)
            return []

    def _detect_compound_recovery_peak(self) -> list[InsightSignal]:
        """Fire if HRV 7-day avg > 30-day avg by ≥15% AND RHR is declining."""
        try:
            hrv_values = [r.hrv_ms for r in self.brief.daily_metrics if r.hrv_ms is not None]
            if len(hrv_values) < 30:
                return []
            hrv_7d = sum(hrv_values[-7:]) / 7
            hrv_30d = sum(hrv_values[-30:]) / 30
            if hrv_30d == 0:
                return []
            hrv_boost_pct = (hrv_7d - hrv_30d) / hrv_30d * 100
            if hrv_boost_pct < 15:
                return []

            rhr_values = [r.resting_heart_rate for r in self.brief.daily_metrics if r.resting_heart_rate is not None]
            if len(rhr_values) < 14:
                return []
            rhr_7d = sum(rhr_values[-7:]) / 7
            rhr_30d = sum(rhr_values[-30:]) / 30 if len(rhr_values) >= 30 else sum(rhr_values) / len(rhr_values)
            if rhr_7d >= rhr_30d:
                return []

            return [
                InsightSignal(
                    signal_type="compound_recovery_peak",
                    category="E",
                    metrics=["hrv_ms", "resting_heart_rate"],
                    values={
                        "hrv_7d_avg": round(hrv_7d, 1),
                        "hrv_30d_avg": round(hrv_30d, 1),
                        "hrv_boost_pct": round(hrv_boost_pct, 1),
                        "rhr_7d_avg": round(rhr_7d, 1),
                    },
                    severity=2,
                    actionable=False,
                    focus_relevant=False,
                    title_hint="Peak recovery window",
                    data_payload={
                        "hrv_boost_pct": round(hrv_boost_pct, 1),
                        "rhr_7d_avg": round(rhr_7d, 1),
                    },
                )
            ]
        except Exception as exc:  # noqa: BLE001
            logger.debug("compound_recovery_peak failed: %s", exc)
            return []

    def _detect_compound_stress_cascade(self) -> list[InsightSignal]:
        """Fire if avg stress >7 or avg mood <4 for 3+ consecutive days AND sleep declining."""
        try:
            stress_logs = [q for q in self.brief.quick_logs if q.metric_type == "stress" and q.value is not None]
            mood_logs = [q for q in self.brief.quick_logs if q.metric_type == "mood" and q.value is not None]

            if not stress_logs and not mood_logs:
                return []

            # Check 3 consecutive bad days
            today = self.brief.generated_at.date()
            bad_days = 0
            for offset in range(3):
                day = (today - timedelta(days=offset)).isoformat()
                day_stress = [q.value for q in stress_logs if q.logged_at.startswith(day)]
                day_mood = [q.value for q in mood_logs if q.logged_at.startswith(day)]
                stress_bad = (sum(day_stress) / len(day_stress)) > 7 if day_stress else False
                mood_bad = (sum(day_mood) / len(day_mood)) < 4 if day_mood else False
                if stress_bad or mood_bad:
                    bad_days += 1

            if bad_days < 3:
                return []

            # Sleep hours declining over same period
            recent_sleep = [r.hours for r in self.brief.sleep_records[-7:] if r.hours is not None]
            if len(recent_sleep) < 4:
                return []
            half = len(recent_sleep) // 2
            sleep_declining = sum(recent_sleep[:half]) / half > sum(recent_sleep[half:]) / (len(recent_sleep) - half)

            if not sleep_declining:
                return []

            return [
                InsightSignal(
                    signal_type="compound_stress_cascade",
                    category="E",
                    metrics=["stress", "sleep_hours"],
                    values={"bad_days": bad_days},
                    severity=4,
                    actionable=True,
                    focus_relevant=False,
                    title_hint="Stress and sleep spiral detected",
                    data_payload={"consecutive_bad_days": bad_days},
                )
            ]
        except Exception as exc:  # noqa: BLE001
            logger.debug("compound_stress_cascade failed: %s", exc)
            return []

    def _detect_compound_dehydration_pattern(self) -> list[InsightSignal]:
        """Fire if avg water intake < 1500 ml/day over last 3 days."""
        try:
            today = self.brief.generated_at.date()
            daily_water: dict[str, float] = {}
            for log in self.brief.quick_logs:
                if log.metric_type != "water_ml" or log.value is None:
                    continue
                day = log.logged_at[:10] if log.logged_at else None
                if day:
                    daily_water[day] = daily_water.get(day, 0.0) + log.value

            last_3 = [(today - timedelta(days=i)).isoformat() for i in range(3)]
            totals = [daily_water.get(d, 0.0) for d in last_3]
            days_logged = sum(1 for d in last_3 if d in daily_water)

            if days_logged < 2:
                return []

            avg_water = sum(totals) / 3
            if avg_water >= 1500:
                return []

            return [
                InsightSignal(
                    signal_type="compound_dehydration_pattern",
                    category="E",
                    metrics=["water_ml"],
                    values={"avg_water_ml": round(avg_water, 0)},
                    severity=3,
                    actionable=True,
                    focus_relevant=False,
                    title_hint="Low water intake this week",
                    data_payload={"avg_water_ml": round(avg_water, 0), "days_checked": 3},
                )
            ]
        except Exception as exc:  # noqa: BLE001
            logger.debug("compound_dehydration_pattern failed: %s", exc)
            return []

    def _detect_compound_weekend_gap(self) -> list[InsightSignal]:
        """Fire if weekend workout count is consistently < weekday count by ≥60% over 4 weeks."""
        try:
            if not self.brief.activities:
                return []

            activity_dates = {a.date for a in self.brief.activities if a.date}
            today = self.brief.generated_at.date()
            cutoff = (today - timedelta(weeks=4)).isoformat()
            relevant = [d for d in activity_dates if d >= cutoff]

            if len(relevant) < 4:
                return []

            weekend_days = sum(1 for d in relevant if date_type.fromisoformat(d).weekday() >= 5)
            weekday_days = sum(1 for d in relevant if date_type.fromisoformat(d).weekday() < 5)

            # Normalise to per-day rate (28 days: 8 weekend days, 20 weekday days)
            if weekday_days == 0:
                return []
            weekend_rate = weekend_days / 8  # out of 8 weekend days in 4 weeks
            weekday_rate = weekday_days / 20  # out of 20 weekday days in 4 weeks

            if weekday_rate == 0:
                return []
            gap_pct = (weekday_rate - weekend_rate) / weekday_rate * 100
            if gap_pct < 60:
                return []

            return [
                InsightSignal(
                    signal_type="compound_weekend_gap",
                    category="E",
                    metrics=["workout_frequency"],
                    values={
                        "weekend_workout_days": weekend_days,
                        "weekday_workout_days": weekday_days,
                        "gap_pct": round(gap_pct, 1),
                    },
                    severity=2,
                    actionable=True,
                    focus_relevant=False,
                    title_hint="Much less active on weekends",
                    data_payload={
                        "weekend_days": weekend_days,
                        "weekday_days": weekday_days,
                        "gap_pct": round(gap_pct, 1),
                    },
                )
            ]
        except Exception as exc:  # noqa: BLE001
            logger.debug("compound_weekend_gap failed: %s", exc)
            return []

    def _detect_compound_event_on_track(self) -> list[InsightSignal]:
        """Fire if goal with deadline is on pace to be met in time."""
        try:
            signals: list[InsightSignal] = []
            today = self.brief.generated_at.date()

            for goal in self.brief.goals:
                if not goal.is_active or not goal.deadline or goal.target_value <= 0:
                    continue
                if goal.current_value is None:
                    continue

                try:
                    deadline = date_type.fromisoformat(str(goal.deadline))
                except (ValueError, TypeError):
                    continue

                days_remaining = (deadline - today).days
                if days_remaining <= 0:
                    continue

                pct_complete = goal.current_value / goal.target_value
                # "On track" = at least 50% complete when halfway to deadline OR
                # extrapolated linear progress would reach 100% by deadline.
                # Use a simple linear projection from current value.
                #
                # We need to know start_value; we approximate using the first
                # available metric value from daily_metrics.
                start_values = self._get_metric_values(goal.metric)
                if start_values:
                    start_value = start_values[0]
                    total_progress = goal.current_value - start_value
                    data_days = len(start_values)
                    if data_days > 0 and total_progress > 0:
                        daily_rate = total_progress / data_days
                        projected_value = goal.current_value + daily_rate * days_remaining
                        if projected_value >= goal.target_value:
                            signals.append(
                                InsightSignal(
                                    signal_type="compound_event_on_track",
                                    category="E",
                                    metrics=[goal.metric],
                                    values={
                                        "current": goal.current_value,
                                        "target": goal.target_value,
                                        "days_remaining": days_remaining,
                                        "projected": round(projected_value, 1),
                                    },
                                    severity=2,
                                    actionable=False,
                                    focus_relevant=False,
                                    title_hint=f"On track for {goal.metric} goal",
                                    data_payload={
                                        "metric": goal.metric,
                                        "projected": round(projected_value, 1),
                                        "days_remaining": days_remaining,
                                    },
                                )
                            )
                elif pct_complete >= 0.5:
                    # Simpler check when no historical data: already halfway there
                    signals.append(
                        InsightSignal(
                            signal_type="compound_event_on_track",
                            category="E",
                            metrics=[goal.metric],
                            values={
                                "current": goal.current_value,
                                "target": goal.target_value,
                                "days_remaining": days_remaining,
                                "pct_complete": round(pct_complete * 100, 1),
                            },
                            severity=2,
                            actionable=False,
                            focus_relevant=False,
                            title_hint=f"On track for {goal.metric} goal",
                            data_payload={
                                "metric": goal.metric,
                                "pct_complete": round(pct_complete * 100, 1),
                                "days_remaining": days_remaining,
                            },
                        )
                    )

            return signals
        except Exception as exc:  # noqa: BLE001
            logger.debug("compound_event_on_track failed: %s", exc)
            return []

    # ------------------------------------------------------------------
    # Category G — Streaks
    # ------------------------------------------------------------------

    def _detect_category_g(self) -> list[InsightSignal]:
        """Detect streak at-risk, milestone, and milestone-tomorrow events."""
        signals: list[InsightSignal] = []
        today = self.brief.generated_at.date().isoformat()
        milestones = {7, 14, 30, 60, 90, 180, 365}

        for streak in self.brief.streaks:
            count = streak.current_count
            last = streak.last_activity_date

            # Streak at risk: active streak + today not yet logged
            if count >= 3 and last and last < today:
                signals.append(
                    InsightSignal(
                        signal_type="streak_at_risk",
                        category="G",
                        metrics=[streak.streak_type],
                        values={"streak_days": count},
                        severity=4,
                        actionable=True,
                        focus_relevant=False,
                        title_hint=f"{count}-day streak at risk",
                        data_payload={
                            "streak_type": streak.streak_type,
                            "streak_days": count,
                        },
                    )
                )

            # Streak milestone reached
            if count in milestones and last == today:
                signals.append(
                    InsightSignal(
                        signal_type="streak_milestone",
                        category="G",
                        metrics=[streak.streak_type],
                        values={"streak_days": count},
                        severity=3,
                        actionable=False,
                        focus_relevant=False,
                        title_hint=f"{count}-day streak milestone",
                        data_payload={
                            "streak_type": streak.streak_type,
                            "streak_days": count,
                        },
                    )
                )

            # Streak milestone tomorrow
            next_milestone = min((m for m in milestones if m > count), default=None)
            if next_milestone == count + 1 and last == today:
                signals.append(
                    InsightSignal(
                        signal_type="streak_milestone_tomorrow",
                        category="G",
                        metrics=[streak.streak_type],
                        values={"streak_days": count, "next_milestone": next_milestone},
                        severity=2,
                        actionable=True,
                        focus_relevant=False,
                        title_hint=f"{next_milestone}-day milestone tomorrow",
                        data_payload={
                            "streak_type": streak.streak_type,
                            "next_milestone": next_milestone,
                        },
                    )
                )

        return signals

    # ------------------------------------------------------------------
    # Category H — Data quality
    # ------------------------------------------------------------------

    def _detect_category_h(self) -> list[InsightSignal]:
        """Detect stale integrations, new-user state, and missing sleep data."""
        signals: list[InsightSignal] = []

        # Stale integrations
        stale = [i for i in self.brief.integrations if i.is_stale]
        if stale:
            signals.append(
                InsightSignal(
                    signal_type="integration_stale",
                    category="H",
                    metrics=[],
                    values={"stale_providers": [i.provider for i in stale]},
                    severity=2,
                    actionable=True,
                    focus_relevant=False,
                    title_hint="Integration needs re-sync",
                    data_payload={"stale_providers": [i.provider for i in stale]},
                )
            )

        # New user / first week
        if self.brief.data_maturity_days < 7:
            signals.append(
                InsightSignal(
                    signal_type="first_week",
                    category="H",
                    metrics=[],
                    values={"data_days": self.brief.data_maturity_days},
                    severity=1,
                    actionable=True,
                    focus_relevant=False,
                    title_hint="Building your baseline",
                    data_payload={"data_days": self.brief.data_maturity_days},
                )
            )

        # Missing sleep data for 3+ consecutive days
        recent_sleep_dates = {r.date for r in self.brief.sleep_records}
        today = self.brief.generated_at.date()
        consecutive_missing = 0
        for i in range(7):
            d = (today - timedelta(days=i)).isoformat()
            if d not in recent_sleep_dates:
                consecutive_missing += 1
            else:
                break
        if consecutive_missing >= 3:
            signals.append(
                InsightSignal(
                    signal_type="data_quality",
                    category="H",
                    metrics=["sleep"],
                    values={"missing_days": consecutive_missing},
                    severity=2,
                    actionable=True,
                    focus_relevant=False,
                    title_hint="Missing sleep data",
                    data_payload={
                        "missing_days": consecutive_missing,
                        "data_type": "sleep",
                    },
                )
            )

        return signals
