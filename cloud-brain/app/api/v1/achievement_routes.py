"""
Zuralog Cloud Brain — Achievement API Routes.

Provides endpoints for fetching a user's achievements, both as a
complete catalogue grouped by category and as a recent-unlocks feed.

Endpoints:
    GET /api/v1/achievements          — All achievements grouped by category
    GET /api/v1/achievements/recent   — Last 5 unlocked achievements
"""

import logging
from collections import defaultdict

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.deps import get_authenticated_user_id
from app.database import get_db
from app.models.achievement import ACHIEVEMENT_REGISTRY
from app.services.achievement_tracker import AchievementTracker

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/achievements",
    tags=["achievements"],
)


@router.get("")
async def get_all_achievements(
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Return all achievements with locked/unlocked state, grouped by category.

    Every achievement key in the registry is present in the response.
    Locked achievements have ``unlocked=false`` and ``unlocked_at=null``.

    Args:
        user_id: Authenticated user ID from JWT (injected by dependency).
        db: Injected async database session.

    Returns:
        Dict with a ``categories`` key mapping category name to a list of
        achievement dicts, and a ``summary`` with counts.
    """
    tracker = AchievementTracker(session=db)
    all_achievements = await tracker.get_all_achievements(user_id)

    # Group by category preserving registry insertion order
    grouped: dict[str, list[dict]] = defaultdict(list)
    for achievement in all_achievements:
        grouped[achievement["category"]].append(achievement)

    total = len(all_achievements)
    unlocked_count = sum(1 for a in all_achievements if a["unlocked"])

    return {
        "categories": dict(grouped),
        "summary": {
            "total": total,
            "unlocked": unlocked_count,
            "locked": total - unlocked_count,
        },
    }


@router.get("/recent")
async def get_recent_achievements(
    user_id: str = Depends(get_authenticated_user_id),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Return the last 5 unlocked achievements, most recent first.

    Args:
        user_id: Authenticated user ID from JWT (injected by dependency).
        db: Injected async database session.

    Returns:
        Dict with a ``achievements`` list of up to 5 recently unlocked
        achievements, enriched with registry metadata.
    """
    tracker = AchievementTracker(session=db)
    recent = await tracker.get_recent_achievements(user_id, limit=5)

    items = []
    for achievement in recent:
        meta = ACHIEVEMENT_REGISTRY.get(achievement.achievement_key, {})
        items.append(
            {
                "achievement_key": achievement.achievement_key,
                "title": meta.get("title", achievement.achievement_key),
                "description": meta.get("description", ""),
                "category": meta.get("category", ""),
                "icon": meta.get("icon", ""),
                "unlocked_at": achievement.unlocked_at,
            }
        )

    return {"achievements": items}
