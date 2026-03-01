"""
Zuralog Cloud Brain — Product Analytics Service.

Centralized PostHog integration for server-side event tracking,
user identification, group analytics, and feature flag evaluation.

All PostHog calls are non-blocking (batched and flushed in background
threads). Failures are logged but never raise — analytics must not
break application logic.
"""

import logging
from datetime import datetime, timezone
from typing import Any

import posthog

from app.config import settings

logger = logging.getLogger(__name__)


class AnalyticsService:
    """PostHog analytics client wrapper.

    Provides a clean interface for event capture, user identification,
    group analytics, and feature flag evaluation. All methods are
    fire-and-forget — errors are caught and logged.

    Attributes:
        enabled: Whether PostHog is active (False when API key is missing).
    """

    def __init__(self) -> None:
        """Initialize the PostHog client.

        If POSTHOG_API_KEY is empty, analytics is disabled and all
        methods become no-ops. This allows local development without
        PostHog credentials.
        """
        self.enabled = bool(settings.posthog_api_key)
        if self.enabled:
            posthog.api_key = settings.posthog_api_key
            posthog.host = settings.posthog_host
            posthog.debug = settings.app_env == "development"
            posthog.on_error = self._on_error
            # Batching config: flush every 100 events or every 5 seconds
            posthog.max_queue_size = 100
            posthog.flush_interval = 5.0
            logger.info("AnalyticsService initialized (PostHog, host=%s)", settings.posthog_host)
        else:
            logger.info("AnalyticsService disabled (no POSTHOG_API_KEY)")

    @staticmethod
    def _on_error(error: Exception, items: list) -> None:
        """PostHog error callback — log but never raise."""
        logger.warning("PostHog flush error: %s (items=%d)", error, len(items))

    def capture(
        self,
        distinct_id: str,
        event: str,
        properties: dict[str, Any] | None = None,
        groups: dict[str, str] | None = None,
        timestamp: datetime | None = None,
    ) -> None:
        """Capture an analytics event.

        Args:
            distinct_id: The user's unique identifier (Supabase UID).
            event: Event name (e.g., 'health_data_ingested').
            properties: Optional event properties dict.
            groups: Optional group associations (e.g., {'subscription': 'pro'}).
            timestamp: Optional event timestamp (defaults to now).
        """
        if not self.enabled:
            return
        try:
            posthog.capture(
                distinct_id=distinct_id,
                event=event,
                properties=properties or {},
                groups=groups,
                timestamp=timestamp or datetime.now(timezone.utc),
            )
        except Exception:
            logger.warning("PostHog capture failed: event=%s, user=%s", event, distinct_id, exc_info=True)

    def identify(
        self,
        distinct_id: str,
        properties: dict[str, Any] | None = None,
    ) -> None:
        """Identify a user with properties.

        Sets persistent user properties in PostHog for segmentation
        and cohort analysis.

        Args:
            distinct_id: The user's unique identifier (Supabase UID).
            properties: User properties dict (e.g., subscription_tier,
                        connected_integrations, platform, signup_date).
        """
        if not self.enabled:
            return
        try:
            posthog.identify(
                distinct_id=distinct_id,
                properties=properties or {},
            )
        except Exception:
            logger.warning("PostHog identify failed: user=%s", distinct_id, exc_info=True)

    def group_identify(
        self,
        group_type: str,
        group_key: str,
        properties: dict[str, Any] | None = None,
    ) -> None:
        """Identify a group with properties.

        Used for subscription tier grouping and platform grouping.

        Args:
            group_type: Group type (e.g., 'subscription', 'platform').
            group_key: Group identifier (e.g., 'pro', 'ios').
            properties: Group properties dict.
        """
        if not self.enabled:
            return
        try:
            posthog.group_identify(
                group_type=group_type,
                group_key=group_key,
                properties=properties or {},
            )
        except Exception:
            logger.warning(
                "PostHog group_identify failed: type=%s, key=%s",
                group_type,
                group_key,
                exc_info=True,
            )

    def alias(self, previous_id: str, distinct_id: str) -> None:
        """Create an alias linking two distinct_ids.

        Used to link a waitlist email (pre-signup) to a Supabase UID
        (post-signup) so all pre-signup activity is attributed correctly.

        Args:
            previous_id: The previous distinct_id (e.g., email address).
            distinct_id: The new distinct_id (e.g., Supabase UID).
        """
        if not self.enabled:
            return
        try:
            posthog.alias(previous_id=previous_id, distinct_id=distinct_id)
        except Exception:
            logger.warning("PostHog alias failed", exc_info=True)

    def is_feature_enabled(
        self,
        flag_key: str,
        distinct_id: str,
        default: bool = False,
    ) -> bool:
        """Check if a feature flag is enabled for a user.

        Uses PostHog's server-side feature flag evaluation with
        periodic polling for flag definitions.

        Args:
            flag_key: Feature flag key (e.g., 'enhanced-analytics-api').
            distinct_id: The user's unique identifier.
            default: Default value if evaluation fails.

        Returns:
            True if the flag is enabled, False otherwise.
        """
        if not self.enabled:
            return default
        try:
            result = posthog.feature_enabled(flag_key, distinct_id)
            return bool(result) if result is not None else default
        except Exception:
            logger.warning(
                "PostHog feature_flag failed: flag=%s, user=%s",
                flag_key,
                distinct_id,
                exc_info=True,
            )
            return default

    def shutdown(self) -> None:
        """Flush all pending events and shut down the client.

        Must be called during application shutdown to ensure no
        events are lost. Blocks until the queue is empty.
        """
        if not self.enabled:
            return
        try:
            posthog.flush()
            posthog.shutdown()
            logger.info("AnalyticsService shut down (PostHog flushed)")
        except Exception:
            logger.warning("PostHog shutdown failed", exc_info=True)
