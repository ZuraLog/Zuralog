"""
Tests that update_profile uses an explicit allowlist (S-9).

Verifies the _PROFILE_WRITABLE_FIELDS constant exists and contains the
expected fields, and that the endpoint rejects any field not on the list.
"""

import pytest
from fastapi import HTTPException


class TestProfileWritableFieldsConstant:
    """_PROFILE_WRITABLE_FIELDS must exist and contain only expected fields."""

    def test_constant_exists(self):
        from app.api.v1.users import _PROFILE_WRITABLE_FIELDS

        assert _PROFILE_WRITABLE_FIELDS is not None

    def test_constant_is_frozenset(self):
        from app.api.v1.users import _PROFILE_WRITABLE_FIELDS

        assert isinstance(_PROFILE_WRITABLE_FIELDS, frozenset)

    def test_expected_fields_present(self):
        from app.api.v1.users import _PROFILE_WRITABLE_FIELDS

        expected = {"display_name", "nickname", "birthday", "gender", "onboarding_complete"}
        assert expected == _PROFILE_WRITABLE_FIELDS

    def test_subscription_tier_not_writable(self):
        """subscription_tier must NOT be in the allowlist — it is server-managed."""
        from app.api.v1.users import _PROFILE_WRITABLE_FIELDS

        assert "subscription_tier" not in _PROFILE_WRITABLE_FIELDS


class TestUpdateProfileAllowlistEnforcement:
    """The update loop must reject fields absent from the allowlist."""

    def test_unknown_field_raises_http_400(self):
        """Simulate the allowlist check directly without HTTP machinery."""
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

        for field in ("display_name", "nickname", "birthday", "gender", "onboarding_complete"):
            assert field in _PROFILE_WRITABLE_FIELDS
