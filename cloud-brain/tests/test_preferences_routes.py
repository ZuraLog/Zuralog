"""
Zuralog Cloud Brain — Tests for GET/PUT/PATCH /api/v1/preferences.

Uses the shared ``integration_client`` fixture (from conftest.py) that
wires up mocked AuthService and DB session so no real database is needed.

The route-level helper ``_get_or_create_prefs`` is patched directly to
control exactly which ORM object the endpoints operate on.

Coverage:
  - GET returns defaults when no row exists yet (upsert on first access)
  - GET returns the stored values when a row already exists
  - PUT overwrites all provided fields
  - PATCH only updates the specified fields, leaving others unchanged
  - 401 is returned when no Authorization header is sent
  - PATCH leaves unset fields at their original values
"""

from unittest.mock import AsyncMock, MagicMock

import pytest


# ---------------------------------------------------------------------------
# Shared test data
# ---------------------------------------------------------------------------

USER_ID = "user-pref-001"
AUTH_HEADERS = {"Authorization": "Bearer test-token"}


def _make_prefs_orm(overrides: dict | None = None):
    """Return a mock UserPreferences ORM instance with default field values.

    Args:
        overrides: Optional dict of field-name → value pairs to apply on
            top of the defaults.

    Returns:
        A :class:`MagicMock` with spec :class:`UserPreferences` and all
        required attributes populated.
    """
    from app.models.user_preferences import UserPreferences

    prefs = MagicMock(spec=UserPreferences)
    prefs.user_id = USER_ID
    prefs.coach_persona = "balanced"
    prefs.proactivity_level = "medium"
    prefs.dashboard_layout = {}
    prefs.notification_settings = {}
    prefs.theme = "system"
    prefs.haptic_enabled = True
    prefs.tooltips_enabled = True
    prefs.onboarding_complete = False
    prefs.morning_briefing_time = None
    prefs.checkin_reminder_time = None
    prefs.quiet_hours_start = None
    prefs.quiet_hours_end = None
    prefs.goals = []
    prefs.response_length = "concise"
    prefs.suggested_prompts_enabled = True
    prefs.voice_input_enabled = True
    prefs.wellness_checkin_card_visible = True
    prefs.data_maturity_banner_dismissed = False
    prefs.analytics_opt_out = False
    prefs.memory_enabled = True
    prefs.morning_briefing_enabled = True
    prefs.checkin_reminder_enabled = False
    prefs.quiet_hours_enabled = False
    prefs.units_system = "metric"
    prefs.fitness_level = None

    if overrides:
        for key, value in overrides.items():
            setattr(prefs, key, value)

    return prefs


def _make_user_orm():
    """Return a mock User ORM instance used by get_current_user."""
    from app.models.user import User

    user = MagicMock(spec=User)
    user.id = USER_ID
    user.subscription_tier = "free"
    return user


# ---------------------------------------------------------------------------
# GET /api/v1/preferences
# ---------------------------------------------------------------------------


def test_get_preferences_creates_defaults(integration_client):
    """GET on a fresh user should auto-create preferences with defaults and return them."""
    client, mock_auth, mock_db = integration_client

    mock_auth.get_user.return_value = {"id": USER_ID}

    # DB returns no existing user row (get_current_user lookup)
    mock_user = _make_user_orm()
    mock_user_result = MagicMock()
    mock_user_result.scalar_one_or_none.return_value = mock_user

    new_prefs = _make_prefs_orm()

    from unittest.mock import patch

    with patch(
        "app.api.v1.preferences_routes._get_or_create_prefs",
        new_callable=AsyncMock,
        return_value=new_prefs,
    ):
        mock_db.execute = AsyncMock(return_value=mock_user_result)
        response = client.get("/api/v1/preferences", headers=AUTH_HEADERS)

    assert response.status_code == 200
    data = response.json()
    assert data["user_id"] == USER_ID
    assert data["coach_persona"] == "balanced"
    assert data["proactivity_level"] == "medium"
    assert data["theme"] == "system"
    assert data["haptic_enabled"] is True
    assert data["tooltips_enabled"] is True
    assert data["onboarding_complete"] is False
    assert data["goals"] == []


