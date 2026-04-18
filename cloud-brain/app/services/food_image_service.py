"""Food image service.

Resolves a food description (e.g. "eggs with toast") to a stock photo URL
via Pexels, cached by normalised query. Used by the meal-parse loading
state to show contextual imagery while the AI parses the description.
"""
from __future__ import annotations

import logging
import re
from typing import Any

import httpx

from app.services.cache_service import CacheService

logger = logging.getLogger(__name__)

_PUNCT_RE = re.compile(r"[^\w\s-]")  # keep letters/digits/_, whitespace, hyphen
_WHITESPACE_RE = re.compile(r"\s+")

_PEXELS_URL = "https://api.pexels.com/v1/search"
_POSITIVE_TTL = 60 * 60 * 24 * 7  # 7 days
_NEGATIVE_TTL = 60 * 60 * 24  # 1 day
_TIMEOUT_S = 4.0
_CACHE_PREFIX = "food_image:"


class FoodImageService:
    """Resolves a food description to a stock-photo URL with in-memory caching.

    Dependencies are injected so the service is easy to unit-test and swap
    providers later if needed.
    """

    def __init__(self, cache: CacheService, api_key: str) -> None:
        self._cache = cache
        self._api_key = api_key

    async def fetch(self, query: str) -> dict[str, Any]:
        """Return {'image_url': ..., 'thumb_url': ...} or both None on miss."""
        key_part = normalise_query(query)
        if not key_part:
            return {"image_url": None, "thumb_url": None}

        cache_key = f"{_CACHE_PREFIX}{key_part}"
        cached = await self._cache.get(cache_key)
        if cached is not None:
            return cached

        if not self._api_key:
            # No key configured — behave like a permanent miss without caching
            # so adding the key later takes effect immediately.
            return {"image_url": None, "thumb_url": None}

        try:
            async with httpx.AsyncClient(timeout=_TIMEOUT_S) as client:
                resp = await client.get(
                    _PEXELS_URL,
                    params={"query": key_part, "per_page": 1, "orientation": "square"},
                    headers={"Authorization": self._api_key},
                )
        except httpx.HTTPError as exc:
            logger.warning("pexels request failed for %r: %s", key_part, exc)
            return {"image_url": None, "thumb_url": None}

        if resp.status_code != 200:
            logger.warning("pexels returned %s for %r", resp.status_code, key_part)
            return {"image_url": None, "thumb_url": None}

        photos = resp.json().get("photos", [])
        if not photos:
            negative = {"image_url": None, "thumb_url": None}
            await self._cache.set(cache_key, negative, ttl=_NEGATIVE_TTL)
            return negative

        src = photos[0].get("src", {})
        result = {
            "image_url": src.get("medium"),
            "thumb_url": src.get("tiny"),
        }
        await self._cache.set(cache_key, result, ttl=_POSITIVE_TTL)
        return result


def normalise_query(raw: str) -> str:
    """Normalise a user food description into a stable cache key.

    Rules:
      1. lowercase
      2. strip punctuation (keep hyphen so "low-carb" survives)
      3. collapse runs of whitespace to a single space
      4. strip leading/trailing whitespace

    Examples:
        "Eggs & Toast!"     -> "eggs toast"
        "low-carb  bagel"   -> "low-carb bagel"
        "   EGGS   "        -> "eggs"
    """
    lowered = raw.lower()
    depunct = _PUNCT_RE.sub(" ", lowered)
    collapsed = _WHITESPACE_RE.sub(" ", depunct)
    return collapsed.strip()
