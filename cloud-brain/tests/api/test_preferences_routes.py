"""
Zuralog Cloud Brain — Tests for Preferences API Routes.

Covers the full GET / PUT / PATCH lifecycle for user preferences,
including lazy creation on first access, full replacement, partial
update, enum validation, and authentication guard.

All database and auth operations are mocked so that no real I/O
occurs during the test run.
"""

import uuid
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from app.api.v1.auth import _get_auth_service
from app.api.v1.deps import get_authenticated_user_id
from app.database import get_db
from app.main import app
from app.models.user_preferences import (
    CoachPersona,
    Theme,
    UnitsSystem,
)
from app.services.auth_service import AuthService

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_TEST_USER_ID = "test-user-pref-001"
_PREFS_URL = "/api/v1/preferences"
_AUTH_HEADER = {"Authorization": "Bearer fake-token"}


def _make_prefs(**overrides) -> SimpleNamespace:
    """Build a UserPreferences-shaped namespace with sensible defaults.

    Uses SimpleNamespace to avoid SQLAlchemy ORM instrumentation errors
    when constructing objects outside a session context.

    The namespace includes a ``to_dict()`` method that mirrors
    ``UserPreferences.to_dict()`` so the route serialisation helpers work.

    Args:
        **overrides: Field values to override on the default object.

    Returns:
        A SimpleNamespace with all UserPreferences fields and a to_dict().
    """
    defaults = dict(
        id=str(uuid.uuid4()),
        user_id=_TEST_USER_ID,
        coach_persona=CoachPersona.BALANCED.value,
        proactivity_level="medium",
        dashboard_layout=None,
        notification_settings=None,
        theme=Theme.DARK.value,
        haptic_enabled=True,
        tooltips_enabled=True,
        onboarding_complete=False,
        morning_briefing_enabled=False,
        morning_briefing_time=None,
        checkin_reminder_enabled=False,
        checkin_reminder_time=None,
        quiet_hours_enabled=False,
        quiet_hours_start=None,
        quiet_hours_end=None,
        goals=None,
        units_system=UnitsSystem.METRIC.value,
        created_at=None,
        updated_at=None,
    )
    defaults.update(overrides)
    ns = SimpleNamespace(**defaults)

    def _to_dict(self=ns) -> dict:
        """Serialise the namespace to a dict as UserPreferences.to_dict() would."""
        return {
            "id": self.id,
            "user_id": self.user_id,
            "coach_persona": self.coach_persona,
            "proactivity_level": self.proactivity_level,
            "dashboard_layout": self.dashboard_layout,
            "notification_settings": self.notification_settings,
            "theme": self.theme,
            "haptic_enabled": self.haptic_enabled,
            "tooltips_enabled": self.tooltips_enabled,
            "onboarding_complete": self.onboarding_complete,
            "morning_briefing_enabled": self.morning_briefing_enabled,
            "morning_briefing_time": None,
            "checkin_reminder_enabled": self.checkin_reminder_enabled,
            "checkin_reminder_time": None,
            "quiet_hours_enabled": self.quiet_hours_enabled,
            "quiet_hours_start": None,
            "quiet_hours_end": None,
            "goals": self.goals,
            "units_system": self.units_system,
            "created_at": None,
            "updated_at": None,
        }

    ns.to_dict = _to_dict
    return ns


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
def client_with_auth():
    """TestClient with mocked auth and database dependencies.

    Yields:
        tuple: (TestClient, mock_db) for use inside test functions.
    """
    mock_auth = AsyncMock(spec=AuthService)
    mock_auth.get_user = AsyncMock(return_value={"id": _TEST_USER_ID})

    mock_db = AsyncMock()
    mock_db.add = MagicMock()
    mock_db.commit = AsyncMock()
    mock_db.refresh = AsyncMock()

    # Override both the low-level auth service and the high-level dep.
    app.dependency_overrides[_get_auth_service] = lambda: mock_auth
    app.dependency_overrides[get_authenticated_user_id] = lambda: _TEST_USER_ID
    app.dependency_overrides[get_db] = lambda: mock_db

    with TestClient(app, raise_server_exceptions=False) as c:
        yield c, mock_db

    app.dependency_overrides.clear()


@pytest.fixture
def client_unauthenticated():
    """TestClient with NO auth override (triggers 401).

    Yields:
        TestClient: The unmodified app client.
    """
    with TestClient(app, raise_server_exceptions=False) as c:
        yield c


# ---------------------------------------------------------------------------
# Tests — GET /preferences
# ---------------------------------------------------------------------------


def test_get_creates_defaults_on_first_access(client_with_auth):
    """GET should create a default preferences row when none exists.

    The endpoint must:
    - Call db.execute to attempt a SELECT.
    - Add a new UserPreferences row to the session.
    - Commit and refresh.
    - Return 200 with a valid PreferencesResponse.
    """
    client, mock_db = client_with_auth

    # scalar_one_or_none returns None → no existing row.
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = None
    mock_db.execute = AsyncMock(return_value=mock_result)

    mock_db.refresh = AsyncMock()  # no-op; the ORM object is already mutated by the handler

    # Patch app.state.cache_service to avoid upstash calls.
    with patch.object(app.state, "cache_service", None, create=True):
        resp = client.get(_PREFS_URL, headers=_AUTH_HEADER)

    assert resp.status_code == 200
    data = resp.json()
    assert data["user_id"] == _TEST_USER_ID
    assert data["coach_persona"] == CoachPersona.BALANCED.value
    assert data["theme"] == Theme.DARK.value
    mock_db.add.assert_called_once()
    mock_db.commit.assert_awaited_once()


