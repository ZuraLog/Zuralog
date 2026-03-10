"""
Zuralog Cloud Brain — Push Notification Service.

Sends push notifications via Firebase Cloud Messaging (FCM).
Gated behind the ``fcm_credentials_path`` setting — returns None
if no credentials are configured, allowing graceful degradation
during development.

Firebase is lazy-initialized on first use rather than at import time.
This avoids startup cost and errors when credentials are not configured.

Key methods
-----------
``send_notification``       — Send a push to a single device token (existing).
``send_data_message``       — Send a silent data-only message (existing).
``send_and_persist``        — Send to all user devices AND persist a
                              ``NotificationLog`` row (new, Phase 2).
"""

import logging
import uuid
from datetime import datetime, timezone
from typing import TYPE_CHECKING

from app.config import settings

if TYPE_CHECKING:
    from sqlalchemy.ext.asyncio import AsyncSession

logger = logging.getLogger(__name__)

# FCM initialization state: None = not yet attempted, True/False = result
_fcm_initialized = None


def _ensure_fcm_initialized() -> bool:
    """Lazy-initialize Firebase if not already attempted.

    Called on first use rather than at module import time. This avoids
    startup overhead and import-time errors when FCM credentials are absent.

    Returns:
        True if FCM was successfully initialized, False otherwise.
    """
    global _fcm_initialized

    if _fcm_initialized is not None:
        return _fcm_initialized

    if settings.firebase_credentials_json:
        # Production path: credentials provided as a JSON string env var (Railway).
        try:
            import json

            import firebase_admin  # type: ignore[import-untyped]
            from firebase_admin import credentials

            cred_dict = json.loads(settings.firebase_credentials_json)
            cred = credentials.Certificate(cred_dict)
            firebase_admin.initialize_app(cred)
            _fcm_initialized = True
            logger.info("FCM initialized from FIREBASE_CREDENTIALS_JSON env var")
        except Exception:
            logger.exception("Failed to initialize FCM from JSON env var")
            _fcm_initialized = False
    elif settings.fcm_credentials_path:
        # Local dev path: credentials loaded from a file.
        try:
            import firebase_admin  # type: ignore[import-untyped]
            from firebase_admin import credentials

            cred = credentials.Certificate(settings.fcm_credentials_path)
            firebase_admin.initialize_app(cred)
            _fcm_initialized = True
            logger.info("FCM initialized with credentials from %s", settings.fcm_credentials_path)
        except Exception:
            logger.exception("Failed to initialize FCM")
            _fcm_initialized = False
    else:
        logger.info("FCM not configured — push notifications disabled")
        _fcm_initialized = False

    return _fcm_initialized


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
        return _ensure_fcm_initialized()

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
        if not _ensure_fcm_initialized():
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
            # TODO: PostHog push_notification_sent event — needs analytics service injection.
            # PushService is a plain class instantiated without request context; pass an
            # optional analytics_service parameter if this event becomes required.
            return response
        except Exception:
            logger.exception("FCM send failed")
            return None

    async def send_and_persist(
        self,
        user_id: str,
        title: str,
        body: str,
        notification_type: str,
        deep_link: str | None = None,
        data: dict[str, str] | None = None,
        db: "AsyncSession | None" = None,
    ) -> bool:
        """Send a push notification to all of the user's registered devices
        and persist a ``NotificationLog`` row for the notification centre.

        The FCM send is attempted first. Persistence is then attempted
        regardless of FCM availability — even if no push was delivered, the
        notification still appears in the user's in-app history.

        Both FCM failures and persistence failures are caught and logged;
        this method **never raises**.

        Args:
            user_id: Zuralog user ID who should receive the notification.
            title: Notification title text.
            body: Notification body text.
            notification_type: Category string (e.g. ``"insight"``,
                ``"streak"``). See ``NOTIFICATION_TYPES`` in
                ``notification_log.py``.
            deep_link: Optional URI for in-app navigation (e.g.
                ``zuralog://insights/abc123``).
            data: Optional FCM data payload (all values must be strings).
            db: Optional async session. When provided, the ``NotificationLog``
                row is added to this session (caller must commit). When
                ``None``, a short-lived session is created internally.

        Returns:
            ``True`` if the push was sent to at least one device token,
            ``False`` if FCM is not configured or all sends failed.
        """
        # ------------------------------------------------------------------
        # 1. Look up user device tokens and attempt FCM delivery
        # ------------------------------------------------------------------
        push_sent = False

        if _ensure_fcm_initialized():
            try:
                from sqlalchemy import select

                from app.database import async_session as _session_factory
                from app.models.user_device import UserDevice

                async with _session_factory() as _token_db:
                    token_result = await _token_db.execute(
                        select(UserDevice.fcm_token).where(
                            UserDevice.user_id == user_id,
                            UserDevice.fcm_token.isnot(None),
                        )
                    )
                    tokens: list[str] = [row[0] for row in token_result.all() if row[0]]

                for token in tokens:
                    msg_id = self.send_notification(token, title, body, data)
                    if msg_id is not None:
                        push_sent = True

            except Exception:
                logger.exception("send_and_persist: FCM delivery failed for user=%s", user_id)

        # ------------------------------------------------------------------
        # 2. Persist to notification_logs regardless of push outcome
        # ------------------------------------------------------------------
        try:
            from app.models.notification_log import NotificationLog

            log_row = NotificationLog(
                id=str(uuid.uuid4()),
                user_id=user_id,
                title=title,
                body=body,
                type=notification_type,
                deep_link=deep_link,
                sent_at=datetime.now(timezone.utc),
            )

            if db is not None:
                db.add(log_row)
                await db.flush()
            else:
                from app.database import async_session as _factory

                async with _factory() as _persist_db:
                    _persist_db.add(log_row)
                    await _persist_db.commit()

        except Exception:
            logger.exception(
                "send_and_persist: persistence failed for user=%s — push was %s",
                user_id,
                "sent" if push_sent else "not sent",
            )

        return push_sent

    def send_data_message(
        self,
        token: str,
        data: dict[str, str],
    ) -> str | None:
        """Send a silent data-only FCM message to a device.

        Unlike send_notification(), this sends no visible notification.
        The message wakes the app in the background for processing
        (e.g., writing health data to HealthKit/Health Connect).

        Args:
            token: The device's FCM registration token.
            data: Key-value data payload. All values must be strings
                per FCM requirements.

        Returns:
            The FCM message ID on success, or None if FCM is not
            configured or the send fails.
        """
        if not _ensure_fcm_initialized():
            logger.debug("FCM not initialized — skipping data message")
            return None

        try:
            from firebase_admin import messaging  # type: ignore[import-untyped]

            message = messaging.Message(
                data=data,
                token=token,
            )
            response = messaging.send(message)
            logger.info("FCM data message sent: %s", response)
            return response
        except Exception:
            logger.exception("FCM data message send failed")
            return None
