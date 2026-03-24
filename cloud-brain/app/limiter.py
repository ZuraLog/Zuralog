"""
Zuralog Cloud Brain — Global Limiter Configuration.

Uses slowapi (Starlette-native wrapper around the `limits` library).
Rate limit key: verified user ID from auth middleware when available,
falling back to the client's remote IP address.

In production, limits are stored in Redis so they are shared across
all server instances. Set REDIS_URL in the environment to enable this.
If REDIS_URL is not set, limits fall back to in-memory storage (dev only).
"""

import logging

from fastapi import Request
from slowapi import Limiter
from slowapi.util import get_remote_address

from app.config import settings

logger = logging.getLogger(__name__)


def _get_rate_limit_key(request: Request) -> str:
    """Rate limit key: verified user_id from auth middleware if available, else remote IP.

    Uses request.state.user_id (set by auth middleware) rather than unverified
    JWT claims to prevent JWT spoofing attacks on rate limit keys (Fix 2.1 / C-6).
    """
    # Use verified user_id from auth middleware if available
    user_id = getattr(request.state, "user_id", None)
    if user_id:
        return f"user:{user_id}"
    # Fall back to IP — never use unverified JWT claims
    return f"ip:{request.client.host}"


# Fix 2.2 (H-8): Use settings for Redis URL instead of os.getenv
_redis_url = settings.redis_url if settings.redis_url else None

# Fix 2.3 (H-9): Startup warning for in-memory fallback
if not _redis_url:
    logger.warning(
        "slowapi using IN-MEMORY rate limit store — NOT safe for multi-replica deployments"
    )
    if settings.app_env == "production":
        raise RuntimeError("REDIS_URL must be set in production for distributed rate limiting")

limiter = Limiter(
    key_func=_get_rate_limit_key,
    storage_uri=_redis_url,  # None → in-memory (dev). Set in production.
)
