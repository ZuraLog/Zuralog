"""Tests verifying that health data models have foreign keys on user_id.

Each of the 5 health data models should have a ForeignKey constraint on
the user_id column pointing to the users table, enabling CASCADE deletes
when a user is removed.
"""

import pytest

from app.models.health_data import (
    NutritionEntry,
    SleepRecord,
    UnifiedActivity,
    WeightMeasurement,
)
from app.models.daily_metrics import DailyHealthMetrics


HEALTH_MODELS = [
    UnifiedActivity,
    SleepRecord,
    NutritionEntry,
    WeightMeasurement,
    DailyHealthMetrics,
]


@pytest.mark.parametrize("model", HEALTH_MODELS, ids=lambda m: m.__name__)
def test_user_id_has_foreign_key(model):
    """user_id column must have a ForeignKey constraint."""
    fks = model.__table__.c.user_id.foreign_keys
    assert fks, (
        f"{model.__name__}.user_id has no foreign keys — expected a FK to users.id"
    )


@pytest.mark.parametrize("model", HEALTH_MODELS, ids=lambda m: m.__name__)
def test_user_id_fk_points_to_users(model):
    """The foreign key on user_id must reference the users table."""
    fks = model.__table__.c.user_id.foreign_keys
    targets = {fk.target_fullname for fk in fks}
    assert "users.id" in targets, (
        f"{model.__name__}.user_id FK does not point to users.id — got {targets}"
    )


@pytest.mark.parametrize("model", HEALTH_MODELS, ids=lambda m: m.__name__)
def test_user_id_fk_has_cascade_delete(model):
    """The foreign key on user_id must be defined with ondelete='CASCADE'."""
    fks = model.__table__.c.user_id.foreign_keys
    cascade_fks = [fk for fk in fks if fk.ondelete and fk.ondelete.upper() == "CASCADE"]
    assert cascade_fks, (
        f"{model.__name__}.user_id FK does not have ondelete=CASCADE"
    )
