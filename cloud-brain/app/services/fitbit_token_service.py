# app/services/fitbit_token_service.py
"""
Zuralog Cloud Brain — Fitbit Token Lifecycle Service.

Manages PKCE generation, OAuth token persistence, retrieval, automatic
refresh, and revocation for Fitbit integrations. All token operations go
through the ``integrations`` database table.

Key differences from Strava:
- PKCE is required for every authorization flow.
- Token endpoints use ``Authorization: Basic {base64(client_id:client_secret)}``
  rather than POST-body credentials.
- Refresh tokens are SINGLE-USE — the new refresh token must be persisted
  atomically before returning to the caller.
- Tokens expire every 8 hours; the refresh buffer is 10 minutes.
- On a 401 refresh failure, the integration is marked ``sync_status="error"``.
"""

import base64
import hashlib
import logging
import os
import secrets
from datetime import datetime, timedelta, timezone

import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models.integration import Integration

logger = logging.getLogger(__name__)

# Fitbit tokens expire after 8 hours; refresh when within this buffer.
_REFRESH_BUFFER = timedelta(minutes=10)

# Fitbit token endpoint
_TOKEN_URL = "https://api.fitbit.com/oauth2/token"

# Fitbit revocation endpoint
_REVOKE_URL = "https://api.fitbit.com/oauth2/revoke"

# Fitbit authorization endpoint
_AUTH_URL = "https://www.fitbit.com/oauth2/authorize"

# Scopes requested from Fitbit
_SCOPES = (
    "activity heartrate sleep oxygen_saturation respiratory_rate "
    "temperature cardio_fitness electrocardiogram weight nutrition "
    "profile settings"
)


