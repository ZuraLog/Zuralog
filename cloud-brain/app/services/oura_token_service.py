# app/services/oura_token_service.py
"""
Zuralog Cloud Brain — Oura Ring Token Lifecycle Service.

Manages OAuth 2.0 token persistence, retrieval, automatic refresh,
and revocation for Oura Ring integrations. All token operations go
through the ``integrations`` database table.

Key differences from Fitbit:
- No PKCE — Oura uses a plain authorization code flow.
- Token exchange and refresh use ``client_id`` + ``client_secret``
  in the POST body rather than an ``Authorization: Basic`` header.
- Revocation is a GET request with the token as a query parameter,
  not a POST.
- Access tokens live ~24 hours; the refresh buffer is 30 minutes.
- Refresh tokens are SINGLE-USE — the new refresh token must be
  persisted atomically before returning to the caller.
- On a 401 refresh failure the integration is marked
  ``sync_status="error"`` with a user-facing reconnect message.
- Personal info is fetched from the Oura v2 API after every token
  save and stored in ``provider_metadata``.
"""

import logging
import urllib.parse
from datetime import datetime, timedelta, timezone

import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models.integration import Integration

logger = logging.getLogger(__name__)

# Oura tokens expire after ~24 hours; refresh when within this buffer.
_REFRESH_BUFFER = timedelta(minutes=30)

# Oura OAuth endpoints
_AUTH_URL = "https://cloud.ouraring.com/oauth/authorize"
_TOKEN_URL = "https://api.ouraring.com/oauth/token"
_REVOKE_URL = "https://api.ouraring.com/oauth/revoke"

# Oura v2 personal info endpoint
_PERSONAL_INFO_URL = "https://api.ouraring.com/v2/usercollection/personal_info"

# All 8 Oura scopes
_SCOPES = "email personal daily heartrate workout tag session spo2"