def test_get_preferences_returns_existing(integration_client):
    """GET should return previously stored values when a preferences row exists."""
    client, mock_auth, mock_db = integration_client

    mock_auth.get_user.return_value = {"id": USER_ID}

    mock_user = _make_user_orm()
    mock_user_result = MagicMock()
    mock_user_result.scalar_one_or_none.return_value = mock_user

    existing_prefs = _make_prefs_orm(
        {
            "coach_persona": "tough_love",
            "theme": "light",
            "onboarding_complete": True,
            "proactivity_level": "high",
        }
    )

    from unittest.mock import patch

    with patch(
        "app.api.v1.preferences_routes._get_or_create_prefs",
        new_callable=AsyncMock,
        return_value=existing_prefs,
    ):
        mock_db.execute = AsyncMock(return_value=mock_user_result)
        response = client.get("/api/v1/preferences", headers=AUTH_HEADERS)

    assert response.status_code == 200
    data = response.json()
    assert data["coach_persona"] == "tough_love"
    assert data["theme"] == "light"
    assert data["onboarding_complete"] is True
    assert data["proactivity_level"] == "high"


# ---------------------------------------------------------------------------
# PUT /api/v1/preferences
# ---------------------------------------------------------------------------


def test_put_preferences_full_replace(integration_client):
    """PUT should overwrite all provided fields on the preferences row."""
    client, mock_auth, mock_db = integration_client

    mock_auth.get_user.return_value = {"id": USER_ID}

    mock_user = _make_user_orm()
    mock_user_result = MagicMock()
    mock_user_result.scalar_one_or_none.return_value = mock_user

    prefs = _make_prefs_orm()
    mock_db.commit = AsyncMock()
    mock_db.refresh = AsyncMock()

    from unittest.mock import patch

    with patch(
        "app.api.v1.preferences_routes._get_or_create_prefs",
        new_callable=AsyncMock,
        return_value=prefs,
    ):
        mock_db.execute = AsyncMock(return_value=mock_user_result)
        response = client.put(
            "/api/v1/preferences",
            json={
                "coach_persona": "gentle",
                "theme": "dark",
                "onboarding_complete": True,
                "proactivity_level": "low",
                "haptic_enabled": False,
            },
            headers=AUTH_HEADERS,
        )

    assert response.status_code == 200
    assert prefs.coach_persona == "gentle"
    assert prefs.theme == "dark"
    assert prefs.onboarding_complete is True
    assert prefs.proactivity_level == "low"
    assert prefs.haptic_enabled is False


# ---------------------------------------------------------------------------
# PATCH /api/v1/preferences
# ---------------------------------------------------------------------------


def test_patch_preferences_partial_update(integration_client):
    """PATCH should update only the specified fields."""
    client, mock_auth, mock_db = integration_client

    mock_auth.get_user.return_value = {"id": USER_ID}

    mock_user = _make_user_orm()
    mock_user_result = MagicMock()
    mock_user_result.scalar_one_or_none.return_value = mock_user

    prefs = _make_prefs_orm()
    mock_db.commit = AsyncMock()
    mock_db.refresh = AsyncMock()

    from unittest.mock import patch

    with patch(
        "app.api.v1.preferences_routes._get_or_create_prefs",
        new_callable=AsyncMock,
        return_value=prefs,
    ):
        mock_db.execute = AsyncMock(return_value=mock_user_result)
        response = client.patch(
            "/api/v1/preferences",
            json={"coach_persona": "tough_love", "tooltips_enabled": False},
            headers=AUTH_HEADERS,
        )

    assert response.status_code == 200
    assert prefs.coach_persona == "tough_love"
    assert prefs.tooltips_enabled is False


def test_preferences_auth_required(integration_client):
    """GET without an Authorization header should return 401 or 403 (no bearer token)."""
    client, _, _ = integration_client

    response = client.get("/api/v1/preferences")
    assert response.status_code in (401, 403)


