"""
Zuralog Cloud Brain — Emergency Health Card API Route Tests.

Tests for the /api/v1/emergency-card endpoints. Database and auth
operations are fully mocked following the project's established testing
patterns.

Test coverage:
    - GET 404 when card not created
    - PUT creates card
    - GET returns card after creation
    - PUT updates existing card
    - Auth guard returns 401/403
"""

import uuid
from datetime import datetime, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi.testclient import TestClient

from app.api.v1.auth import _get_auth_service
from app.api.v1.deps import get_authenticated_user_id
from app.database import get_db
from app.main import app
from app.services.auth_service import AuthService

TEST_USER_ID = "emergency-card-test-user-001"
AUTH_HEADER = {"Authorization": "Bearer test-token"}
CARD_URL = "/api/v1/emergency-card"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_card(**overrides) -> SimpleNamespace:
    """Build an EmergencyHealthCard-shaped namespace."""
    defaults = dict(
        id=str(uuid.uuid4()),
        user_id=TEST_USER_ID,
        blood_type="O+",
        allergies=["penicillin"],
        medications=None,
        conditions=["Hypertension"],
        emergency_contacts=None,
        updated_at=datetime.now(tz=timezone.utc),
        created_at=datetime.now(tz=timezone.utc),
    )
    defaults.update(overrides)
    return SimpleNamespace(**defaults)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


def _populate_id(obj):
    """Side-effect for mock_db.refresh: assigns a UUID and timestamps if unset."""
    if getattr(obj, "id", None) is None:
        obj.id = str(uuid.uuid4())
    if getattr(obj, "updated_at", None) is None:
        obj.updated_at = datetime.now(tz=timezone.utc)
    if getattr(obj, "created_at", None) is None:
        obj.created_at = datetime.now(tz=timezone.utc)


@pytest.fixture
def client_with_auth():
    """TestClient with mocked auth and database dependencies."""
    mock_auth = AsyncMock(spec=AuthService)
    mock_auth.get_user = AsyncMock(return_value={"id": TEST_USER_ID})

    mock_db = AsyncMock()
    mock_db.add = MagicMock()
    mock_db.commit = AsyncMock()
    mock_db.refresh = AsyncMock(side_effect=_populate_id)

    app.dependency_overrides[_get_auth_service] = lambda: mock_auth
    app.dependency_overrides[get_authenticated_user_id] = lambda: TEST_USER_ID
    app.dependency_overrides[get_db] = lambda: mock_db

    with TestClient(app, raise_server_exceptions=False) as c:
        yield c, mock_db

    app.dependency_overrides.clear()


@pytest.fixture
def client_unauthenticated():
    """TestClient with no auth override."""
    with TestClient(app, raise_server_exceptions=False) as c:
        yield c


# ---------------------------------------------------------------------------
# GET /emergency-card
# ---------------------------------------------------------------------------


class TestGetEmergencyCard:
    def test_get_returns_404_when_not_created(self, client_with_auth):
        """GET /emergency-card returns 404 when no card row exists."""
        client, mock_db = client_with_auth

        mock_result = MagicMock()
        mock_result.scalars.return_value.first.return_value = None
        mock_db.execute = AsyncMock(return_value=mock_result)

        response = client.get(CARD_URL, headers=AUTH_HEADER)
        assert response.status_code == 404

    def test_get_returns_card_after_creation(self, client_with_auth):
        """GET /emergency-card returns 200 with card data when row exists."""
        client, mock_db = client_with_auth

        card = _make_card(blood_type="A+", allergies=["penicillin"])

        mock_result = MagicMock()
        mock_result.scalars.return_value.first.return_value = card
        mock_db.execute = AsyncMock(return_value=mock_result)

        response = client.get(CARD_URL, headers=AUTH_HEADER)
        assert response.status_code == 200
        data = response.json()
        assert data["blood_type"] == "A+"
        assert data["allergies"] == ["penicillin"]
        assert data["user_id"] == TEST_USER_ID


# ---------------------------------------------------------------------------
# PUT /emergency-card
# ---------------------------------------------------------------------------


