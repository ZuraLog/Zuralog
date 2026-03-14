"""
Zuralog Cloud Brain — Global Limiter Configuration.

Provides a shared slowapi Limiter used to protect endpoints
from abuse and brute-force attacks.
"""

from fastapi import Request
from slowapi import Limiter
from slowapi.util import get_remote_address


def get_user_or_ip(request: Request) -> str:
    """Rate limit key: authenticated user ID if available, else remote IP.

    Authenticated endpoints are keyed by user ID so users behind shared NAT
    (corporate networks, mobile carriers) don't share a single quota bucket.
    Unauthenticated endpoints (webhooks) fall back to IP address.
    """
    auth_header = request.headers.get("Authorization", "")
    if auth_header.startswith("Bearer "):
        token = auth_header[7:]
        try:
            # Decode without signature verification — we only need the `sub`
            # claim for rate-limiting purposes. Auth integrity is verified
            # separately by the dependency injection layer.
            import jwt as pyjwt  # noqa: PLC0415

            payload = pyjwt.decode(token, options={"verify_signature": False})
            sub = payload.get("sub")
            if sub:
                return f"user:{sub}"
        except Exception:  # noqa: BLE001
            pass
    return get_remote_address(request)


limiter = Limiter(key_func=get_user_or_ip)
