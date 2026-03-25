"""Test that UserGoal date columns use the Date type, not String."""
from sqlalchemy import Date

from app.models.user_goal import UserGoal


def test_start_date_is_date_type() -> None:
    col_type = UserGoal.__table__.c.start_date.type
    assert isinstance(col_type, Date), (
        f"Expected start_date to be Date, got {type(col_type).__name__}"
    )


def test_deadline_is_date_type() -> None:
    col_type = UserGoal.__table__.c.deadline.type
    assert isinstance(col_type, Date), (
        f"Expected deadline to be Date, got {type(col_type).__name__}"
    )
