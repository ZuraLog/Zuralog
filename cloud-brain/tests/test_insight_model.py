"""Tests for the Insight model and INSIGHT_TYPES constant.

These tests verify that the AI Insights Engine schema additions are present:
  - generation_date column on Insight
  - signal_type column on Insight
  - timezone column on UserPreferences
  - All new INSIGHT_TYPES values are present
"""


def test_insight_has_generation_date_and_signal_type():
    from app.models.insight import Insight

    assert hasattr(Insight, "generation_date")
    assert hasattr(Insight, "signal_type")


def test_user_preferences_has_timezone():
    from app.models.user_preferences import UserPreferences

    assert hasattr(UserPreferences, "timezone")


def test_insight_types_contains_new_types():
    from app.models.insight import INSIGHT_TYPES

    required = [
        "trend_decline",
        "trend_improvement",
        "compound_weight_plateau",
        "compound_overtraining_risk",
        "compound_sleep_debt",
        "compound_deficit_too_deep",
        "compound_workout_collapse",
        "compound_recovery_peak",
        "compound_stress_cascade",
        "compound_dehydration_pattern",
        "compound_weekend_gap",
        "compound_event_on_track",
        "data_quality",
    ]
    for t in required:
        assert t in INSIGHT_TYPES, f"Missing type: {t}"
