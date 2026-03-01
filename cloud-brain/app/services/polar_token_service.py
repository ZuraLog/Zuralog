# app/services/polar_token_service.py
"""
Zuralog Cloud Brain — Polar AccessLink Token Lifecycle Service.

Manages OAuth 2.0 token persistence, retrieval, and revocation for Polar
integrations. All token operations go through the ``integrations`` database
table.

Key differences from other providers:
- Polar uses Authorization: Basic header for token exchange (base64-encoded
  client_id:client_secret), NOT credentials in the POST body.
- Polar has NO refresh tokens — access tokens are long-lived (~1 year).
  When a token expires the user must re-authenticate.
- After OAuth, users must be explicitly registered with the AccessLink API
  via a POST to /v3/users before any data can be fetched.
- The ``x_user_id`` field in the token response is the numeric Polar user ID
  needed for all subsequent API calls.
- State key stores the user_id (not a boolean) so the callback can identify
  which Zuralog user initiated the OAuth flow.
"""

import base64
import logging
import urllib.parse
from datetime import datetime, timedelta, timezone

import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models.integration import Integration

logger = logging.getLogger(__name__)

# Polar OAuth and API constants
POLAR_AUTH_URL = "https://flow.polar.com/oauth2/authorization"
POLAR_TOKEN_URL = "https://polarremote.com/v2/oauth2/token"
POLAR_API_BASE = "https://www.polaraccesslink.com"

# Anti-CSRF state TTL
STATE_TTL_SECONDS = 600


