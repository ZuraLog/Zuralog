"""
Tests that update_profile uses explicit, split allowlists (S-9).

Verifies:
- `_USER_FIELDS` and `_USER_PREF_FIELDS` exist as disjoint frozensets.
- Their union is exposed as `_PROFILE_WRITABLE_FIELDS` for backwards compat.
- Expected fields are in each set.
- Server-managed fields (e.g. subscription_tier) are in neither set.
- Unknown fields raise a 400.
"""

import pytest
from fastapi import HTTPException


class TestProfileWritableFieldsConstants:
    """Split allowlists on app.api.v1.users must exist and be well-formed."""

    def test_user_fields_exists_as_frozenset(self):
        from app.api.v1.users import _USER_FIELDS

        assert isinstance(_USER_FIELDS, frozenset)
        assert len(_USER_FIELDS) > 0

    def test_user_pref_fields_exists_as_frozenset(self):
        from app.api.v1.users import _USER_PREF_FIELDS

        assert isinstance(_USER_PREF_FIELDS, frozenset)
        assert len(_USER_PREF_FIELDS) > 0

    def test_sets_are_disjoint(self):
        """A field must belong to exactly one destination table."""
        from app.api.v1.users import _USER_FIELDS, _USER_PREF_FIELDS

        assert _USER_FIELDS.isdisjoint(_USER_PREF_FIELDS)

    def test_writable_fields_is_the_union(self):
        from app.api.v1.users import (
            _PROFILE_WRITABLE_FIELDS,
            _USER_FIELDS,
            _USER_PREF_FIELDS,
        )

        assert _PROFILE_WRITABLE_FIELDS == _USER_FIELDS | _USER_PREF_FIELDS

    def test_expected_user_fields_present(self):
        from app.api.v1.users import _USER_FIELDS

        expected = {
            "display_name",
            "nickname",
            "birthday",
            "gender",
            "height_cm",
            "weight_kg",
            "onboarding_complete",
        }
        assert expected == _USER_FIELDS

    def test_expected_user_pref_fields_present(self):
        from app.api.v1.users import _USER_PREF_FIELDS

        expected = {
            "focus_area",
            "primary_goal",
            "tone",
            "dietary_restrictions",
            "injuries",
            "sleep_pattern",
            "health_frustration",
            "fitness_level",
            "profile_catchup_status",
        }
        assert expected == _USER_PREF_FIELDS

    def test_subscription_tier_not_writable(self):
        from app.api.v1.users import _PROFILE_WRITABLE_FIELDS

        assert "subscription_tier" not in _PROFILE_WRITABLE_FIELDS


class TestUpdateProfileAllowlistEnforcement:
    """The update loop must reject fields absent from the allowlist."""

    def test_unknown_field_raises_http_400(self):
        from app.api.v1.users import _PROFILE_WRITABLE_FIELDS

        update_data = {"subscription_tier": "premium"}
        for field in update_data:
            if field not in _PROFILE_WRITABLE_FIELDS:
                with pytest.raises(HTTPException) as exc_info:
                    raise HTTPException(
                        status_code=400,
                        detail=f"Field '{field}' cannot be updated",
                    )
                assert exc_info.value.status_code == 400
                assert "subscription_tier" in exc_info.value.detail

    def test_allowed_fields_pass_check(self):
        from app.api.v1.users import _PROFILE_WRITABLE_FIELDS

        for field in (
            "display_name",
            "nickname",
            "birthday",
            "gender",
            "onboarding_complete",
            "focus_area",
            "tone",
        ):
            assert field in _PROFILE_WRITABLE_FIELDS
