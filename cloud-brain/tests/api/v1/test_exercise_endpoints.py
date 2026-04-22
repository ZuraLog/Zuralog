"""
Unit-style tests for exercise endpoint schemas.

HTTP-based integration tests are skipped in this project due to a pre-existing
Redis URL issue in test fixtures. These tests validate schema behaviour directly.
"""
import pytest
from pydantic import ValidationError


class TestExerciseSchemas:
    def test_exercise_entry_create_rejects_empty_activity(self):
        """An empty activity name must be rejected."""
        from app.api.v1.exercise_schemas import ExerciseEntryCreate

        with pytest.raises((ValidationError, Exception)):
            ExerciseEntryCreate(activity="", calories_burned=300)

    def test_exercise_entry_create_valid(self):
        """A fully populated entry must be accepted and values preserved."""
        from app.api.v1.exercise_schemas import ExerciseEntryCreate

        entry = ExerciseEntryCreate(
            activity="running",
            duration_minutes=30,
            calories_burned=320,
        )
        assert entry.activity == "running"
        assert entry.calories_burned == 320
        assert entry.duration_minutes == 30

    def test_exercise_entry_create_duration_defaults_to_zero(self):
        """duration_minutes should default to 0 when not provided."""
        from app.api.v1.exercise_schemas import ExerciseEntryCreate

        entry = ExerciseEntryCreate(activity="yoga", calories_burned=150)
        assert entry.duration_minutes == 0

    def test_exercise_entry_create_rejects_zero_calories(self):
        """calories_burned must be > 0."""
        from app.api.v1.exercise_schemas import ExerciseEntryCreate

        with pytest.raises((ValidationError, Exception)):
            ExerciseEntryCreate(activity="walking", calories_burned=0)

    def test_exercise_entry_create_rejects_negative_calories(self):
        """calories_burned must not be negative."""
        from app.api.v1.exercise_schemas import ExerciseEntryCreate

        with pytest.raises((ValidationError, Exception)):
            ExerciseEntryCreate(activity="walking", calories_burned=-50)

    def test_exercise_entry_create_rejects_excessive_calories(self):
        """calories_burned must not exceed 10 000."""
        from app.api.v1.exercise_schemas import ExerciseEntryCreate

        with pytest.raises((ValidationError, Exception)):
            ExerciseEntryCreate(activity="marathon", calories_burned=10001)

    def test_exercise_entry_create_rejects_negative_duration(self):
        """duration_minutes must not be negative."""
        from app.api.v1.exercise_schemas import ExerciseEntryCreate

        with pytest.raises((ValidationError, Exception)):
            ExerciseEntryCreate(
                activity="cycling", duration_minutes=-5, calories_burned=200
            )

    def test_exercise_entry_response_fields(self):
        """ExerciseEntryResponse must expose all required fields."""
        from datetime import datetime, timezone
        from app.api.v1.exercise_schemas import ExerciseEntryResponse

        resp = ExerciseEntryResponse(
            id="abc-123",
            activity="swimming",
            duration_minutes=45,
            calories_burned=400,
            logged_at=datetime(2026, 4, 23, 9, 0, tzinfo=timezone.utc),
        )
        assert resp.id == "abc-123"
        assert resp.activity == "swimming"
        assert resp.calories_burned == 400