class PolarTokenService:
    """Database-backed Polar AccessLink OAuth token lifecycle manager.

    Handles authorization URL construction, authorization-code exchange,
    user registration with AccessLink, token saving, retrieval, and
    revocation for Polar integrations stored in the ``integrations`` table.

    Polar uses Authorization: Basic for token exchange and has no refresh
    tokens — long-lived access tokens (~1 year) are issued directly.
    """

    # ------------------------------------------------------------------
    # Authorization URL
    # ------------------------------------------------------------------

    def build_auth_url(self, state: str) -> str:
        """Construct the full Polar OAuth 2.0 authorization URL.

        Args:
            state: Random opaque value for CSRF protection.

        Returns:
            A fully-formed authorization URL string pointing to Polar Flow.
        """
        params = {
            "response_type": "code",
            "client_id": settings.polar_client_id,
            "redirect_uri": settings.polar_redirect_uri,
            "state": state,
        }
        return f"{POLAR_AUTH_URL}?{urllib.parse.urlencode(params)}"

    # ------------------------------------------------------------------
    # Redis state storage (anti-CSRF)
    # ------------------------------------------------------------------

    async def store_state(self, state: str, user_id: str, redis_client: object) -> None:
        """Store an OAuth state token mapped to a user_id in Redis.

        Unlike Oura (which stores '1'), Polar stores the user_id so the
        callback can identify which Zuralog user initiated the flow.

        Key: ``polar:state:{state}`` → user_id string, TTL = 600s.

        Args:
            state: The OAuth ``state`` parameter to store.
            user_id: The Zuralog user ID initiating the OAuth flow.
            redis_client: An async Redis client instance.
        """
        key = f"polar:state:{state}"
        await redis_client.setex(key, STATE_TTL_SECONDS, user_id)
        logger.debug("Stored Polar CSRF state '%s' for user '%s'", state, user_id)

    async def validate_state(self, state: str, redis_client: object) -> str | None:
        """Retrieve and immediately delete an OAuth state from Redis.

        Single-use: the key is deleted after retrieval via atomic GETDEL
        so the state cannot be replayed.

        Args:
            state: The OAuth ``state`` parameter to validate.
            redis_client: An async Redis client instance.

        Returns:
            The stored user_id string, or ``None`` if not found/expired.
        """
        key = f"polar:state:{state}"
        # Atomic GETDEL — closes TOCTOU race window between GET and DELETE.
        value = await redis_client.getdel(key)
        if value is None:
            logger.warning("Polar CSRF state not found or expired: '%s'", state)
            return None
        # Redis returns bytes; decode to string.
        user_id = value.decode("utf-8") if isinstance(value, bytes) else value
        logger.debug("Validated and deleted Polar CSRF state '%s'", state)
        return user_id

    # ------------------------------------------------------------------
    # Token exchange
    # ------------------------------------------------------------------

    async def exchange_code(self, code: str) -> dict:
        """Exchange an authorization code for a Polar AccessLink access token.

        Polar requires credentials via Authorization: Basic header (base64
        encoded ``client_id:client_secret``), NOT in the POST body.
        ``redirect_uri`` must be echoed back if it was included in the
        authorization request (RFC 6749 §4.1.3; Polar enforces this).

        Args:
            code: The authorization code received from the Polar callback.

        Returns:
            Parsed token response dict containing at minimum
            ``access_token``, ``token_type``, ``expires_in``, and
            ``x_user_id`` (the numeric Polar user identifier).

        Raises:
            httpx.HTTPStatusError: If Polar returns a non-2xx status.
            httpx.RequestError: On network-level failures.
        """
        client_id = settings.polar_client_id
        client_secret = settings.polar_client_secret

        # Build Basic auth header: base64(client_id:client_secret)
        credentials = base64.b64encode(f"{client_id}:{client_secret}".encode()).decode()

        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.post(
                POLAR_TOKEN_URL,
                headers={
                    "Authorization": f"Basic {credentials}",
                    "Content-Type": "application/x-www-form-urlencoded",
                    "Accept": "application/json;charset=UTF-8",
                },
                data={
                    "grant_type": "authorization_code",
                    "code": code,
                    # Must match the redirect_uri used in build_auth_url
                    "redirect_uri": settings.polar_redirect_uri,
                },
            )

        resp.raise_for_status()
        return resp.json()

    # ------------------------------------------------------------------
    # User registration with AccessLink
    # ------------------------------------------------------------------

    async def register_user(self, access_token: str, member_id: str) -> dict:
        """Register a user with the Polar AccessLink API.

        Must be called after the first token exchange. If the user is
        already registered (409), falls back to fetching their existing
        info via :meth:`_get_user_info`.

        Args:
            access_token: A valid Polar Bearer access token.
            member_id: The Zuralog user ID to use as the Polar member-id.

        Returns:
            User info dict from Polar, or empty dict if lookup fails.
        """
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.post(
                f"{POLAR_API_BASE}/v3/users",
                headers={
                    "Authorization": f"Bearer {access_token}",
                    "Content-Type": "application/json",
                    "Accept": "application/json",
                },
                json={"member-id": member_id},
            )

        if resp.status_code == 200:
            logger.info("Registered new Polar user with member-id '%s'", member_id)
            return resp.json()

        if resp.status_code == 409:
            # User already registered — attempt to fetch their info.
            # We don't have polar_user_id at this point so we return an empty
            # dict; the caller should use the x_user_id from the token response.
            logger.info(
                "Polar user already registered (409) for member-id '%s'; fetching info",
                member_id,
            )
            # Try to parse polar_user_id from conflict response if available
            try:
                conflict_data = resp.json()
                polar_user_id = conflict_data.get("polar-user-id") or conflict_data.get("x_user_id")
            except Exception:
                polar_user_id = None

            if polar_user_id:
                return await self._get_user_info(access_token, polar_user_id)

            # Fall back: return empty dict — caller will use x_user_id from token
            return {}

        logger.error(
            "Polar user registration failed (%d): %s",
            resp.status_code,
            resp.text,
        )
        resp.raise_for_status()
        return {}

    async def _get_user_info(self, access_token: str, polar_user_id: int | str) -> dict:
        """Fetch user info from Polar AccessLink.

        Args:
            access_token: A valid Polar Bearer access token.
            polar_user_id: The numeric Polar user ID.

        Returns:
            User info dict from Polar, or ``{}`` on any error.
        """
        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                resp = await client.get(
                    f"{POLAR_API_BASE}/v3/users/{polar_user_id}",
                    headers={
                        "Authorization": f"Bearer {access_token}",
                        "Accept": "application/json",
                    },
                )
            if resp.status_code == 200:
                return resp.json()
            return {}
        except Exception as exc:
            logger.warning("Failed to fetch Polar user info for %s: %s", polar_user_id, exc)
            return {}

    # ------------------------------------------------------------------
    # Token persistence
    # ------------------------------------------------------------------

    async def save_tokens(
        self,
        db: AsyncSession,
        user_id: str,
        token_response: dict,
        user_info: dict,
    ) -> Integration:
        """Persist Polar OAuth tokens and user metadata to the database.

        Creates a new ``Integration`` row if none exists for this
        user+provider pair; otherwise updates the existing row in place.

        Polar issues no refresh tokens; ``refresh_token`` is always ``None``.
        Access tokens are long-lived (~1 year by default).

        Args:
            db: Async database session.
            user_id: The Zuralog user ID.
            token_response: Token response dict from Polar containing at
                minimum ``access_token``, ``expires_in``, and ``x_user_id``.
            user_info: User profile dict from Polar AccessLink ``/v3/users``.

        Returns:
            The created or updated ``Integration`` instance.
        """
        stmt = select(Integration).where(
            Integration.user_id == user_id,
            Integration.provider == "polar",
        )
        result = await db.execute(stmt)
        integration = result.scalar_one_or_none()

        access_token = token_response["access_token"]
        expires_in = token_response.get("expires_in", 31535999)  # ~1 year default
        expires_dt = datetime.now(timezone.utc) + timedelta(seconds=expires_in)

        provider_metadata = {
            "polar_user_id": token_response.get("x_user_id"),
            "member_id": user_id,
            "first_name": user_info.get("first-name", ""),
            "last_name": user_info.get("last-name", ""),
            "registration_date": user_info.get("registration-date", ""),
            "weight": user_info.get("weight"),
            "height": user_info.get("height"),
            "gender": user_info.get("gender", ""),
            "birthdate": user_info.get("birthdate", ""),
        }

        if integration is None:
            integration = Integration(
                user_id=user_id,
                provider="polar",
                access_token=access_token,
                refresh_token=None,  # Polar has no refresh tokens
                token_expires_at=expires_dt,
                provider_metadata=provider_metadata,
                is_active=True,
                sync_status="idle",
                sync_error=None,
            )
            db.add(integration)
        else:
            integration.access_token = access_token
            integration.refresh_token = None
            integration.token_expires_at = expires_dt
            integration.provider_metadata = provider_metadata
            integration.is_active = True
            integration.sync_status = "idle"
            integration.sync_error = None

        await db.commit()
        await db.refresh(integration)
        logger.info("Saved Polar tokens for user '%s'", user_id)
        return integration

    # ------------------------------------------------------------------
    # Token retrieval
    # ------------------------------------------------------------------

    async def get_access_token(
        self,
        db: AsyncSession,
        user_id: str,
    ) -> str | None:
        """Retrieve a valid Polar access token for a user.

        Polar has no refresh tokens so expired tokens return ``None``
        rather than triggering a refresh. The user must re-authenticate.

        Args:
            db: Async database session.
            user_id: The Zuralog user ID.

        Returns:
            A valid access token string, or ``None`` if no active Polar
            integration exists or the token has expired.
        """
        integration = await self.get_integration(db, user_id)
        if integration is None:
            return None

        # Check expiry only if token_expires_at is set
        if integration.token_expires_at is not None:
            now = datetime.now(timezone.utc)
            if integration.token_expires_at < now:
                logger.info(
                    "Polar access token expired for user '%s'; re-auth required",
                    user_id,
                )
                return None

        return integration.access_token

    # ------------------------------------------------------------------
    # Integration lookup
    # ------------------------------------------------------------------

    async def get_integration(
        self,
        db: AsyncSession,
        user_id: str,
    ) -> Integration | None:
        """Fetch the active Polar integration row for a user.

        Args:
            db: Async database session.
            user_id: The Zuralog user ID.

        Returns:
            The active ``Integration`` instance, or ``None`` if not found.
        """
        stmt = select(Integration).where(
            Integration.provider == "polar",
            Integration.user_id == user_id,
            Integration.is_active.is_(True),
        )
        result = await db.execute(stmt)
        return result.scalar_one_or_none()

    # ------------------------------------------------------------------
    # Disconnect / deactivate
    # ------------------------------------------------------------------

    async def disconnect(
        self,
        db: AsyncSession,
        user_id: str,
    ) -> bool:
        """Disconnect a user's Polar integration.

        Makes a best-effort DELETE to the Polar AccessLink API to
        deregister the user, then deactivates the local integration row
        regardless of the API call outcome.

        Args:
            db: Async database session.
            user_id: The Zuralog user ID.

        Returns:
            ``True`` if disconnected, ``False`` if no integration found.
        """
        integration = await self.get_integration(db, user_id)
        if integration is None:
            return False

        polar_user_id = (integration.provider_metadata or {}).get("polar_user_id")

        # Best-effort DELETE to Polar AccessLink API — swallow all exceptions.
        if integration.access_token and polar_user_id:
            try:
                async with httpx.AsyncClient(timeout=10.0) as client:
                    await client.delete(
                        f"{POLAR_API_BASE}/v3/users/{polar_user_id}",
                        headers={"Authorization": f"Bearer {integration.access_token}"},
                    )
                logger.info("Deregistered Polar user %s from AccessLink", polar_user_id)
            except Exception as exc:
                logger.warning(
                    "Failed to deregister Polar user %s from AccessLink: %s",
                    polar_user_id,
                    exc,
                )

        integration.is_active = False
        integration.access_token = None
        integration.sync_status = "idle"
        await db.commit()

        logger.info("Disconnected Polar for user '%s'", user_id)
        return True
