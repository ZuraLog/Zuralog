"""API tests for GET /api/v1/nutrition/food-image."""
from unittest.mock import AsyncMock, patch

import pytest
from fastapi.testclient import TestClient

from app.api.deps import get_authenticated_user_id
from app.main import app


TEST_USER_ID = "food-image-test-user"
AUTH_HEADER = {"Authorization": "Bearer test-token"}


@pytest.fixture
def client_with_auth():
    app.dependency_overrides[get_authenticated_user_id] = lambda: TEST_USER_ID
    with TestClient(app, raise_server_exceptions=False) as c:
        yield c
    app.dependency_overrides.clear()


@pytest.fixture
def client_unauthenticated():
    with TestClient(app, raise_server_exceptions=False) as c:
        yield c


class TestFoodImageEndpoint:
    def test_returns_urls_from_service(self, client_with_auth):
        with patch(
            "app.api.v1.nutrition_routes.FoodImageService.fetch",
            new=AsyncMock(return_value={
                "image_url": "https://pexels/medium.jpg",
                "thumb_url": "https://pexels/tiny.jpg",
            }),
        ):
            r = client_with_auth.get(
                "/api/v1/nutrition/food-image",
                params={"q": "eggs"},
                headers=AUTH_HEADER,
            )
        assert r.status_code == 200
        assert r.json() == {
            "image_url": "https://pexels/medium.jpg",
            "thumb_url": "https://pexels/tiny.jpg",
        }

    def test_empty_query_returns_400(self, client_with_auth):
        r = client_with_auth.get(
            "/api/v1/nutrition/food-image",
            params={"q": ""},
            headers=AUTH_HEADER,
        )
        assert r.status_code == 400

    def test_whitespace_query_returns_400(self, client_with_auth):
        r = client_with_auth.get(
            "/api/v1/nutrition/food-image",
            params={"q": "   "},
            headers=AUTH_HEADER,
        )
        assert r.status_code == 400

    def test_long_query_returns_400(self, client_with_auth):
        r = client_with_auth.get(
            "/api/v1/nutrition/food-image",
            params={"q": "x" * 201},
            headers=AUTH_HEADER,
        )
        assert r.status_code == 400

    def test_unauthenticated_returns_auth_error(self, client_unauthenticated):
        r = client_unauthenticated.get(
            "/api/v1/nutrition/food-image",
            params={"q": "eggs"},
        )
        assert r.status_code in (401, 403)
