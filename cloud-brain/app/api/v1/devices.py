"""
Zuralog Cloud Brain — Device Registration Endpoints.

Manages FCM device token registration for cloud-to-device
push communication. The Edge Agent calls these endpoints
after obtaining an FCM token during initialization.
"""

import logging

import sentry_sdk
from fastapi import APIRouter, Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel

from app.api.v1.auth import _get_auth_service
from app.limiter import limiter
from app.services.auth_service import AuthService

logger = logging.getLogger(__name__)


async def _set_sentry_module() -> None:
    sentry_sdk.set_tag("api.module", "devices")


router = APIRouter(
    prefix="/devices",
    tags=["devices"],
    dependencies=[Depends(_set_sentry_module)],
)
security = HTTPBearer()


class DeviceRegistration(BaseModel):
    """Request body for registering a device's FCM token.

    Attributes:
        fcm_token: The device's Firebase Cloud Messaging token.
        platform: Device platform ('ios' or 'android').
    """

    fcm_token: str
    platform: str


@router.post("/register")
@limiter.limit("10/minute")
async def register_device(
    request: Request,
    body: DeviceRegistration,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    auth_service: AuthService = Depends(_get_auth_service),
) -> dict[str, object]:
    """Register or update a device's FCM token.

    Called by the Edge Agent after FCM initialization. If the
    token already exists, updates the associated user. If it's
    a new token, creates a new device record.

    For MVP, stores tokens in-memory on app.state. Phase 2 will
    persist to the UserDevice database table.

    Args:
        request: FastAPI request.
        body: Device registration payload with fcm_token and platform.
        credentials: Bearer token for authentication.
        auth_service: Auth service dependency.

    Returns:
        dict with success status.

    Raises:
        HTTPException: 401 if bearer token is invalid.
    """
    user_data = await auth_service.get_user(credentials.credentials)
    user_id = user_data["id"]
    request.state.user_id = user_id
    sentry_sdk.set_user({"id": user_id})

    if not hasattr(request.app.state, "device_tokens"):
        request.app.state.device_tokens = {}

    request.app.state.device_tokens[user_id] = {
        "fcm_token": body.fcm_token,
        "platform": body.platform,
    }

    logger.info("Device registered for user '%s' (platform=%s)", user_id, body.platform)

    analytics = getattr(request.app.state, "analytics_service", None)
    if analytics:
        analytics.capture(
            distinct_id=user_id,
            event="device_registered",
            properties={"platform": body.platform},
        )

    return {"success": True, "message": "Device registered"}
