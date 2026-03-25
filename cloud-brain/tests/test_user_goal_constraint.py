"""Test for UserGoal unique constraint on (user_id, metric)."""

from sqlalchemy import UniqueConstraint

from app.models.user_goal import UserGoal


def test_user_goal_has_unique_constraint():
    """Assert that UserGoal has a unique constraint on (user_id, metric)."""
    table = UserGoal.__table__
    constraints = table.constraints

    # Filter for unique constraints
    unique_constraints = [
        c for c in constraints if isinstance(c, UniqueConstraint)
    ]

    # Check that the expected constraint exists
    constraint_names = [c.name for c in unique_constraints]
    assert "uq_user_goals_user_metric" in constraint_names, (
        f"Expected constraint 'uq_user_goals_user_metric' not found. "
        f"Found constraints: {constraint_names}"
    )

    # Verify the constraint covers the correct columns
    target_constraint = next(
        c for c in unique_constraints
        if c.name == "uq_user_goals_user_metric"
    )
    column_names = [col.name for col in target_constraint.columns]
    assert sorted(column_names) == ["metric", "user_id"], (
        f"Expected columns [metric, user_id], got {column_names}"
    )
