"""Shared helper to resolve a user's local date from their timezone preference."""
import zoneinfo
from datetime import date, datetime, timezone

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession


async def get_user_local_date(db: AsyncSession, user_id: str) -> date:
    """Return the user's current local date based on their IANA timezone preference."""
    row = await db.execute(
        text("SELECT timezone FROM user_preferences WHERE user_id = :uid"),
        {"uid": user_id},
    )
    iana_tz = row.scalar_one_or_none() or "UTC"
    try:
        user_tz = zoneinfo.ZoneInfo(iana_tz)
    except Exception:
        user_tz = zoneinfo.ZoneInfo("UTC")
    return datetime.now(tz=user_tz).date()
