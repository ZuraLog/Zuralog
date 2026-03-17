"""
Zuralog Cloud Brain — Global Limiter Configuration.

Uses slowapi (Starlette-native wrapper around the `limits` library).
Rate limit key: authenticated user ID when a Bearer JWT is present,
falling back to the client's remote IP address.

In production, limits are stored in Redis so they are shared across
all server instances. Set REDIS_URL in the environment to enable this.
If REDIS_URL is not set, limits fall back to in-memory storage (dev only).
"""

import os

from fastapi import Request
from slowapi import Limiter
from slowapi.util import get_remote_address


def get_user_or_ip(request: Request) -> str:
    """Rate limit key: authenticated user ID if available, else remote IP.

    The JWT is decoded WITHOUT signature verification — this is intentional.
    The auth layer (get_authenticated_user_id) performs full verification.
    We only need the `sub` claim to produce a stable per-user key.
    """
    auth_header = request.headers.get("Authorization", "")
    if auth_header.startswith("Bearer "):
        token = auth_header[7:]
        try:
            import jwt as pyjwt  # noqa: PLC0415

            payload = pyjwt.decode(token, options={"verify_signature": False})
            sub = payload.get("sub")
            if sub:
                return f"user:{sub}"
        except Exception:  # noqa: BLE001
            pass
    return get_remote_address(request)


_redis_url = os.getenv("REDIS_URL")

limiter = Limiter(
    key_func=get_user_or_ip,
    storage_uri=_redis_url,  # None → in-memory (dev). Set in production.
)
