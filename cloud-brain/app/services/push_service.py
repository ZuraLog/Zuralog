"""
Life Logger Cloud Brain — Push Notification Service.

Sends push notifications via Firebase Cloud Messaging (FCM).
Gated behind the ``fcm_credentials_path`` setting — returns None
if no credentials are configured, allowing graceful degradation
during development.
"""

import logging

from app.config import settings

logger = logging.getLogger(__name__)

# FCM is optional — only initialize if credentials are configured.
_fcm_initialized = False

if settings.fcm_credentials_path:
    try:
        import firebase_admin  # type: ignore[import-untyped]
        from firebase_admin import credentials

        cred = credentials.Certificate(settings.fcm_credentials_path)
        firebase_admin.initialize_app(cred)
        _fcm_initialized = True
        logger.info("FCM initialized with credentials from %s", settings.fcm_credentials_path)
    except Exception:
        logger.exception("Failed to initialize FCM")
else:
    logger.info("FCM not configured — push notifications disabled")


class PushService:
    """Firebase Cloud Messaging push notification service.

    All methods are no-ops when FCM credentials are not configured,
    allowing the service to be safely instantiated in any environment.
    """

    @property
    def is_available(self) -> bool:
        """Whether FCM is configured and ready to send notifications.

        Returns:
            True if FCM was successfully initialized.
        """
        return _fcm_initialized

    def send_notification(
        self,
        token: str,
        title: str,
        body: str,
        data: dict[str, str] | None = None,
    ) -> str | None:
        """Send a push notification to a specific device.

        Args:
            token: The device's FCM registration token.
            title: Notification title text.
            body: Notification body text.
            data: Optional key-value data payload for the client app.

        Returns:
            The FCM message ID on success, or None if FCM is not
            configured or the send fails.
        """
        if not _fcm_initialized:
            logger.debug("FCM not initialized — skipping notification")
            return None

        try:
            from firebase_admin import messaging  # type: ignore[import-untyped]

            message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data=data or {},
                token=token,
            )
            response = messaging.send(message)
            logger.info("FCM notification sent: %s", response)
            return response
        except Exception:
            logger.exception("FCM send failed")
            return None
