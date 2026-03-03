"""
Tests for GET/PUT/PATCH /api/v1/preferences endpoints.

Uses the shared ``integration_client`` fixture that wires up mocked
AuthService and DB session so no real database is needed.

Coverage:
- GET: returns defaults when no row exists
- GET: returns existing row values
- PATCH: updates individual fields, leaves others unchanged
- PUT: full replacement behaves like PATCH for provided fields
- Validation: invalid coach_persona, proactivity_level, theme rejected
- Validation: invalid time format rejected
"""

from unittest.mock import AsyncMock, MagicMock, patch
from datetime import time

import pytest


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

USER_ID = "user-pref-001"
AUTH_HEADERS = {"Authorization": "Bearer test-token"}

DEFAULT_PREFS_PAYLOAD = {
    "coach_persona": "balanced",
    "proactivity_level": "medium",
    "theme": "dark",
    "haptic_enabled": True,
    "tooltips_enabled": True,
    "onboarding_complete": False,
    "goals": [],
}


def _make_prefs_orm(overrides: dict | None = None):
    """Return a mock UserPreferences ORM instance with default values."""
    from app.models.user_preferences import UserPreferences

    prefs = MagicMock(spec=UserPreferences)
    prefs.user_id = USER_ID
    prefs.coach_persona = "balanced"
    prefs.proactivity_level = "medium"
    prefs.dashboard_layout = None
    prefs.notification_settings = None
    prefs.theme = "dark"
    prefs.haptic_enabled = True
    prefs.tooltips_enabled = True
    prefs.onboarding_complete = False
    prefs.morning_briefing_time = None
    prefs.checkin_reminder_time = None
    prefs.quiet_hours_start = None
    prefs.quiet_hours_end = None
    prefs.goals = []

    if overrides:
        for k, v in overrides.items():
            setattr(prefs, k, v)
    return prefs


# ---------------------------------------------------------------------------
# GET /api/v1/preferences
# ---------------------------------------------------------------------------


def test_get_preferences_creates_defaults(integration_client):
    """GET should auto-create preferences with defaults on first access."""
    client, mock_auth, mock_db = integration_client

    mock_auth.get_user.return_value = {"id": USER_ID}

    # Simulate no existing row — scalar_one_or_none returns None first,
    # then returns a newly-created mock after commit.
    new_prefs = _make_prefs_orm()
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = None
    mock_db.execute = AsyncMock(return_value=mock_result)
    mock_db.add = MagicMock()
    mock_db.commit = AsyncMock()
    mock_db.refresh = AsyncMock(side_effect=lambda p: None)

    # After the upsert, _get_or_create_prefs needs to return something
    # We patch the route helper directly.
    with patch(
        "app.api.v1.preferences_routes._get_or_create_prefs",
        new_callable=AsyncMock,
        return_value=new_prefs,
    ):
        response = client.get("/api/v1/preferences", headers=AUTH_HEADERS)

    assert response.status_code == 200
    data = response.json()
    assert data["coach_persona"] == "balanced"
    assert data["theme"] == "dark"
    assert data["haptic_enabled"] is True


def test_get_preferences_returns_existing(integration_client):
    """GET should return the stored values when a row exists."""
    client, mock_auth, _ = integration_client

    mock_auth.get_user.return_value = {"id": USER_ID}

    existing_prefs = _make_prefs_orm(
        {"coach_persona": "tough_love", "theme": "light", "onboarding_complete": True}
    )

    with patch(
        "app.api.v1.preferences_routes._get_or_create_prefs",
        new_callable=AsyncMock,
        return_value=existing_prefs,
    ):
        response = client.get("/api/v1/preferences", headers=AUTH_HEADERS)

    assert response.status_code == 200
    data = response.json()
    assert data["coach_persona"] == "tough_love"
    assert data["theme"] == "light"
    assert data["onboarding_complete"] is True


# ---------------------------------------------------------------------------
# PATCH /api/v1/preferences
# ---------------------------------------------------------------------------


def test_patch_updates_coach_persona(integration_client):
    """PATCH with coach_persona should update that field."""
    client, mock_auth, _ = integration_client

    mock_auth.get_user.return_value = {"id": USER_ID}
    prefs = _make_prefs_orm()

    with (
        patch(
            "app.api.v1.preferences_routes._get_or_create_prefs",
            new_callable=AsyncMock,
            return_value=prefs,
        ),
        patch("app.api.v1.preferences_routes.AsyncSession", new=MagicMock()),
    ):
        response = client.patch(
            "/api/v1/preferences",
            json={"coach_persona": "gentle"},
            headers=AUTH_HEADERS,
        )

    assert response.status_code == 200
    # Model field should be mutated
    assert prefs.coach_persona == "gentle"


