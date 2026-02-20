"""
Life Logger Cloud Brain — User Profile Service.

Retrieves user profile data from the local database for use by the
Orchestrator. Reads from the ``users`` table created in Phase 1.1
rather than returning hardcoded stubs.
"""

import logging
from typing import Any

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

logger = logging.getLogger(__name__)


class UserProfileService:
    """Retrieves user profile and preferences from the database.

    Uses the existing ``users`` table and the established
    ``get_db`` dependency pattern from Phase 1.2.

    Attributes:
        _session: The async database session.
    """

    def __init__(self, session: AsyncSession) -> None:
        """Create a new UserProfileService.

        Args:
            session: An async SQLAlchemy session (injected via Depends).
        """
        self._session = session

    async def get_profile(self, user_id: str) -> dict[str, Any]:
        """Retrieve the profile for a given user.

        Queries the ``users`` table for the user's email and
        metadata. Returns a structured dict the Orchestrator can
        inject into the LLM system prompt.

        Args:
            user_id: The Supabase auth UID.

        Returns:
            A dict with profile fields. Returns a minimal dict
            with ``found=False`` if the user does not exist.
        """
        result = await self._session.execute(
            text("SELECT id, email, created_at, updated_at FROM users WHERE id = :uid"),
            {"uid": user_id},
        )
        row = result.mappings().first()

        if row is None:
            logger.warning("User profile not found for uid '%s'", user_id)
            return {"found": False, "user_id": user_id}

        return {
            "found": True,
            "user_id": str(row["id"]),
            "email": row["email"],
            "created_at": str(row["created_at"]),
            "updated_at": str(row["updated_at"]),
            # Future: coach_persona, goals, connected_apps
            # will be added when the schema expands.
            "coach_persona": "default",
            "goals": {},
            "connected_apps": [],
        }
