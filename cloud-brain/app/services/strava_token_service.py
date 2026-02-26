# app/services/strava_token_service.py
"""
Zuralog Cloud Brain — Strava Token Lifecycle Service.

Manages OAuth token persistence, retrieval, automatic refresh, and
revocation for Strava integrations. All operations go through the
``integrations`` database table.
"""

import logging
from datetime import datetime, timedelta, timezone

import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models.integration import Integration

logger = logging.getLogger(__name__)

# Refresh tokens 5 minutes before they expire.
_REFRESH_BUFFER = timedelta(minutes=5)


class StravaTokenService:
    """Database-backed Strava OAuth token lifecycle manager.

    Handles saving, retrieving (with auto-refresh), refreshing,
    and revoking Strava OAuth tokens stored in the ``integrations``
    table.
    """

    async def save_tokens(
        self,
        db: AsyncSession,
        user_id: str,
        access_token: str,
        refresh_token: str,
        expires_at: int,
        athlete_data: dict | None = None,
    ) -> Integration:
        """Persist Strava OAuth tokens to the database.

        Creates a new ``Integration`` row if none exists for this
        user+provider pair; otherwise updates the existing row.

        Args:
            db: Async database session.
            user_id: The Zuralog user ID.
            access_token: Strava OAuth access token.
            refresh_token: Strava OAuth refresh token.
            expires_at: Unix timestamp when the access token expires.
            athlete_data: Optional Strava athlete profile dict.

        Returns:
            The created or updated ``Integration`` instance.
        """
        stmt = select(Integration).where(
            Integration.user_id == user_id,
            Integration.provider == "strava",
        )
        result = await db.execute(stmt)
        integration = result.scalar_one_or_none()

        expires_dt = datetime.fromtimestamp(expires_at, tz=timezone.utc)

        if integration is None:
            integration = Integration(
                user_id=user_id,
                provider="strava",
                access_token=access_token,
                refresh_token=refresh_token,
                token_expires_at=expires_dt,
                provider_metadata=athlete_data,
                is_active=True,
            )
            db.add(integration)
        else:
            integration.access_token = access_token
            integration.refresh_token = refresh_token
            integration.token_expires_at = expires_dt
            integration.is_active = True
            if athlete_data:
                integration.provider_metadata = athlete_data

        await db.commit()
        await db.refresh(integration)
        logger.info("Saved Strava tokens for user '%s'", user_id)
        return integration

    async def get_access_token(
        self,
        db: AsyncSession,
        user_id: str,
    ) -> str | None:
        """Retrieve a valid Strava access token for a user.

        If the token is expired or within the refresh buffer, it is
        automatically refreshed before being returned.

        Args:
            db: Async database session.
            user_id: The Zuralog user ID.

        Returns:
            A valid access token string, or ``None`` if no active
            Strava integration exists.
        """
        stmt = select(Integration).where(
            Integration.user_id == user_id,
            Integration.provider == "strava",
            Integration.is_active.is_(True),
        )
        result = await db.execute(stmt)
        integration = result.scalar_one_or_none()

        if integration is None:
            return None

        now = datetime.now(timezone.utc)
        if integration.token_expires_at and integration.token_expires_at - _REFRESH_BUFFER <= now:
            logger.info("Token expired/expiring for user '%s', refreshing", user_id)
            return await self.refresh_access_token(db, integration)

        return integration.access_token

    async def refresh_access_token(
        self,
        db: AsyncSession,
        integration: Integration,
    ) -> str | None:
        """Refresh an expired Strava access token.

        Calls Strava's token endpoint with the refresh token and
        updates the database row with the new tokens.

        Args:
            db: Async database session.
            integration: The ``Integration`` row with stale tokens.

        Returns:
            The new access token, or ``None`` if refresh failed.
        """
        try:
            async with httpx.AsyncClient(timeout=15.0) as client:
                resp = await client.post(
                    "https://www.strava.com/oauth/token",
                    data={
                        "client_id": settings.strava_client_id,
                        "client_secret": settings.strava_client_secret,
                        "grant_type": "refresh_token",
                        "refresh_token": integration.refresh_token,
                    },
                )
        except httpx.RequestError as exc:
            logger.error("Network error refreshing Strava token: %s", exc)
            return None

        if resp.status_code != 200:
            logger.error(
                "Strava token refresh failed (%d): %s",
                resp.status_code,
                resp.text,
            )
            integration.sync_status = "error"
            integration.sync_error = f"Token refresh failed: {resp.status_code}"
            await db.commit()
            return None

        data = resp.json()
        integration.access_token = data["access_token"]
        integration.refresh_token = data.get("refresh_token", integration.refresh_token)
        integration.token_expires_at = datetime.fromtimestamp(data["expires_at"], tz=timezone.utc)
        integration.sync_error = None
        await db.commit()

        logger.info("Refreshed Strava token for user '%s'", integration.user_id)
        return integration.access_token

    async def get_integration(
        self,
        db: AsyncSession,
        user_id: str,
    ) -> Integration | None:
        """Fetch the Strava integration row for a user.

        Args:
            db: Async database session.
            user_id: The Zuralog user ID.

        Returns:
            The ``Integration`` instance, or ``None``.
        """
        stmt = select(Integration).where(
            Integration.user_id == user_id,
            Integration.provider == "strava",
        )
        result = await db.execute(stmt)
        return result.scalar_one_or_none()

    async def disconnect(
        self,
        db: AsyncSession,
        user_id: str,
    ) -> bool:
        """Disconnect a user's Strava integration.

        Clears tokens and deactivates the integration row.
        Optionally revokes the token on Strava's side.

        Args:
            db: Async database session.
            user_id: The Zuralog user ID.

        Returns:
            ``True`` if disconnected, ``False`` if no integration found.
        """
        integration = await self.get_integration(db, user_id)
        if integration is None:
            return False

        # Best-effort revoke on Strava's side
        if integration.access_token:
            try:
                async with httpx.AsyncClient(timeout=10.0) as client:
                    await client.post(
                        "https://www.strava.com/oauth/deauthorize",
                        params={"access_token": integration.access_token},
                    )
            except httpx.RequestError:
                logger.warning("Failed to revoke Strava token for user '%s'", user_id)

        integration.access_token = None
        integration.refresh_token = None
        integration.token_expires_at = None
        integration.is_active = False
        await db.commit()

        logger.info("Disconnected Strava for user '%s'", user_id)
        return True
