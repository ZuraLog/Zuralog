"""
Zuralog Cloud Brain — Developer-Only Endpoints.

Provides test endpoints for the developer harness. These endpoints
simulate AI-initiated actions (like health data writes) without
going through the full LLM pipeline.

WARNING: These endpoints must be disabled or protected in production.
"""

import logging

import sentry_sdk
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel

from app.api.v1.auth import _get_auth_service
from app.config import settings
from app.limiter import limiter
from app.services.auth_service import AuthService

logger = logging.getLogger(__name__)


async def _set_sentry_module() -> None:
    sentry_sdk.set_tag("api.module", "dev")


router = APIRouter(
    prefix="/dev",
    tags=["dev"],
    dependencies=[Depends(_set_sentry_module)],
)
security = HTTPBearer()


class TriggerWriteRequest(BaseModel):
    """Request body for simulating an AI write request.

    Attributes:
        data_type: Health data type to write (e.g., 'steps', 'nutrition').
        value: Data payload to write to the health store.
    """

    data_type: str
    value: dict


@router.post("/trigger-write")
@limiter.limit("20/minute")
async def trigger_write(
    request: Request,
    body: TriggerWriteRequest,
    credentials: HTTPAuthorizationCredentials = Depends(security),
    auth_service: AuthService = Depends(_get_auth_service),
) -> dict[str, object]:
    """Simulate an AI-initiated health data write via FCM.

    This endpoint bypasses the LLM pipeline and directly sends
    a write request to the user's registered device. Used by the
    developer harness to test the FCM -> Background Handler ->
    HealthKit/Health Connect write chain.

    Args:
        request: FastAPI request — accesses app.state services.
        body: The write request payload.
        credentials: Bearer token for authentication.
        auth_service: Auth service dependency.

    Returns:
        The result from DeviceWriteService.send_write_request().

    Raises:
        HTTPException: 401 if bearer token is invalid.
        HTTPException: 404 if no device is registered for this user.
        HTTPException: 503 if the endpoint is disabled in production.
    """
    if settings.app_env == "production":
        raise HTTPException(
            status_code=503,
            detail="Dev endpoints disabled in production",
        )

    user_data = await auth_service.get_user(credentials.credentials)
    user_id = user_data["id"]

    # Look up the user's registered device token
    device_tokens = getattr(request.app.state, "device_tokens", {})
    device_info = device_tokens.get(user_id)

    if not device_info:
        raise HTTPException(
            status_code=404,
            detail="No device registered. Open the app and initialize FCM first.",
        )

    device_write_service = request.app.state.device_write_service
    result = await device_write_service.send_write_request(
        device_token=device_info["fcm_token"],
        data_type=body.data_type,
        value=body.value,
    )

    return result
