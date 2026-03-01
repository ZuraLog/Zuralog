"""Withings OAuth 2.0 token service.

Key differences from other integrations:
- Access tokens expire in 3 hours (most aggressive)
- Refresh tokens expire in 1 year (must track)
- Auth code valid for only 30 seconds
- All token requests signed with HMAC SHA-256 nonce
- Server-side OAuth callback (not deep link)
- store_state stores user_id (not just "1") so /callback can resolve user
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone
from typing import Any
from urllib.parse import urlencode

import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models.integration import Integration

logger = logging.getLogger(__name__)

_REFRESH_BUFFER = timedelta(minutes=30)
_AUTH_URL = "https://account.withings.com/oauth2_user/authorize2"
_TOKEN_URL = "https://wbsapi.withings.net/v2/oauth2"
_SCOPES = "user.metrics,user.activity"


class WithingsTokenService:
    """Manages Withings OAuth 2.0 tokens."""

    def build_auth_url(self, state: str) -> str:
        """Build the Withings authorization URL."""
        params = {
            "response_type": "code",
            "client_id": settings.withings_client_id,
            "scope": _SCOPES,
            "redirect_uri": settings.withings_redirect_uri,
            "state": state,
        }
        return f"{_AUTH_URL}?{urlencode(params)}"

    async def store_state(self, state: str, user_id: str, redis_client: object) -> None:
        """Store CSRF state token in Redis with user_id as value.

        Unlike Oura which stores "1", we store user_id because the
        server-side /callback endpoint needs it to resolve the user
        (no JWT available in a browser redirect from Withings).
        """
        await redis_client.setex(f"withings:state:{state}", 600, user_id)  # type: ignore[union-attr]

    async def validate_state(self, state: str, redis_client: object) -> str | None:
        """Validate CSRF state and return the stored user_id.

        Returns user_id if state is valid, None otherwise.
        Atomic getdel ensures single-use.
        """
        result = await redis_client.getdel(f"withings:state:{state}")  # type: ignore[union-attr]
        if result is None:
            return None
        return result.decode("utf-8") if isinstance(result, bytes) else str(result)

    async def exchange_code(
        self,
        code: str,
        signature_service: Any,
        redirect_uri: str,
    ) -> dict:
        """Exchange authorization code for tokens.

        Must be called within 30 seconds of receiving the code.
        The signature_service handles nonce+HMAC signing.
        """
        signed_params = await signature_service.prepare_signed_params(
            action="requesttoken",
            extra_params={
                "grant_type": "authorization_code",
                "code": code,
                "redirect_uri": redirect_uri,
            },
        )

        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.post(_TOKEN_URL, data=signed_params)
            response.raise_for_status()

        body = response.json()
        if body.get("status") != 0:
            raise Exception(
                f"Withings token exchange failed: status={body.get('status')}, error={body.get('error', 'unknown')}"
            )

        return body["body"]

    async def save_tokens(
        self,
        db: AsyncSession,
        user_id: str,
        token_response: dict,
    ) -> Integration:
        """Persist tokens to the integrations table (upsert)."""
        result = await db.execute(
            select(Integration).where(
                Integration.user_id == user_id,
                Integration.provider == "withings",
            )
        )
        integration = result.scalar_one_or_none()

        expires_at = datetime.now(timezone.utc) + timedelta(seconds=token_response.get("expires_in", 10800))

        if integration is None:
            integration = Integration(
                user_id=user_id,
                provider="withings",
                access_token=token_response["access_token"],
                refresh_token=token_response["refresh_token"],
                token_expires_at=expires_at,
                provider_metadata={
                    "withings_user_id": str(token_response["userid"]),
                    "granted_scopes": token_response.get("scope", _SCOPES),
                    "webhook_subscription_applis": [],
                },
                is_active=True,
                sync_status="idle",
                sync_error=None,
            )
            db.add(integration)
        else:
            integration.access_token = token_response["access_token"]
            integration.refresh_token = token_response["refresh_token"]
            integration.token_expires_at = expires_at
            integration.is_active = True
            integration.sync_status = "idle"
            integration.sync_error = None
            metadata = integration.provider_metadata or {}
            metadata["withings_user_id"] = str(token_response["userid"])
            metadata["granted_scopes"] = token_response.get("scope", _SCOPES)
            integration.provider_metadata = metadata

        await db.commit()
        await db.refresh(integration)
        return integration

    async def get_access_token(
        self,
        db: AsyncSession,
        user_id: str,
    ) -> str | None:
        """Get a valid access token, auto-refreshing if within 30-min buffer."""
        integration = await self.get_integration(db, user_id)
        if not integration or not integration.is_active:
            return None

        if (
            integration.token_expires_at
            and integration.token_expires_at - _REFRESH_BUFFER  # type: ignore[operator]
            <= datetime.now(timezone.utc)
        ):
            return await self.refresh_access_token(db, integration)

        return integration.access_token

    async def refresh_access_token(
        self,
        db: AsyncSession,
        integration: Integration,
    ) -> str | None:
        """Refresh the access token using the refresh token.

        Withings returns a new refresh token with every refresh.
        Old refresh token valid for 8 hours after new issuance.
        Refresh token expires after 1 year -- if refresh fails, user must re-auth.
        """
        from app.services.withings_signature_service import WithingsSignatureService

        sig_service = WithingsSignatureService(
            client_id=settings.withings_client_id,
            client_secret=settings.withings_client_secret,
        )

        try:
            signed_params = await sig_service.prepare_signed_params(
                action="requesttoken",
                extra_params={
                    "grant_type": "refresh_token",
                    "refresh_token": integration.refresh_token,
                },
            )

            async with httpx.AsyncClient(timeout=15.0) as client:
                response = await client.post(_TOKEN_URL, data=signed_params)
                response.raise_for_status()

            body = response.json()
            if body.get("status") != 0:
                logger.error(
                    "Withings token refresh failed: status=%s error=%s",
                    body.get("status"),
                    body.get("error"),
                )
                integration.sync_status = "error"
                integration.sync_error = "Refresh token expired or invalid. Please reconnect Withings."
                await db.commit()
                return None

            token_data = body["body"]
            integration.access_token = token_data["access_token"]
            integration.refresh_token = token_data["refresh_token"]
            integration.token_expires_at = datetime.now(timezone.utc) + timedelta(  # type: ignore[assignment]
                seconds=token_data.get("expires_in", 10800)
            )
            integration.sync_status = "idle"
            integration.sync_error = None
            await db.commit()
            return integration.access_token

        except httpx.RequestError as exc:
            logger.exception("Network error refreshing Withings token: %s", exc)
            return None

    async def get_integration(
        self,
        db: AsyncSession,
        user_id: str,
    ) -> Integration | None:
        """Look up Withings integration for a user."""
        result = await db.execute(
            select(Integration).where(
                Integration.user_id == user_id,
                Integration.provider == "withings",
            )
        )
        return result.scalar_one_or_none()

    async def disconnect(self, db: AsyncSession, user_id: str) -> bool:
        """Disconnect Withings integration."""
        integration = await self.get_integration(db, user_id)
        if not integration:
            return False

        # TODO: Unsubscribe webhooks via Notify - Revoke before deactivating

        integration.is_active = False
        integration.access_token = ""
        integration.refresh_token = ""
        integration.sync_status = "idle"
        integration.sync_error = None
        await db.commit()
        return True