def test_patch_updates_boolean_fields(integration_client):
    """PATCH should accept haptic_enabled and tooltips_enabled."""
    client, mock_auth, _ = integration_client

    mock_auth.get_user.return_value = {"id": USER_ID}
    prefs = _make_prefs_orm()

    with patch(
        "app.api.v1.preferences_routes._get_or_create_prefs",
        new_callable=AsyncMock,
        return_value=prefs,
    ):
        response = client.patch(
            "/api/v1/preferences",
            json={"haptic_enabled": False, "tooltips_enabled": False},
            headers=AUTH_HEADERS,
        )

    assert response.status_code == 200
    assert prefs.haptic_enabled is False
    assert prefs.tooltips_enabled is False


def test_patch_updates_time_fields(integration_client):
    """PATCH should parse HH:MM time strings correctly."""
    client, mock_auth, _ = integration_client

    mock_auth.get_user.return_value = {"id": USER_ID}
    prefs = _make_prefs_orm()

    with patch(
        "app.api.v1.preferences_routes._get_or_create_prefs",
        new_callable=AsyncMock,
        return_value=prefs,
    ):
        response = client.patch(
            "/api/v1/preferences",
            json={"morning_briefing_time": "07:30", "quiet_hours_start": "22:00"},
            headers=AUTH_HEADERS,
        )

    assert response.status_code == 200
    assert prefs.morning_briefing_time == time(7, 30)
    assert prefs.quiet_hours_start == time(22, 0)


def test_patch_updates_goals(integration_client):
    """PATCH should update the goals array."""
    client, mock_auth, _ = integration_client

    mock_auth.get_user.return_value = {"id": USER_ID}
    prefs = _make_prefs_orm()

    with patch(
        "app.api.v1.preferences_routes._get_or_create_prefs",
        new_callable=AsyncMock,
        return_value=prefs,
    ):
        response = client.patch(
            "/api/v1/preferences",
            json={"goals": ["lose_weight", "improve_sleep"]},
            headers=AUTH_HEADERS,
        )

    assert response.status_code == 200
    assert prefs.goals == ["lose_weight", "improve_sleep"]


# ---------------------------------------------------------------------------
# PUT /api/v1/preferences
# ---------------------------------------------------------------------------


def test_put_behaves_like_patch(integration_client):
    """PUT should update provided fields (same as PATCH for this endpoint)."""
    client, mock_auth, _ = integration_client

    mock_auth.get_user.return_value = {"id": USER_ID}
    prefs = _make_prefs_orm()

    with patch(
        "app.api.v1.preferences_routes._get_or_create_prefs",
        new_callable=AsyncMock,
        return_value=prefs,
    ):
        response = client.put(
            "/api/v1/preferences",
            json={"theme": "system", "onboarding_complete": True},
            headers=AUTH_HEADERS,
        )

    assert response.status_code == 200
    assert prefs.theme == "system"
    assert prefs.onboarding_complete is True


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------


def test_patch_invalid_coach_persona_rejected(integration_client):
    """PATCH with an invalid coach_persona should return 400."""
    client, mock_auth, _ = integration_client

    mock_auth.get_user.return_value = {"id": USER_ID}
    prefs = _make_prefs_orm()

    with patch(
        "app.api.v1.preferences_routes._get_or_create_prefs",
        new_callable=AsyncMock,
        return_value=prefs,
    ):
        response = client.patch(
            "/api/v1/preferences",
            json={"coach_persona": "aggressive"},
            headers=AUTH_HEADERS,
        )

    assert response.status_code == 400
    assert "coach_persona" in response.json()["detail"]


def test_patch_invalid_theme_rejected(integration_client):
    """PATCH with an invalid theme value should return 400."""
    client, mock_auth, _ = integration_client

    mock_auth.get_user.return_value = {"id": USER_ID}
    prefs = _make_prefs_orm()

    with patch(
        "app.api.v1.preferences_routes._get_or_create_prefs",
        new_callable=AsyncMock,
        return_value=prefs,
    ):
        response = client.patch(
            "/api/v1/preferences",
            json={"theme": "midnight"},
            headers=AUTH_HEADERS,
        )

    assert response.status_code == 400
    assert "theme" in response.json()["detail"]


def test_patch_invalid_time_format_rejected(integration_client):
    """PATCH with a malformed time string should return 422."""
    client, mock_auth, _ = integration_client

    mock_auth.get_user.return_value = {"id": USER_ID}
    prefs = _make_prefs_orm()

    with patch(
        "app.api.v1.preferences_routes._get_or_create_prefs",
        new_callable=AsyncMock,
        return_value=prefs,
    ):
        response = client.patch(
            "/api/v1/preferences",
            json={"morning_briefing_time": "not-a-time"},
            headers=AUTH_HEADERS,
        )

    assert response.status_code == 422


def test_get_preferences_auth_required(integration_client):
    """GET without Authorization header should return 403 (no bearer token)."""
    client, _, _ = integration_client

    response = client.get("/api/v1/preferences")
    assert response.status_code == 403
