"""Tests for POST /api/v1/supplements/scan-label.

Covers:
  - Barcode lookup returns parsed supplement fields
  - Missing both image_base64 and barcode returns 422
  - Unauthenticated request returns 401
"""

from __future__ import annotations

from unittest.mock import AsyncMock, patch

import pytest
from fastapi.testclient import TestClient

from app.api.deps import _get_auth_service, get_authenticated_user_id
from app.database import get_db
from app.main import app
from app.services.auth_service import AuthService

TEST_USER_ID = "test-scan-label-user-001"
AUTH_HEADER = {"Authorization": "Bearer test-scan-label-token"}


# ---------------------------------------------------------------------------
# Shared fixture
# ---------------------------------------------------------------------------


@pytest.fixture
def client_with_auth():
    """TestClient with mocked auth — no real DB or network required."""
    mock_auth = AsyncMock(spec=AuthService)
    mock_auth.get_user = AsyncMock(return_value={"id": TEST_USER_ID})

    app.dependency_overrides[_get_auth_service] = lambda: mock_auth
    app.dependency_overrides[get_authenticated_user_id] = lambda: TEST_USER_ID

    with TestClient(app, raise_server_exceptions=False) as c:
        yield c

    app.dependency_overrides.clear()


@pytest.fixture
def client_no_auth():
    """TestClient with no auth override — tests unauthenticated paths."""
    mock_auth = AsyncMock(spec=AuthService)
    mock_auth.get_user = AsyncMock(return_value=None)

    app.dependency_overrides[_get_auth_service] = lambda: mock_auth

    with TestClient(app, raise_server_exceptions=False) as c:
        yield c

    app.dependency_overrides.clear()


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


def test_scan_label_barcode_returns_fields(client_with_auth: TestClient):
    with patch(
        "app.api.v1.supplements_routes._parse_supplement_barcode",
        new_callable=AsyncMock,
        return_value={
            "name": "Vitamin D3",
            "dose_amount": 5000.0,
            "dose_unit": "IU",
            "form": "softgel",
        },
    ):
        response = client_with_auth.post(
            "/api/v1/supplements/scan-label",
            json={"barcode": "012345678901"},
            headers=AUTH_HEADER,
        )
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "Vitamin D3"
    assert data["dose_amount"] == 5000.0
    assert data["dose_unit"] == "IU"


def test_scan_label_requires_image_or_barcode(client_with_auth: TestClient):
    response = client_with_auth.post(
        "/api/v1/supplements/scan-label",
        json={},
        headers=AUTH_HEADER,
    )
    assert response.status_code == 422


def test_scan_label_requires_auth(client_no_auth: TestClient):
    response = client_no_auth.post(
        "/api/v1/supplements/scan-label",
        json={"barcode": "012345678901"},
    )
    assert response.status_code == 401
