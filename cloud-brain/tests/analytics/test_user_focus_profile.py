"""Tests for UserFocusProfileBuilder."""

from app.analytics.user_focus_profile import UserFocusProfileBuilder


def test_weight_loss_goal_maps_to_cutting_focus():
    builder = UserFocusProfileBuilder(goals=["weight_loss"], dashboard_layout={})
    profile = builder.build()
    assert profile.inferred_focus == "cutting"
    assert "weight_kg" in profile.focus_metrics
    assert "calories" in profile.focus_metrics


def test_no_goals_no_layout_returns_general():
    builder = UserFocusProfileBuilder(goals=[], dashboard_layout={})
    profile = builder.build()
    assert profile.inferred_focus == "general"
    assert profile.focus_metrics == []


def test_dashboard_layout_infers_recovery_focus():
    builder = UserFocusProfileBuilder(
        goals=[],
        dashboard_layout={"visible_cards": ["sleep", "hrv", "stress"]},
    )
    profile = builder.build()
    assert profile.inferred_focus == "recovery"


def test_combined_goal_and_layout_body_recomp():
    builder = UserFocusProfileBuilder(
        goals=["build_muscle"],
        dashboard_layout={"visible_cards": ["protein", "calories", "weight", "workouts"]},
    )
    profile = builder.build()
    assert profile.inferred_focus == "body_recomposition"
    assert "protein_grams" in profile.focus_metrics


def test_focus_metrics_are_not_in_deprioritised():
    builder = UserFocusProfileBuilder(goals=["fitness"], dashboard_layout={})
    profile = builder.build()
    for m in profile.focus_metrics:
        assert m not in profile.deprioritised_metrics


def test_stated_goals_preserved():
    builder = UserFocusProfileBuilder(goals=["sleep", "fitness"], dashboard_layout={})
    profile = builder.build()
    assert "sleep" in profile.stated_goals
    assert "fitness" in profile.stated_goals
