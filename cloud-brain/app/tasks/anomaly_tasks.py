"""Celery task: run anomaly detection after new health data is ingested.

The single exported task ``check_anomalies_for_user`` is intended to be
enqueued immediately after a successful health-data ingest so that the
system can surface critical metric deviations to the user in near real-time.

Workflow
--------
1. Run :class:`~app.services.anomaly_detector.AnomalyDetector` against the
   user's most recent 30 days of data.
2. For each ``elevated`` or ``critical`` anomaly, attempt to persist an
   ``Insight`` record via :func:`_store_anomaly_insight` (soft-import —
   the ``Insight`` model is created in Task 2.6).
3. For each ``critical`` anomaly, fire a push notification via
   :class:`~app.services.push_service.PushService` to all registered
   devices for the user.

The task is safe to retry — both the insight write and push-notification
paths are idempotent or tolerant of duplicate calls.
"""

from __future__ import annotations

import asyncio
import logging
from typing import Any

import sentry_sdk
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import worker_async_session as async_session
from app.services.anomaly_detector import AnomalyDetector, AnomalyResult
from app.services.push_service import PushService
from app.worker import celery_app

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Insight persistence — soft import (Insight model created in Task 2.6)
# ---------------------------------------------------------------------------


async def _store_anomaly_insight(
    user_id: str,
    anomaly: AnomalyResult,
    db: AsyncSession,
) -> None:
    """Persist an anomaly as an Insight record (soft import).

    If the ``Insight`` model does not yet exist (Task 2.6 not yet merged),
    this function logs a warning and returns without raising. This allows
    the anomaly-detection pipeline to operate end-to-end before the Insight
    model is available.

    Args:
        user_id: Owner of the anomaly insight.
        anomaly: The detected :class:`~app.services.anomaly_detector.AnomalyResult`.
        db: Active async database session.
    """
    insight_data: dict[str, Any] = {
        "user_id": user_id,
        "type": "anomaly",
        "metric": anomaly.metric,
        "severity": anomaly.severity,
        "direction": anomaly.direction,
        "current_value": anomaly.current_value,
        "baseline_mean": anomaly.baseline_mean,
        "baseline_stddev": anomaly.baseline_stddev,
        "deviation_magnitude": anomaly.deviation_magnitude,
    }

    try:
        from app.models.insight import Insight  # noqa: PLC0415
    except ImportError:
        logger.warning(
            "_store_anomaly_insight: Insight model not yet available — "
            "skipping persistence for metric='%s' user='%s'. Data: %s",
            anomaly.metric,
            user_id,
            insight_data,
        )
        return

    try:
        insight = Insight(**insight_data)
        db.add(insight)
        await db.commit()
        logger.info(
            "_store_anomaly_insight: stored %s anomaly insight for user='%s' metric='%s'",
            anomaly.severity,
            user_id,
            anomaly.metric,
        )
    except Exception as exc:  # noqa: BLE001
        logger.exception(
            "_store_anomaly_insight: failed to persist insight for user='%s' metric='%s': %s",
            user_id,
            anomaly.metric,
            exc,
        )
        await db.rollback()


# ---------------------------------------------------------------------------
# Push notification helper
# ---------------------------------------------------------------------------