class FitbitTokenService:
    """Database-backed Fitbit OAuth token lifecycle manager.

    Handles PKCE pair generation, authorization URL construction,
    authorization-code exchange, token saving, retrieval (with
    auto-refresh), and revocation for Fitbit integrations stored in
    the ``integrations`` table.
    """

    # ------------------------------------------------------------------
    # PKCE helpers
    # ------------------------------------------------------------------

    def generate_pkce_pair(self) -> tuple[str, str]:
        """Generate a PKCE code_verifier / code_challenge pair.

        The verifier is a cryptographically random, URL-safe base64 string
        (without padding) between 43 and 128 characters long, as required
        by RFC 7636.  The challenge is ``base64url(sha256(verifier))``.

        Returns:
            A ``(code_verifier, code_challenge)`` tuple, both as plain
            strings.
        """
        # 32 random bytes → 43 URL-safe base64 characters (no padding)
        verifier_bytes = os.urandom(32)
        code_verifier = base64.urlsafe_b64encode(verifier_bytes).rstrip(b"=").decode()

        # SHA-256 of the ASCII-encoded verifier, then base64url-encode
        digest = hashlib.sha256(code_verifier.encode("ascii")).digest()
        code_challenge = base64.urlsafe_b64encode(digest).rstrip(b"=").decode()

        return code_verifier, code_challenge

    async def store_pkce_verifier(
        self,
        state: str,
        verifier: str,
        redis_client: object,
    ) -> None:
        """Store a PKCE code_verifier in Redis with a 10-minute TTL.

        The key is ``fitbit:pkce:{state}`` and is single-use; it is
        deleted on retrieval by :meth:`get_pkce_verifier`.

        Args:
            state: The OAuth ``state`` parameter used as part of the key.
            verifier: The PKCE code_verifier string to store.
            redis_client: An async Redis client instance.

        Raises:
            Exception: Propagates any Redis error to the caller.
        """
        key = f"fitbit:pkce:{state}"
        await redis_client.set(key, verifier, ex=600)
        logger.debug("Stored PKCE verifier for state '%s'", state)

    async def get_pkce_verifier(
        self,
        state: str,
        redis_client: object,
    ) -> str | None:
        """Retrieve and immediately delete a PKCE code_verifier from Redis.

        Single-use: the key is deleted atomically after retrieval so that
        the verifier cannot be replayed.

        Args:
            state: The OAuth ``state`` parameter used to locate the key.
            redis_client: An async Redis client instance.

        Returns:
            The code_verifier string, or ``None`` if not found / expired.
        """
        key = f"fitbit:pkce:{state}"
        verifier = await redis_client.getdel(key)
        if verifier is None:
            logger.warning("PKCE verifier not found or expired for state '%s'", state)
            return None
        result = verifier.decode() if isinstance(verifier, bytes) else verifier
        logger.debug("Retrieved and deleted PKCE verifier for state '%s'", state)
        return result

    # ------------------------------------------------------------------
    # Authorization URL
    # ------------------------------------------------------------------

    def build_auth_url(
        self,
        state: str,
        code_challenge: str,
        client_id: str,
        redirect_uri: str,
    ) -> str:
        """Construct the full Fitbit OAuth 2.0 authorization URL.

        Includes all required health scopes and PKCE parameters.

        Args:
            state: Random opaque value for CSRF protection.
            code_challenge: The PKCE code_challenge derived from the verifier.
            client_id: The Fitbit application client ID.
            redirect_uri: The registered OAuth redirect URI.

        Returns:
            A fully-formed authorization URL string.
        """
        import urllib.parse

        params = {
            "response_type": "code",
            "client_id": client_id,
            "redirect_uri": redirect_uri,
            "scope": _SCOPES,
            "state": state,
            "code_challenge": code_challenge,
            "code_challenge_method": "S256",
        }
        return f"{_AUTH_URL}?{urllib.parse.urlencode(params)}"

    # ------------------------------------------------------------------
    # Token exchange
    # ------------------------------------------------------------------

    async def exchange_code(
        self,
        code: str,
        code_verifier: str,
        client_id: str,
        client_secret: str,
        redirect_uri: str,
    ) -> dict:
        """Exchange an authorization code for Fitbit OAuth tokens.

        Uses ``Authorization: Basic {base64(client_id:client_secret)}``
        as required by Fitbit — credentials are NOT sent in the POST body.

        Args:
            code: The authorization code received from the callback.
            code_verifier: The original PKCE code_verifier.
            client_id: The Fitbit application client ID.
            client_secret: The Fitbit application client secret.
            redirect_uri: The registered OAuth redirect URI.

        Returns:
            The parsed token response dict from Fitbit containing at
            minimum ``access_token``, ``refresh_token``, and
            ``expires_in``.

        Raises:
            httpx.HTTPStatusError: If Fitbit returns a non-2xx status.
            httpx.RequestError: On network-level failures.
        """
        credentials = base64.b64encode(
            f"{client_id}:{client_secret}".encode()
        ).decode()

        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.post(
                _TOKEN_URL,
                headers={
                    "Authorization": f"Basic {credentials}",
                    "Content-Type": "application/x-www-form-urlencoded",
                },
                data={
                    "grant_type": "authorization_code",
                    "code": code,
                    "redirect_uri": redirect_uri,
                    "code_verifier": code_verifier,
                    "client_id": client_id,
                },
            )

        resp.raise_for_status()
        return resp.json()

    # ------------------------------------------------------------------
    # Token persistence
    # ------------------------------------------------------------------

    async def save_tokens(
        self,
        db: AsyncSession,
        user_id: str,
        token_response: dict,
    ) -> Integration:
        """Persist Fitbit OAuth tokens to the database.

        Creates a new ``Integration`` row if none exists for this
        user+provider pair; otherwise updates the existing row in place.
        The Fitbit ``user_id`` from the token response is stored in
        ``provider_metadata["fitbit_user_id"]``.

        Args:
            db: Async database session.
            user_id: The Zuralog user ID.
            token_response: Token response dict from Fitbit containing
                ``access_token``, ``refresh_token``, ``expires_in``,
                and optionally ``user_id`` (Fitbit's own user identifier).

        Returns:
            The created or updated ``Integration`` instance.
        """
        stmt = select(Integration).where(
            Integration.user_id == user_id,
            Integration.provider == "fitbit",
        )
        result = await db.execute(stmt)
        integration = result.scalar_one_or_none()

        access_token = token_response["access_token"]
        refresh_token = token_response["refresh_token"]
        expires_in = token_response.get("expires_in", 28800)  # 8 hours default
        expires_dt = datetime.now(timezone.utc) + timedelta(seconds=expires_in)

        fitbit_user_id = token_response.get("user_id")
        provider_metadata = {"fitbit_user_id": fitbit_user_id} if fitbit_user_id else {}

        if integration is None:
            integration = Integration(
                user_id=user_id,
                provider="fitbit",
                access_token=access_token,
                refresh_token=refresh_token,
                token_expires_at=expires_dt,
                provider_metadata=provider_metadata,
                is_active=True,
            )
            db.add(integration)
        else:
            integration.access_token = access_token
            integration.refresh_token = refresh_token
            integration.token_expires_at = expires_dt
            integration.is_active = True
            if fitbit_user_id:
                existing_meta = integration.provider_metadata or {}
                integration.provider_metadata = {
                    **existing_meta,
                    "fitbit_user_id": fitbit_user_id,
                }

        await db.commit()
        await db.refresh(integration)
        logger.info("Saved Fitbit tokens for user '%s'", user_id)
        return integration

    # ------------------------------------------------------------------
    # Token retrieval with auto-refresh
    # ------------------------------------------------------------------

    async def get_access_token(
        self,
        db: AsyncSession,
        user_id: str,
    ) -> str | None:
        """Retrieve a valid Fitbit access token for a user.

        If the token is expired or within the 10-minute refresh buffer,
        it is automatically refreshed before being returned.

        Args:
            db: Async database session.
            user_id: The Zuralog user ID.

        Returns:
            A valid access token string, or ``None`` if no active Fitbit
            integration exists.
        """
        stmt = select(Integration).where(
            Integration.user_id == user_id,
            Integration.provider == "fitbit",
            Integration.is_active.is_(True),
        )
        result = await db.execute(stmt)
        integration = result.scalar_one_or_none()

        if integration is None:
            return None

        now = datetime.now(timezone.utc)
        if integration.token_expires_at and integration.token_expires_at - _REFRESH_BUFFER <= now:
            logger.info("Fitbit token expired/expiring for user '%s', refreshing", user_id)
            return await self.refresh_access_token(db, integration)

        return integration.access_token

    async def refresh_access_token(
        self,
        db: AsyncSession,
        integration: Integration,
    ) -> str | None:
        """Refresh an expired Fitbit access token.

        Fitbit issues SINGLE-USE refresh tokens.  The new refresh token
        returned by the API must be persisted atomically before this
        method returns; otherwise a subsequent retry with the old token
        will be rejected with 401.

        Uses ``Authorization: Basic`` header — credentials are NOT sent
        in the POST body.

        On a 401 response the integration is marked ``sync_status="error"``
        so the caller and any monitoring tooling can react appropriately.

        Args:
            db: Async database session.
            integration: The ``Integration`` row with stale tokens.

        Returns:
            The new access token string, or ``None`` if refresh failed.
        """
        credentials = base64.b64encode(
            f"{settings.fitbit_client_id}:{settings.fitbit_client_secret}".encode()
        ).decode()

        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                resp = await client.post(
                    _TOKEN_URL,
                    headers={
                        "Authorization": f"Basic {credentials}",
                        "Content-Type": "application/x-www-form-urlencoded",
                    },
                    data={
                        "grant_type": "refresh_token",
                        "refresh_token": integration.refresh_token,
                    },
                )
        except httpx.RequestError as exc:
            logger.error("Network error refreshing Fitbit token: %s", exc)
            return None

        if resp.status_code == 401:
            logger.error(
                "Fitbit token refresh unauthorized (401) for user '%s' — marking error",
                integration.user_id,
            )
            integration.sync_status = "error"
            integration.sync_error = "Token refresh failed: 401 Unauthorized"
            await db.commit()
            return None

        if resp.status_code != 200:
            logger.error(
                "Fitbit token refresh failed (%d): %s",
                resp.status_code,
                resp.text,
            )
            integration.sync_status = "error"
            integration.sync_error = f"Token refresh failed: {resp.status_code}"
            await db.commit()
            return None

        data = resp.json()

        # CRITICAL: Fitbit issues single-use refresh tokens — save the new
        # refresh token atomically BEFORE returning the access token.
        integration.access_token = data["access_token"]
        integration.refresh_token = data["refresh_token"]  # must be new token
        expires_in = data.get("expires_in", 28800)
        integration.token_expires_at = datetime.now(timezone.utc) + timedelta(seconds=expires_in)
        integration.sync_error = None
        await db.commit()

        logger.info("Refreshed Fitbit token for user '%s'", integration.user_id)
        return integration.access_token

    # ------------------------------------------------------------------
    # Integration lookup
    # ------------------------------------------------------------------

    async def get_integration(
        self,
        db: AsyncSession,
        user_id: str,
    ) -> Integration | None:
        """Fetch the Fitbit integration row for a user.

        Args:
            db: Async database session.
            user_id: The Zuralog user ID.

        Returns:
            The ``Integration`` instance, or ``None`` if not found.
        """
        stmt = select(Integration).where(
            Integration.user_id == user_id,
            Integration.provider == "fitbit",
        )
        result = await db.execute(stmt)
        return result.scalar_one_or_none()

    # ------------------------------------------------------------------
    # Disconnect / revoke
    # ------------------------------------------------------------------

    async def disconnect(
        self,
        db: AsyncSession,
        user_id: str,
    ) -> bool:
        """Disconnect a user's Fitbit integration.

        Revokes the access token on Fitbit's authorization server via
        ``POST /oauth2/revoke``, then deactivates the integration row
        in the database.

        Args:
            db: Async database session.
            user_id: The Zuralog user ID.

        Returns:
            ``True`` if disconnected, ``False`` if no integration found.
        """
        integration = await self.get_integration(db, user_id)
        if integration is None:
            return False

        credentials = base64.b64encode(
            f"{settings.fitbit_client_id}:{settings.fitbit_client_secret}".encode()
        ).decode()

        # Best-effort revoke on Fitbit's side
        if integration.access_token:
            try:
                async with httpx.AsyncClient(timeout=10.0) as client:
                    await client.post(
                        _REVOKE_URL,
                        headers={
                            "Authorization": f"Basic {credentials}",
                            "Content-Type": "application/x-www-form-urlencoded",
                        },
                        data={"token": integration.access_token},
                    )
            except httpx.RequestError:
                logger.warning("Failed to revoke Fitbit token for user '%s'", user_id)

        integration.is_active = False
        await db.commit()

        logger.info("Disconnected Fitbit for user '%s'", user_id)
        return True