class TestUpsertEmergencyCard:
    def test_put_creates_card(self, client_with_auth):
        """PUT /emergency-card returns 200 when creating a new card."""
        client, mock_db = client_with_auth

        # No existing row → SELECT returns None → handler creates new row
        mock_result = MagicMock()
        mock_result.scalars.return_value.first.return_value = None
        mock_db.execute = AsyncMock(return_value=mock_result)

        response = client.put(
            CARD_URL,
            json={
                "blood_type": "O-",
                "allergies": ["latex", "aspirin"],
                "conditions": ["Type 2 Diabetes"],
            },
            headers=AUTH_HEADER,
        )
        assert response.status_code == 200
        mock_db.add.assert_called_once()
        mock_db.commit.assert_awaited()

    def test_put_updates_existing_card(self, client_with_auth):
        """PUT /emergency-card updates and returns 200 when row exists."""
        client, mock_db = client_with_auth

        existing_card = _make_card(blood_type="B+")

        mock_result = MagicMock()
        mock_result.scalars.return_value.first.return_value = existing_card
        mock_db.execute = AsyncMock(return_value=mock_result)

        response = client.put(
            CARD_URL,
            json={"blood_type": "AB+", "conditions": ["Hypertension"]},
            headers=AUTH_HEADER,
        )
        assert response.status_code == 200
        # No new row added when updating
        mock_db.add.assert_not_called()
        mock_db.commit.assert_awaited()

    def test_put_with_medications(self, client_with_auth):
        """PUT with medications list is accepted (200)."""
        client, mock_db = client_with_auth

        mock_result = MagicMock()
        mock_result.scalars.return_value.first.return_value = None
        mock_db.execute = AsyncMock(return_value=mock_result)

        response = client.put(
            CARD_URL,
            json={
                "medications": [
                    {"name": "Metformin", "dose": "500mg", "frequency": "twice daily"},
                ]
            },
            headers=AUTH_HEADER,
        )
        assert response.status_code == 200
        mock_db.add.assert_called_once()
        # Verify medications were serialised correctly on the added object
        added_card = mock_db.add.call_args.args[0]
        assert added_card.medications is not None
        assert added_card.medications[0]["name"] == "Metformin"

    def test_put_with_emergency_contacts(self, client_with_auth):
        """PUT with emergency_contacts list is accepted (200)."""
        client, mock_db = client_with_auth

        mock_result = MagicMock()
        mock_result.scalars.return_value.first.return_value = None
        mock_db.execute = AsyncMock(return_value=mock_result)

        response = client.put(
            CARD_URL,
            json={
                "emergency_contacts": [
                    {
                        "name": "Jane Doe",
                        "relationship": "spouse",
                        "phone": "+15551234567",
                    }
                ]
            },
            headers=AUTH_HEADER,
        )
        assert response.status_code == 200
        added_card = mock_db.add.call_args.args[0]
        assert added_card.emergency_contacts[0]["name"] == "Jane Doe"

    def test_put_empty_body_accepted(self, client_with_auth):
        """PUT with empty body creates a card with null fields (200)."""
        client, mock_db = client_with_auth

        mock_result = MagicMock()
        mock_result.scalars.return_value.first.return_value = None
        mock_db.execute = AsyncMock(return_value=mock_result)

        response = client.put(CARD_URL, json={}, headers=AUTH_HEADER)
        assert response.status_code == 200
        mock_db.add.assert_called_once()


# ---------------------------------------------------------------------------
# Auth guard
# ---------------------------------------------------------------------------


class TestAuthGuard:
    def test_get_requires_auth(self, client_unauthenticated):
        """GET /emergency-card without Authorization returns 401/403."""
        response = client_unauthenticated.get(CARD_URL)
        assert response.status_code in (401, 403)

    def test_put_requires_auth(self, client_unauthenticated):
        """PUT /emergency-card without Authorization returns 401/403."""
        response = client_unauthenticated.put(CARD_URL, json={"blood_type": "A+"})
        assert response.status_code in (401, 403)