def test_patch_preserves_unset_fields(integration_client):
    """PATCH should leave fields not included in the body completely unchanged."""
    client, mock_auth, mock_db = integration_client

    mock_auth.get_user.return_value = {"id": USER_ID}

    mock_user = _make_user_orm()
    mock_user_result = MagicMock()
    mock_user_result.scalar_one_or_none.return_value = mock_user

    prefs = _make_prefs_orm(
        {
            "haptic_enabled": True,
            "tooltips_enabled": True,
            "proactivity_level": "high",
            "theme": "dark",
        }
    )
    mock_db.commit = AsyncMock()
    mock_db.refresh = AsyncMock()

    from unittest.mock import patch

    with patch(
        "app.api.v1.preferences_routes._get_or_create_prefs",
        new_callable=AsyncMock,
        return_value=prefs,
    ):
        mock_db.execute = AsyncMock(return_value=mock_user_result)
        response = client.patch(
            "/api/v1/preferences",
            # Only update coach_persona — all other fields must stay as-is
            json={"coach_persona": "gentle"},
            headers=AUTH_HEADERS,
        )

    assert response.status_code == 200
    assert prefs.coach_persona == "gentle"
    # These fields were NOT in the PATCH body and must remain unchanged
    assert prefs.haptic_enabled is True
    assert prefs.tooltips_enabled is True
    assert prefs.proactivity_level == "high"
    assert prefs.theme == "dark"


def test_get_preferences_returns_coach_fields(integration_client):
    """GET should return response_length, suggested_prompts_enabled, voice_input_enabled."""
    client, mock_auth, mock_db = integration_client

    mock_auth.get_user.return_value = {"id": USER_ID}
    mock_user = _make_user_orm()
    mock_user_result = MagicMock()
    mock_user_result.scalar_one_or_none.return_value = mock_user

    prefs = _make_prefs_orm({
        "response_length": "detailed",
        "suggested_prompts_enabled": False,
        "voice_input_enabled": False,
    })

    from unittest.mock import patch

    with patch(
        "app.api.v1.preferences_routes._get_or_create_prefs",
        new_callable=AsyncMock,
        return_value=prefs,
    ):
        mock_db.execute = AsyncMock(return_value=mock_user_result)
        response = client.get("/api/v1/preferences", headers=AUTH_HEADERS)

    assert response.status_code == 200
    data = response.json()
    assert data["response_length"] == "detailed"
    assert data["suggested_prompts_enabled"] is False
    assert data["voice_input_enabled"] is False


def test_patch_response_length_validation(integration_client):
    """PATCH with invalid response_length should return 400."""
    client, mock_auth, mock_db = integration_client

    mock_auth.get_user.return_value = {"id": USER_ID}
    mock_user = _make_user_orm()
    mock_user_result = MagicMock()
    mock_user_result.scalar_one_or_none.return_value = mock_user

    prefs = _make_prefs_orm()
    mock_db.commit = AsyncMock()
    mock_db.refresh = AsyncMock()

    from unittest.mock import patch

    with patch(
        "app.api.v1.preferences_routes._get_or_create_prefs",
        new_callable=AsyncMock,
        return_value=prefs,
    ):
        mock_db.execute = AsyncMock(return_value=mock_user_result)
        response = client.patch(
            "/api/v1/preferences",
            json={"response_length": "verbose"},  # invalid value
            headers=AUTH_HEADERS,
        )

    assert response.status_code == 400
    assert "response_length" in response.json()["detail"]


def test_patch_memory_enabled(integration_client):
    """PATCH /preferences can toggle memory_enabled."""
    client, mock_auth, mock_db = integration_client

    mock_auth.get_user.return_value = {"id": USER_ID}
    mock_user = _make_user_orm()
    mock_user_result = MagicMock()
    mock_user_result.scalar_one_or_none.return_value = mock_user

    prefs = _make_prefs_orm()
    mock_db.commit = AsyncMock()
    mock_db.refresh = AsyncMock()

    from unittest.mock import patch

    with patch(
        "app.api.v1.preferences_routes._get_or_create_prefs",
        new_callable=AsyncMock,
        return_value=prefs,
    ):
        mock_db.execute = AsyncMock(return_value=mock_user_result)
        response = client.patch(
            "/api/v1/preferences",
            json={"memory_enabled": False},
            headers=AUTH_HEADERS,
        )

    assert response.status_code == 200
    assert response.json()["memory_enabled"] is False