async def _send_critical_push(user_id: str, anomaly: AnomalyResult, db: AsyncSession) -> None:
    """Send a push notification for a critical anomaly to all user devices.

    Looks up registered FCM tokens from ``UserDevice`` for *user_id* and
    sends a notification via :class:`~app.services.push_service.PushService`.
    Silently skips if FCM is not configured or no devices are registered.

    Args:
        user_id: The user whose devices should be notified.
        anomaly: The :class:`~app.services.anomaly_detector.AnomalyResult`
            that triggered this notification.
        db: Active async database session.
    """
    push = PushService()
    if not push.is_available:
        logger.debug(
            "_send_critical_push: FCM not configured — skipping push for user='%s'",
            user_id,
        )
        return

    try:
        from app.models.user_device import UserDevice  # noqa: PLC0415

        stmt = select(UserDevice).where(UserDevice.user_id == user_id)
        result = await db.execute(stmt)
        devices = result.scalars().all()

        if not devices:
            logger.debug("_send_critical_push: no devices registered for user='%s'", user_id)
            return

        direction_label = "high" if anomaly.direction == "high" else "low"
        title = f"Health Alert: {anomaly.metric.replace('_', ' ').title()}"
        body = (
            f"Your {anomaly.metric.replace('_', ' ')} is unusually {direction_label} today "
            f"({anomaly.current_value:.1f} vs avg {anomaly.baseline_mean:.1f}). "
            "Tap to review."
        )
        data = {
            "type": "anomaly_alert",
            "metric": anomaly.metric,
            "severity": anomaly.severity,
            "direction": anomaly.direction,
        }

        for device in devices:
            push.send_notification(token=device.fcm_token, title=title, body=body, data=data)
            logger.info(
                "_send_critical_push: sent critical alert to device for user='%s' metric='%s'",
                user_id,
                anomaly.metric,
            )

    except Exception as exc:  # noqa: BLE001
        logger.exception(
            "_send_critical_push: error sending push for user='%s' metric='%s': %s",
            user_id,
            anomaly.metric,
            exc,
        )


# ---------------------------------------------------------------------------
# Celery task
# ---------------------------------------------------------------------------


@celery_app.task(
    name="app.tasks.anomaly_tasks.check_anomalies_for_user",
    bind=True,
    max_retries=3,
    default_retry_delay=60,
)
def check_anomalies_for_user(self, user_id: str) -> dict[str, Any]:
    """Detect metric anomalies for a user and surface critical findings.

    Enqueue this task after any successful health-data ingest to give the
    user near-real-time feedback on unusual metric changes.

    Args:
        user_id: The Zuralog user ID to analyse.

    Returns:
        A summary dict with keys:
        - ``"user_id"`` — the analysed user.
        - ``"anomalies_found"`` — total elevated + critical anomalies detected.
        - ``"critical_count"`` — number of critical anomalies.
        - ``"elevated_count"`` — number of elevated anomalies.
        - ``"metrics"`` — list of affected metric names.
    """
    logger.info("check_anomalies_for_user: starting for user='%s'", user_id)

    async def _run() -> dict[str, Any]:
        async with async_session() as db:
            try:
                detector = AnomalyDetector()
                anomalies = await detector.check_user_metrics(user_id, db)
            except Exception as exc:  # noqa: BLE001
                logger.exception(
                    "check_anomalies_for_user: detection failed for user='%s': %s",
                    user_id,
                    exc,
                )
                sentry_sdk.capture_exception(exc)
                raise

            elevated: list[AnomalyResult] = []
            critical: list[AnomalyResult] = []

            for anomaly in anomalies:
                if anomaly.severity == "critical":
                    critical.append(anomaly)
                elif anomaly.severity == "elevated":
                    elevated.append(anomaly)

            # Persist insight records for all anomalies (elevated + critical).
            for anomaly in elevated + critical:
                await _store_anomaly_insight(user_id, anomaly, db)

            # Send push notifications for critical anomalies only.
            for anomaly in critical:
                await _send_critical_push(user_id, anomaly, db)

            summary = {
                "user_id": user_id,
                "anomalies_found": len(elevated) + len(critical),
                "critical_count": len(critical),
                "elevated_count": len(elevated),
                "metrics": [a.metric for a in elevated + critical],
            }

            logger.info(
                "check_anomalies_for_user: complete for user='%s' — "
                "%d elevated, %d critical",
                user_id,
                len(elevated),
                len(critical),
            )
            return summary

    try:
        return asyncio.run(_run())
    except Exception as exc:  # noqa: BLE001
        logger.exception(
            "check_anomalies_for_user: unhandled error for user='%s': %s",
            user_id,
            exc,
        )
        sentry_sdk.capture_exception(exc)
        raise self.retry(exc=exc)