class OuraTokenService:
    """Database-backed Oura Ring OAuth token lifecycle manager.

    Handles authorization URL construction, authorization-code exchange,
    token saving, retrieval (with auto-refresh), and revocation for Oura
    integrations stored in the ``integrations`` table.

    No PKCE is used — Oura does not require it.  Credentials are sent in
    the POST body (not as a Basic authorization header).
    """

    # ------------------------------------------------------------------
    # Authorization URL
    # ------------------------------------------------------------------

    def build_auth_url(self, state: str) -> str:
        """Construct the full Oura OAuth 2.0 authorization URL.

        Includes all 8 required Oura scopes. No PKCE parameters are
        included because Oura does not support PKCE.

        Args:
            state: Random opaque value for CSRF protection.

        Returns:
            A fully-formed authorization URL string.
        """
        params = {
            "response_type": "code",
            "client_id": settings.oura_client_id,
            "redirect_uri": settings.oura_redirect_uri,
            "scope": _SCOPES,
            "state": state,
        }
        return f"{_AUTH_URL}?{urllib.parse.urlencode(params)}"

    # ------------------------------------------------------------------
    # Redis state storage (anti-CSRF)
    # ------------------------------------------------------------------

    async def store_state(self, state: str, redis_client: object) -> None:
        """Store an OAuth state token in Redis with a 10-minute TTL.

        The key is ``oura:state:{state}`` and is single-use; it is
        deleted on retrieval by :meth:`validate_state`.

        Args:
            state: The OAuth ``state`` parameter to store.
            redis_client: An async Redis client instance.

        Raises:
            Exception: Propagates any Redis error to the caller.
        """
        key = f"oura:state:{state}"
        await redis_client.setex(key, 600, "1")
        logger.debug("Stored Oura CSRF state '%s'", state)

    async def validate_state(self, state: str, redis_client: object) -> bool:
        """Retrieve and immediately delete an OAuth state from Redis.

        Single-use: the key is deleted after retrieval so the state
        cannot be replayed.

        Args:
            state: The OAuth ``state`` parameter to validate.
            redis_client: An async Redis client instance.

        Returns:
            ``True`` if the state was found, ``False`` if not found or
            expired.
        """
        key = f"oura:state:{state}"
        # Use atomic GETDEL to retrieve and delete in one operation,
        # closing the TOCTOU race window present with separate GET + DELETE.
        value = await redis_client.getdel(key)
        if value is None:
            logger.warning("Oura CSRF state not found or expired: '%s'", state)
            return False
        logger.debug("Validated and deleted Oura CSRF state '%s'", state)
        return True

    # ------------------------------------------------------------------
    # Token exchange
    # ------------------------------------------------------------------

    async def exchange_code(
        self,
        code: str,
        client_id: str,
        client_secret: str,
        redirect_uri: str,
    ) -> dict:
        """Exchange an authorization code for Oura OAuth tokens.

        Credentials are sent in the POST body — Oura does NOT use
        ``Authorization: Basic`` like Fitbit.

        Args:
            code: The authorization code received from the callback.
            client_id: The Oura application client ID.
            client_secret: The Oura application client secret.
            redirect_uri: The registered OAuth redirect URI.

        Returns:
            The parsed token response dict from Oura containing at
            minimum ``access_token``, ``refresh_token``, and
            ``expires_in``.

        Raises:
            httpx.HTTPStatusError: If Oura returns a non-2xx status.
            httpx.RequestError: On network-level failures.
        """
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.post(
                _TOKEN_URL,
                headers={"Content-Type": "application/x-www-form-urlencoded"},
                data={
                    "grant_type": "authorization_code",
                    "code": code,
                    "redirect_uri": redirect_uri,
                    "client_id": client_id,
                    "client_secret": client_secret,
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
        """Persist Oura OAuth tokens to the database.

        Creates a new ``Integration`` row if none exists for this
        user+provider pair; otherwise updates the existing row in place.

        Also calls :meth:`_fetch_personal_info` to retrieve and store
        the user's Oura profile (``oura_user_id``, ``email``, ``age``,
        ``biological_sex``, ``weight``, ``height``) in
        ``provider_metadata``.  New rows also get an empty
        ``webhook_subscription_ids`` list.

        On UPDATE the new personal info is merged into the existing
        metadata, preserving keys like ``webhook_subscription_ids``.

        Args:
            db: Async database session.
            user_id: The Zuralog user ID.
            token_response: Token response dict from Oura containing
                at minimum ``access_token``, ``refresh_token``, and
                ``expires_in``.

        Returns:
            The created or updated ``Integration`` instance.
        """
        stmt = select(Integration).where(
            Integration.user_id == user_id,
            Integration.provider == "oura",
        )
        result = await db.execute(stmt)
        integration = result.scalar_one_or_none()

        access_token = token_response["access_token"]
        refresh_token = token_response["refresh_token"]
        expires_in = token_response.get("expires_in", 86400)  # 24 hours default
        expires_dt = datetime.now(timezone.utc) + timedelta(seconds=expires_in)

        # Fetch personal info — returns {} on any error so we never fail the flow
        personal_info = await self._fetch_personal_info(access_token)

        # Build a normalized metadata fragment from personal info
        personal_meta: dict = {}
        if personal_info:
            if "id" in personal_info:
                personal_meta["oura_user_id"] = personal_info["id"]
            for field in ("email", "age", "biological_sex", "weight", "height"):
                if field in personal_info:
                    personal_meta[field] = personal_info[field]

        if integration is None:
            provider_metadata: dict = {
                "webhook_subscription_ids": [],
                **personal_meta,
            }
            integration = Integration(
                user_id=user_id,
                provider="oura",
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
            # Reset any prior error state when the user successfully reconnects
            integration.sync_status = "idle"
            integration.sync_error = None
            existing_meta = integration.provider_metadata or {}
            integration.provider_metadata = {
                **existing_meta,
                **personal_meta,
            }

        await db.commit()
        await db.refresh(integration)
        logger.info("Saved Oura tokens for user '%s'", user_id)
        return integration

    # ------------------------------------------------------------------
    # Token retrieval with auto-refresh
    # ------------------------------------------------------------------

    async def get_access_token(
        self,
        db: AsyncSession,
        user_id: str,
    ) -> str | None:
        """Retrieve a valid Oura access token for a user.

        If the token is expired or within the 30-minute refresh buffer,
        it is automatically refreshed before being returned.

        Args:
            db: Async database session.
            user_id: The Zuralog user ID.

        Returns:
            A valid access token string, or ``None`` if no active Oura
            integration exists.
        """
        stmt = select(Integration).where(
            Integration.user_id == user_id,
            Integration.provider == "oura",
            Integration.is_active.is_(True),
        )
        result = await db.execute(stmt)
        integration = result.scalar_one_or_none()

        if integration is None:
            return None

        now = datetime.now(timezone.utc)
        if integration.token_expires_at and integration.token_expires_at - _REFRESH_BUFFER <= now:
            logger.info("Oura token expired/expiring for user '%s', refreshing", user_id)
            return await self.refresh_access_token(db, integration)

        return integration.access_token

    async def refresh_access_token(
        self,
        db: AsyncSession,
        integration: Integration,
    ) -> str | None:
        """Refresh an expired Oura access token.

        Oura issues SINGLE-USE refresh tokens.  The new refresh token
        returned by the API must be persisted atomically before this
        method returns; otherwise a subsequent retry with the old token
        will be rejected with 401.

        Credentials are sent in the POST body — Oura does NOT use
        ``Authorization: Basic`` like Fitbit.

        On a 401 response the integration is marked
        ``sync_status="error"`` with a user-facing reconnect message.

        On a network error, ``None`` is returned without any DB changes.

        Args:
            db: Async database session.
            integration: The ``Integration`` row with stale tokens.

        Returns:
            The new access token string, or ``None`` if refresh failed.
        """
        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                resp = await client.post(
                    _TOKEN_URL,
                    headers={"Content-Type": "application/x-www-form-urlencoded"},
                    data={
                        "grant_type": "refresh_token",
                        "refresh_token": integration.refresh_token,
                        "client_id": settings.oura_client_id,
                        "client_secret": settings.oura_client_secret,
                    },
                )
        except httpx.RequestError as exc:
            logger.error("Network error refreshing Oura token: %s", exc)
            return None

        if resp.status_code == 401:
            logger.error(
                "Oura token refresh unauthorized (401) for user '%s' — marking error",
                integration.user_id,
            )
            integration.sync_status = "error"
            integration.sync_error = "Refresh token expired. Please reconnect Oura."
            await db.commit()
            return None

        if resp.status_code != 200:
            logger.error(
                "Oura token refresh failed (%d): %s",
                resp.status_code,
                resp.text,
            )
            integration.sync_status = "error"
            integration.sync_error = f"Token refresh failed: {resp.status_code}"
            await db.commit()
            return None

        data = resp.json()

        # CRITICAL: Oura issues single-use refresh tokens — save the new
        # refresh token atomically BEFORE returning the access token.
        integration.access_token = data["access_token"]
        integration.refresh_token = data["refresh_token"]  # must be new token
        expires_in = data.get("expires_in", 86400)
        integration.token_expires_at = datetime.now(timezone.utc) + timedelta(seconds=expires_in)
        integration.sync_status = "idle"
        integration.sync_error = None
        await db.commit()

        logger.info("Refreshed Oura token for user '%s'", integration.user_id)
        return integration.access_token

    # ------------------------------------------------------------------
    # Integration lookup
    # ------------------------------------------------------------------

    async def get_integration(
        self,
        db: AsyncSession,
        user_id: str,
    ) -> Integration | None:
        """Fetch the Oura integration row for a user.

        Args:
            db: Async database session.
            user_id: The Zuralog user ID.

        Returns:
            The ``Integration`` instance, or ``None`` if not found.
        """
        stmt = select(Integration).where(
            Integration.user_id == user_id,
            Integration.provider == "oura",
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
        """Disconnect a user's Oura integration.

        Revokes the access token on Oura's authorization server via a
        GET request to ``/oauth/revoke?access_token={token}`` (Oura uses
        GET, not POST like Fitbit), then deactivates the integration row
        and clears stored tokens.

        Args:
            db: Async database session.
            user_id: The Zuralog user ID.

        Returns:
            ``True`` if disconnected, ``False`` if no integration found.
        """
        integration = await self.get_integration(db, user_id)
        if integration is None:
            return False

        # Best-effort revoke on Oura's side (GET with token query param).
        # URL-encode the token to handle any special characters.
        if integration.access_token:
            revoke_url = f"{_REVOKE_URL}?{urllib.parse.urlencode({'access_token': integration.access_token})}"
            try:
                async with httpx.AsyncClient(timeout=10.0) as client:
                    await client.get(revoke_url)
            except httpx.RequestError:
                logger.warning("Failed to revoke Oura token for user '%s'", user_id)

        integration.is_active = False
        integration.access_token = None
        integration.refresh_token = None
        await db.commit()

        logger.info("Disconnected Oura for user '%s'", user_id)
        return True

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    async def _fetch_personal_info(self, access_token: str) -> dict:
        """Fetch the user's personal info from the Oura v2 API.

        Called after every token save to populate ``provider_metadata``
        with the user's profile details. Never raises — returns an empty
        dict on any error so the calling flow is not disrupted.

        Args:
            access_token: A valid Oura Bearer access token.

        Returns:
            A dict containing any of ``id``, ``age``, ``weight``,
            ``height``, ``biological_sex``, and ``email`` from Oura, or
            an empty dict on failure.
        """
        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                resp = await client.get(
                    _PERSONAL_INFO_URL,
                    headers={"Authorization": f"Bearer {access_token}"},
                )
            resp.raise_for_status()
            return resp.json()
        except Exception as exc:
            logger.warning("Failed to fetch Oura personal info: %s", exc)
            return {}
