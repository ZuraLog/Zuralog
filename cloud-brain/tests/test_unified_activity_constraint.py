"""Security regression test: UnifiedActivity unique constraint must include user_id.

S-6: Without user_id in the unique constraint on (source, original_id), two users
with the same original_id from the same source would collide — causing an upsert
to overwrite the wrong user's activity data (cross-user data overwrite).

This test asserts:
1. The new constraint uq_activity_user_source_original exists and covers
   all three columns: user_id, source, original_id.
2. The old constraint uq_activity_source_original no longer exists.
"""

from sqlalchemy import UniqueConstraint

from app.models.health_data import UnifiedActivity


def _get_unique_constraints() -> list[UniqueConstraint]:
    return [
        c
        for c in UnifiedActivity.__table__.constraints
        if isinstance(c, UniqueConstraint)
    ]


def test_new_constraint_includes_user_id_source_original_id() -> None:
    """The unique constraint must cover user_id, source, AND original_id."""
    constraints = _get_unique_constraints()
    column_sets = [
        frozenset(col.name for col in uc.columns) for uc in constraints
    ]
    required = frozenset({"user_id", "source", "original_id"})
    assert required in column_sets, (
        f"No UniqueConstraint with columns {required} found. "
        f"Existing unique constraints have column sets: {column_sets}. "
        "Add user_id to UnifiedActivity's unique constraint to prevent "
        "cross-user data overwrite (S-6)."
    )


def test_old_constraint_name_does_not_exist() -> None:
    """The old constraint name uq_activity_source_original must be gone."""
    constraints = _get_unique_constraints()
    names = [uc.name for uc in constraints]
    assert "uq_activity_source_original" not in names, (
        "Old constraint 'uq_activity_source_original' still exists. "
        "It must be replaced by 'uq_activity_user_source_original' which "
        "includes user_id (S-6)."
    )


def test_new_constraint_name_exists() -> None:
    """The new constraint must use the name uq_activity_user_source_original."""
    constraints = _get_unique_constraints()
    names = [uc.name for uc in constraints]
    assert "uq_activity_user_source_original" in names, (
        f"Expected constraint name 'uq_activity_user_source_original' not found. "
        f"Found: {names}"
    )
