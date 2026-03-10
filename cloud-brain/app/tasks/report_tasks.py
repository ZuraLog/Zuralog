"""
Zuralog Cloud Brain — Report Generation Celery Tasks.

Two scheduled tasks:
- ``generate_weekly_reports_task``: Monday at 6am UTC — generate weekly
  reports for all users with sufficient data.
- ``generate_monthly_reports_task``: 1st of month at 6am UTC — generate
  monthly reports for all users.

Both tasks use asyncio.run() for async DB access, matching the pattern
established in fitbit_sync.py and other Celery tasks.
"""

from __future__ import annotations

import asyncio
import dataclasses
import logging
from datetime import date, timedelta

import sentry_sdk
from sqlalchemy import select

from app.database import worker_async_session as async_session
from app.models.report import Report, ReportType
from app.models.user import User
from app.services.report_generator import ReportGenerator
from app.worker import celery_app

logger = logging.getLogger(__name__)


def _report_to_json(report_obj) -> dict:
    """Convert a WeeklyReport or MonthlyReport dataclass to a JSON-safe dict.

    Converts date/datetime fields to ISO strings.

    Args:
        report_obj: A WeeklyReport or MonthlyReport dataclass instance.

    Returns:
        JSON-serialisable dict.
    """
    raw = dataclasses.asdict(report_obj)
    for key, value in raw.items():
        if isinstance(value, date):
            raw[key] = value.isoformat()
        elif hasattr(value, "isoformat"):
            raw[key] = value.isoformat()
    return raw


# ---------------------------------------------------------------------------
# Weekly report task
# ---------------------------------------------------------------------------


@celery_app.task(name="app.tasks.report.generate_weekly_reports_task")
def generate_weekly_reports_task() -> dict:
    """Generate weekly reports for all users.

    Intended to run on Mondays at 6am UTC via Celery Beat. Generates a
    report for the previous calendar week (Mon–Sun) for every active user.
    Skips users who already have a report for that period (idempotent).

    Returns:
        Dict with ``generated`` and ``skipped`` counts.
    """
    logger.info("generate_weekly_reports_task: starting weekly report generation")
    sentry_sdk.set_tag("task.type", "weekly")

    async def _run() -> dict:
        generator = ReportGenerator()
        generated = 0
        skipped = 0

        # Previous Monday (last full week)
        today = date.today()
        days_since_monday = today.weekday()
        this_monday = today - timedelta(days=days_since_monday)
        week_start = this_monday - timedelta(days=7)

        async with async_session() as db:
            users_result = await db.execute(select(User))
            users = users_result.scalars().all()

            for user in users:
                try:
                    # Idempotency check
                    existing_stmt = select(Report).where(
                        Report.user_id == user.id,
                        Report.type == ReportType.WEEKLY.value,
                        Report.period_start == week_start,
                    )
                    existing_result = await db.execute(existing_stmt)
                    if existing_result.scalar_one_or_none():
                        skipped += 1
                        continue

                    with sentry_sdk.start_span(op="task.report_generation", description="generate_weekly"):
                        report = await generator.generate_weekly(
                            user_id=user.id,
                            week_start=week_start,
                            session=db,
                        )

                    week_end = week_start + timedelta(days=6)
                    db_report = Report(
                        user_id=user.id,
                        type=ReportType.WEEKLY.value,
                        period_start=week_start,
                        period_end=week_end,
                        data=_report_to_json(report),
                    )
                    db.add(db_report)
                    await db.commit()
                    generated += 1

                    logger.debug(
                        "generate_weekly_reports_task: generated for user %s week=%s",
                        user.id,
                        week_start,
                    )

                except Exception as exc:  # noqa: BLE001
                    logger.exception(
                        "generate_weekly_reports_task: failed for user %s: %s",
                        user.id,
                        exc,
                    )
                    sentry_sdk.capture_exception(exc)
                    await db.rollback()

        logger.info(
            "generate_weekly_reports_task: complete — generated=%d skipped=%d",
            generated,
            skipped,
        )
        return {"generated": generated, "skipped": skipped}

    return asyncio.run(_run())


# ---------------------------------------------------------------------------
# Monthly report task
# ---------------------------------------------------------------------------


@celery_app.task(name="app.tasks.report.generate_monthly_reports_task")
def generate_monthly_reports_task() -> dict:
    """Generate monthly reports for all users.

    Intended to run on the 1st of each month at 6am UTC via Celery Beat.
    Generates a report for the previous calendar month for every active user.
    Skips users who already have a report for that period (idempotent).

    Returns:
        Dict with ``generated`` and ``skipped`` counts.
    """
    logger.info("generate_monthly_reports_task: starting monthly report generation")
    sentry_sdk.set_tag("task.type", "monthly")

    async def _run() -> dict:
        generator = ReportGenerator()
        generated = 0
        skipped = 0

        today = date.today()
        # Previous month's first day
        if today.month == 1:
            month_start = date(today.year - 1, 12, 1)
        else:
            month_start = date(today.year, today.month - 1, 1)

        async with async_session() as db:
            users_result = await db.execute(select(User))
            users = users_result.scalars().all()

            for user in users:
                try:
                    # Idempotency check
                    existing_stmt = select(Report).where(
                        Report.user_id == user.id,
                        Report.type == ReportType.MONTHLY.value,
                        Report.period_start == month_start,
                    )
                    existing_result = await db.execute(existing_stmt)
                    if existing_result.scalar_one_or_none():
                        skipped += 1
                        continue

                    with sentry_sdk.start_span(op="task.report_generation", description="generate_monthly"):
                        report = await generator.generate_monthly(
                            user_id=user.id,
                            month_start=month_start,
                            session=db,
                        )

                    db_report = Report(
                        user_id=user.id,
                        type=ReportType.MONTHLY.value,
                        period_start=report.period_start,
                        period_end=report.period_end,
                        data=_report_to_json(report),
                    )
                    db.add(db_report)
                    await db.commit()
                    generated += 1

                    logger.debug(
                        "generate_monthly_reports_task: generated for user %s month=%s",
                        user.id,
                        month_start,
                    )

                except Exception as exc:  # noqa: BLE001
                    logger.exception(
                        "generate_monthly_reports_task: failed for user %s: %s",
                        user.id,
                        exc,
                    )
                    sentry_sdk.capture_exception(exc)
                    await db.rollback()

        logger.info(
            "generate_monthly_reports_task: complete — generated=%d skipped=%d",
            generated,
            skipped,
        )
        return {"generated": generated, "skipped": skipped}

    return asyncio.run(_run())