def test_get_returns_existing_preferences(client_with_auth):
    """GET should return the existing row without touching the database writer.

    The endpoint must:
    - Find an existing row via SELECT.
    - NOT call db.add or db.commit.
    - Return 200 with the stored values.
    """
    client, mock_db = client_with_auth

    existing = _make_prefs(
        coach_persona=CoachPersona.TOUGH_LOVE.value,
        theme=Theme.LIGHT.value,
        units_system=UnitsSystem.IMPERIAL.value,
    )

    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = existing
    mock_db.execute = AsyncMock(return_value=mock_result)

    with patch.object(app.state, "cache_service", None, create=True):
        resp = client.get(_PREFS_URL, headers=_AUTH_HEADER)

    assert resp.status_code == 200
    data = resp.json()
    assert data["coach_persona"] == CoachPersona.TOUGH_LOVE.value
    assert data["theme"] == Theme.LIGHT.value
    assert data["units_system"] == UnitsSystem.IMPERIAL.value
    mock_db.add.assert_not_called()
    mock_db.commit.assert_not_awaited()


# ---------------------------------------------------------------------------
# Tests — PUT /preferences
# ---------------------------------------------------------------------------


def test_put_replaces_preferences(client_with_auth):
    """PUT should write all provided fields and return the updated row.

    The endpoint must overwrite every field supplied in the body and
    return 200 with the new values.
    """
    client, mock_db = client_with_auth

    stored = _make_prefs()
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = stored
    mock_db.execute = AsyncMock(return_value=mock_result)
    mock_db.refresh = AsyncMock()  # no-op; setattr already ran on the stored namespace

    payload = {
        "theme": Theme.LIGHT.value,
        "units_system": UnitsSystem.IMPERIAL.value,
        "coach_persona": CoachPersona.GENTLE.value,
    }

    with patch.object(app.state, "cache_service", None, create=True):
        resp = client.put(_PREFS_URL, json=payload, headers=_AUTH_HEADER)

    assert resp.status_code == 200
    mock_db.commit.assert_awaited_once()


# ---------------------------------------------------------------------------
# Tests — PATCH /preferences
# ---------------------------------------------------------------------------


def test_patch_updates_only_provided_fields(client_with_auth):
    """PATCH should update only the fields present in the body.

    Fields absent from the body must remain unchanged on the stored row.
    """
    client, mock_db = client_with_auth

    stored = _make_prefs(haptic_enabled=True, tooltips_enabled=True)
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = stored
    mock_db.execute = AsyncMock(return_value=mock_result)
    # refresh is a no-op: setattr already mutated `stored` before refresh is called.
    mock_db.refresh = AsyncMock()

    payload = {"haptic_enabled": False}

    with patch.object(app.state, "cache_service", None, create=True):
        resp = client.patch(_PREFS_URL, json=payload, headers=_AUTH_HEADER)

    assert resp.status_code == 200
    # haptic_enabled must have been updated on the stored namespace.
    assert stored.haptic_enabled is False
    # tooltips_enabled must not have been touched.
    assert stored.tooltips_enabled is True
    mock_db.commit.assert_awaited_once()


def test_patch_invalid_enum_returns_422(client_with_auth):
    """PATCH with an unrecognised enum value must return HTTP 422.

    Pydantic validation should reject the value before hitting the DB.
    """
    client, _ = client_with_auth

    payload = {"theme": "neon_pink"}

    with patch.object(app.state, "cache_service", None, create=True):
        resp = client.patch(_PREFS_URL, json=payload, headers=_AUTH_HEADER)

    assert resp.status_code == 422


def test_patch_with_no_fields_returns_400(client_with_auth):
    """PATCH with an empty body must return HTTP 400.

    The endpoint requires at least one field to be updated.
    """
    client, mock_db = client_with_auth

    stored = _make_prefs()
    mock_result = MagicMock()
    mock_result.scalar_one_or_none.return_value = stored
    mock_db.execute = AsyncMock(return_value=mock_result)

    with patch.object(app.state, "cache_service", None, create=True):
        resp = client.patch(_PREFS_URL, json={}, headers=_AUTH_HEADER)

    assert resp.status_code == 400


# ---------------------------------------------------------------------------
# Tests — Authentication guard
# ---------------------------------------------------------------------------


def test_unauthenticated_request_returns_401(client_unauthenticated):
    """Requests without a valid Bearer token must receive HTTP 401.

    No database access should occur for unauthenticated callers.
    """
    resp = client_unauthenticated.get(_PREFS_URL)
    assert resp.status_code == 401
