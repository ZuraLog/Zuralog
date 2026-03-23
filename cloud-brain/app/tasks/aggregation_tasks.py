"""Celery tasks for health data aggregation."""
import asyncio
import logging
from datetime import date, datetime, timezone

from celery import shared_task
from sqlalchemy import select, text
from sqlalchemy.dialects.postgresql import insert as pg_insert

from app.database import worker_async_session
from app.models.health_event import HealthEvent
from app.models.metric_definition import MetricDefinition
from app.models.daily_summary import DailySummary
from app.services.aggregation_service import aggregate_events

logger = logging.getLogger(__name__)


@shared_task(name="app.tasks.aggregation_tasks.recompute_daily_summaries_for_batch")
def recompute_daily_summaries_for_batch(
    batch: list[dict],   # [{"user_id": str, "local_date": "YYYY-MM-DD", "metric_type": str}]
) -> dict:
    """Recompute daily_summaries for all (user, date, metric) combos in batch."""
    return asyncio.run(_recompute_batch(batch))


async def _recompute_batch(batch: list[dict]) -> dict:
    success = 0
    failures = []

    async with worker_async_session() as db:
        for item in batch:
            try:
                user_id = item["user_id"]
                local_date = date.fromisoformat(item["local_date"])
                metric_type = item["metric_type"]

                # Look up metric definition
                md_row = await db.execute(
                    select(MetricDefinition).where(MetricDefinition.metric_type == metric_type)
                )
                md = md_row.scalar_one_or_none()
                if not md:
                    continue  # Unknown metric — skip aggregation

                # Get all non-deleted events
                events_result = await db.execute(
                    select(HealthEvent.value, HealthEvent.recorded_at, HealthEvent.created_at)
                    .where(
                        HealthEvent.user_id == user_id,
                        HealthEvent.local_date == local_date,
                        HealthEvent.metric_type == metric_type,
                        HealthEvent.deleted_at.is_(None),
                    )
                )
                events = [
                    {"value": r.value, "recorded_at": r.recorded_at, "created_at": r.created_at}
                    for r in events_result.fetchall()
                ]

                result = aggregate_events(events, fn=md.aggregation_fn, unit=md.unit)
                if result is None:
                    await db.execute(
                        text("DELETE FROM daily_summaries WHERE user_id=:uid AND date=:d AND metric_type=:mt"),
                        {"uid": user_id, "d": local_date, "mt": metric_type},
                    )
                else:
                    stmt = pg_insert(DailySummary).values(
                        user_id=user_id, date=local_date,
                        metric_type=metric_type, value=result.value,
                        unit=result.unit, event_count=result.event_count,
                        is_stale=False, computed_at=datetime.now(tz=timezone.utc),
                    ).on_conflict_do_update(
                        constraint="uq_daily_summaries_user_date_metric",
                        set_={"value": result.value, "event_count": result.event_count,
                              "is_stale": False, "computed_at": datetime.now(tz=timezone.utc)},
                    )
                    await db.execute(stmt)

                await db.commit()
                success += 1
            except Exception as exc:
                logger.exception("Aggregation failed for %s", item)
                failures.append({"item": item, "error": str(exc)})
                try:
                    await db.execute(
                        text("UPDATE daily_summaries SET is_stale=true "
                             "WHERE user_id=:uid AND date=:d AND metric_type=:mt"),
                        {"uid": item["user_id"], "d": item["local_date"], "mt": item["metric_type"]},
                    )
                    await db.commit()
                except Exception:
                    pass

    return {"success": success, "failures": failures}


@shared_task(name="app.tasks.aggregation_tasks.recompute_stale_summaries")
def recompute_stale_summaries() -> dict:
    """Celery Beat periodic job: recompute all daily_summaries rows with is_stale=true."""
    return asyncio.run(_recompute_stale())


async def _recompute_stale() -> dict:
    async with worker_async_session() as db:
        stale_rows = await db.execute(
            text("""
                SELECT user_id::text, date::text, metric_type
                FROM daily_summaries
                WHERE is_stale = true
                ORDER BY computed_at ASC
                LIMIT 1000
            """)
        )
        batch = [
            {"user_id": r.user_id, "local_date": r.date, "metric_type": r.metric_type}
            for r in stale_rows.fetchall()
        ]

    if not batch:
        return {"processed": 0}

    return await _recompute_batch(batch)
