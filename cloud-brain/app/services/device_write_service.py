"""
Life Logger Cloud Brain — Device Write Service.

Bridges server-side AI decisions to on-device health data writes
via Firebase Cloud Messaging (FCM) silent data messages.

When the AI Brain decides to write data (e.g., "I logged that meal
for you"), this service constructs the FCM payload and sends it
to the user's device. The Edge Agent's background handler then
executes the actual HealthKit/Health Connect write.
"""

import json
import logging
from datetime import datetime, timezone
from typing import Any

from app.services.push_service import PushService

logger = logging.getLogger(__name__)


class DeviceWriteService:
    """Sends health data write requests to user devices via FCM.

    Attributes:
        push_service: The FCM push service for message delivery.
    """

    def __init__(self, push_service: PushService) -> None:
        """Create a new DeviceWriteService.

        Args:
            push_service: An initialized PushService instance.
        """
        self.push_service = push_service

    async def send_write_request(
        self,
        device_token: str,
        data_type: str,
        value: dict[str, Any],
    ) -> dict[str, Any]:
        """Send a write request to a user's device via FCM.

        Constructs an FCM data-only message (silent push) that
        instructs the Edge Agent to write health data locally.

        Args:
            device_token: The target device's FCM registration token.
            data_type: The type of health data to write (e.g.,
                'nutrition', 'steps', 'weight', 'workout').
            value: The data payload to write. Will be JSON-encoded.

        Returns:
            A dict with 'success' (bool) and either 'message' or
            'error' describing the outcome.
        """
        if not self.push_service.is_available:
            logger.warning("FCM not configured — cannot send write request")
            return {
                "success": False,
                "error": "Push service not configured. FCM credentials required.",
            }

        payload: dict[str, str] = {
            "action": "write_health",
            "data_type": data_type,
            "value": json.dumps(value),
            "timestamp": datetime.now(tz=timezone.utc).isoformat(),
        }

        message_id = self.push_service.send_data_message(
            token=device_token,
            data=payload,
        )

        if message_id:
            logger.info(
                "Write request sent (msg=%s, type=%s)",
                message_id,
                data_type,
            )
            return {
                "success": True,
                "message": "Write request sent to device. It may take a moment to appear.",
                "message_id": message_id,
            }

        return {
            "success": False,
            "error": "Could not reach device. The request will be retried by FCM.",
        }
