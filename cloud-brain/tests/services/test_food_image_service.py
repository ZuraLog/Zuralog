"""Unit tests for food_image_service."""
import pytest

from app.services.food_image_service import normalise_query


class TestNormaliseQuery:
    def test_lowercases(self):
        assert normalise_query("EGGS") == "eggs"

    def test_collapses_whitespace(self):
        assert normalise_query("eggs   and   toast") == "eggs and toast"

    def test_strips_leading_trailing_whitespace(self):
        assert normalise_query("   eggs  ") == "eggs"

    def test_strips_punctuation_except_hyphen(self):
        assert normalise_query("Eggs & Toast!") == "eggs toast"
        assert normalise_query("low-carb bagel") == "low-carb bagel"

    def test_collapses_after_punctuation_strip(self):
        # "Eggs , Toast" -> "eggs  toast" -> "eggs toast"
        assert normalise_query("Eggs , Toast") == "eggs toast"

    def test_empty_returns_empty(self):
        assert normalise_query("") == ""
        assert normalise_query("   ") == ""


from unittest.mock import AsyncMock, patch

from app.services.cache_service import CacheService
from app.services.food_image_service import FoodImageService


@pytest.fixture
def cache() -> CacheService:
    return CacheService()


@pytest.fixture
def service(cache: CacheService) -> FoodImageService:
    return FoodImageService(cache=cache, api_key="test-key")


class TestFoodImageServiceFetch:
    @pytest.mark.asyncio
    async def test_empty_query_returns_nulls_without_network(self, service, cache):
        with patch("app.services.food_image_service.httpx.AsyncClient") as client:
            result = await service.fetch("")
        assert result == {"image_url": None, "thumb_url": None}
        client.assert_not_called()

    @pytest.mark.asyncio
    async def test_cache_hit_returns_without_network(self, service, cache):
        await cache.set(
            "food_image:eggs",
            {"image_url": "https://cached.jpg", "thumb_url": "https://cached-tiny.jpg"},
            ttl=60,
        )
        with patch("app.services.food_image_service.httpx.AsyncClient") as client:
            result = await service.fetch("Eggs")
        assert result == {"image_url": "https://cached.jpg", "thumb_url": "https://cached-tiny.jpg"}
        client.assert_not_called()

    @pytest.mark.asyncio
    async def test_cache_miss_calls_pexels_and_caches_positive(self, service, cache):
        pexels_response = {
            "photos": [{
                "src": {
                    "medium": "https://pexels/medium.jpg",
                    "tiny": "https://pexels/tiny.jpg",
                },
            }],
        }
        mock_response = AsyncMock()
        mock_response.status_code = 200
        mock_response.json = lambda: pexels_response
        mock_client = AsyncMock()
        mock_client.__aenter__.return_value = mock_client
        mock_client.get.return_value = mock_response

        with patch(
            "app.services.food_image_service.httpx.AsyncClient", return_value=mock_client
        ):
            result = await service.fetch("eggs")

        assert result == {
            "image_url": "https://pexels/medium.jpg",
            "thumb_url": "https://pexels/tiny.jpg",
        }
        cached = await cache.get("food_image:eggs")
        assert cached == result

    @pytest.mark.asyncio
    async def test_pexels_empty_photos_caches_negative(self, service, cache):
        mock_response = AsyncMock()
        mock_response.status_code = 200
        mock_response.json = lambda: {"photos": []}
        mock_client = AsyncMock()
        mock_client.__aenter__.return_value = mock_client
        mock_client.get.return_value = mock_response

        with patch(
            "app.services.food_image_service.httpx.AsyncClient", return_value=mock_client
        ):
            result = await service.fetch("zorblax")

        assert result == {"image_url": None, "thumb_url": None}
        cached = await cache.get("food_image:zorblax")
        assert cached == {"image_url": None, "thumb_url": None}

    @pytest.mark.asyncio
    async def test_pexels_error_does_not_cache(self, service, cache):
        mock_response = AsyncMock()
        mock_response.status_code = 500
        mock_response.json = lambda: {}
        mock_client = AsyncMock()
        mock_client.__aenter__.return_value = mock_client
        mock_client.get.return_value = mock_response

        with patch(
            "app.services.food_image_service.httpx.AsyncClient", return_value=mock_client
        ):
            result = await service.fetch("eggs")

        assert result == {"image_url": None, "thumb_url": None}
        assert await cache.get("food_image:eggs") is None

    @pytest.mark.asyncio
    async def test_no_api_key_skips_pexels(self, cache):
        service = FoodImageService(cache=cache, api_key="")
        with patch("app.services.food_image_service.httpx.AsyncClient") as client:
            result = await service.fetch("eggs")
        assert result == {"image_url": None, "thumb_url": None}
        client.assert_not_called()
