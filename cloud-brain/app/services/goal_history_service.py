"""Computes per-goal progress history from daily_summaries.

Returns the last N days of (date, value) pairs for a goal's metric.
Used to render the sparkline/progress chart in the Flutter Goal card.
"""
from __future__ import annotations

from datetime import date, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.daily_summary import DailySummary


async def get_goal_history(
    db: AsyncSession,
    user_id: str,
    metric: str,
    days: int = 30,
) -> list[dict]:
    """Return the last `days` daily values for a metric, oldest-first.

    Args:
        db: Async database session.
        user_id: The authenticated user's ID.
        metric: The metric_type to look up in daily_summaries.
        days: How many calendar days to look back (default 30).

    Returns:
        List of {"date": "YYYY-MM-DD", "value": float} dicts, oldest first.
        Returns [] if no data exists.
    """
    cutoff = date.today() - timedelta(days=days)
    result = await db.execute(
        select(DailySummary.date, DailySummary.value)
        .where(
            DailySummary.user_id == user_id,
            DailySummary.metric_type == metric,
            DailySummary.date >= cutoff,
            DailySummary.is_stale.is_(False),
        )
        .order_by(DailySummary.date.asc())
    )
    return [{"date": str(row.date), "value": row.value} for row in result.fetchall()]
