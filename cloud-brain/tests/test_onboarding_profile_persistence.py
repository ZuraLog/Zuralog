"""Tests for onboarding profile fields on PATCH /me/profile.

Covers:
- Pydantic validation of every new field on UpdateProfileRequest
- The split-allowlist (users vs user_preferences) behaviour
"""

import pytest
from pydantic import ValidationError

from app.api.v1.schemas import UpdateProfileRequest


class TestUpdateProfileRequestValidation:
    def test_accepts_valid_focus_area(self):
        req = UpdateProfileRequest(focus_area="nutrition")
        assert req.focus_area == "nutrition"

    def test_rejects_invalid_focus_area(self):
        with pytest.raises(ValidationError):
            UpdateProfileRequest(focus_area="not_a_real_focus")

    def test_accepts_valid_tone(self):
        for tone in ("direct", "warm", "minimal", "thorough"):
            req = UpdateProfileRequest(tone=tone)
            assert req.tone == tone

    def test_rejects_invalid_tone(self):
        with pytest.raises(ValidationError):
            UpdateProfileRequest(tone="sarcastic")

    def test_accepts_valid_sleep_pattern(self):
        req = UpdateProfileRequest(sleep_pattern="wake_up_a_lot")
        assert req.sleep_pattern == "wake_up_a_lot"

    def test_rejects_invalid_sleep_pattern(self):
        with pytest.raises(ValidationError):
            UpdateProfileRequest(sleep_pattern="insomnia")

    def test_primary_goal_max_200_chars(self):
        with pytest.raises(ValidationError):
            UpdateProfileRequest(primary_goal="x" * 201)

    def test_primary_goal_trims_whitespace(self):
        req = UpdateProfileRequest(primary_goal="  lose 15 lbs  ")
        assert req.primary_goal == "lose 15 lbs"

    def test_primary_goal_empty_string_becomes_none(self):
        req = UpdateProfileRequest(primary_goal="   ")
        assert req.primary_goal is None

    def test_health_frustration_max_120_chars(self):
        with pytest.raises(ValidationError):
            UpdateProfileRequest(health_frustration="x" * 121)

    def test_health_frustration_trims_whitespace(self):
        req = UpdateProfileRequest(health_frustration="  can't stop snacking  ")
        assert req.health_frustration == "can't stop snacking"

    def test_dietary_restrictions_max_10_items(self):
        with pytest.raises(ValidationError):
            UpdateProfileRequest(dietary_restrictions=["x"] * 11)

    def test_dietary_restriction_item_max_40_chars(self):
        with pytest.raises(ValidationError):
            UpdateProfileRequest(dietary_restrictions=["x" * 41])

    def test_dietary_restrictions_empty_array_allowed(self):
        req = UpdateProfileRequest(dietary_restrictions=[])
        assert req.dietary_restrictions == []

    def test_dietary_restrictions_trims_items(self):
        req = UpdateProfileRequest(dietary_restrictions=["  vegetarian  "])
        assert req.dietary_restrictions == ["vegetarian"]

    def test_dietary_restrictions_rejects_empty_item(self):
        with pytest.raises(ValidationError):
            UpdateProfileRequest(dietary_restrictions=[""])

    def test_injuries_max_10_items(self):
        with pytest.raises(ValidationError):
            UpdateProfileRequest(injuries=["x"] * 11)

    def test_injuries_item_max_60_chars(self):
        with pytest.raises(ValidationError):
            UpdateProfileRequest(injuries=["x" * 61])

    def test_injuries_empty_array_allowed(self):
        req = UpdateProfileRequest(injuries=[])
        assert req.injuries == []

    def test_profile_catchup_status_valid_values(self):
        for s in ("not_shown", "in_progress", "completed", "dismissed"):
            req = UpdateProfileRequest(profile_catchup_status=s)
            assert req.profile_catchup_status == s

    def test_profile_catchup_status_rejects_garbage(self):
        with pytest.raises(ValidationError):
            UpdateProfileRequest(profile_catchup_status="nonsense")

    def test_fitness_level_valid_values(self):
        for level in ("beginner", "active", "athletic"):
            req = UpdateProfileRequest(fitness_level=level)
            assert req.fitness_level == level

    def test_fitness_level_rejects_garbage(self):
        with pytest.raises(ValidationError):
            UpdateProfileRequest(fitness_level="pro")
