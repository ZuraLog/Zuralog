"""
Zuralog Cloud Brain — PgVector Memory Store.

Stores user memories in Supabase (pgvector table) and retrieves them
without any external embedding API. All memories for a user are fetched
and the most recent ones are returned — appropriate for the realistic
scale of health coaching memories (typically 10-50 facts per user).

No external API dependencies. Pure Postgres via SQLAlchemy async sessions.
"""

from __future__ import annotations

import logging
import uuid

from sqlalchemy import text

from app.agent.context_manager.memory_store import MemoryItem
from app.database import async_session

logger = logging.getLogger(__name__)


class PgVectorMemoryStore:
    """Memory store backed by Supabase postgres.

    Memories are stored as plain text. Retrieval fetches the most recent
    facts for the user — no vector similarity search, no external API.

    Attributes:
        is_available: Always True — no external dependency required.
    """

    @property
    def is_available(self) -> bool:
        return True

    # ------------------------------------------------------------------
    # MemoryStore protocol methods
    # ------------------------------------------------------------------

    async def add(
        self,
        user_id: str,
        content: str,
        category: str,
        source_conversation_id: str | None = None,
    ) -> None:
        """Insert a memory fact. Embedding column is left NULL."""
        async with async_session() as db:
            await db.execute(
                text(
                    """
                    INSERT INTO user_memories
                        (id, user_id, content, category, embedding, source_conversation_id)
                    VALUES
                        (:id, :user_id, :content, :category, NULL, :source_conv_id)
                    """
                ),
                {
                    "id": str(uuid.uuid4()),
                    "user_id": user_id,
                    "content": content,
                    "category": category,
                    "source_conv_id": source_conversation_id,
                },
            )
            await db.commit()

    async def query(
        self,
        user_id: str,
        query_text: str = "",  # noqa: ARG002 — kept for interface compatibility
        limit: int = 5,
    ) -> list[MemoryItem]:
        """Return the most recent memories for the user.

        query_text is accepted for interface compatibility but not used —
        we return the newest facts rather than doing similarity search.
        """
        async with async_session() as db:
            result = await db.execute(
                text(
                    """
                    SELECT id, content, category
                    FROM user_memories
                    WHERE user_id = :user_id
                    ORDER BY created_at DESC
                    LIMIT :limit
                    """
                ),
                {"user_id": user_id, "limit": limit},
            )
            rows = result.fetchall()

        return [
            MemoryItem(
                id=str(row.id),
                content=str(row.content),
                category=str(row.category),
                score=1.0,
            )
            for row in rows
        ]

    async def delete(self, memory_id: str, user_id: str) -> None:
        """Hard-delete a memory by ID, scoped to the owning user."""
        async with async_session() as db:
            await db.execute(
                text("DELETE FROM user_memories WHERE id = :id AND user_id = :user_id"),
                {"id": memory_id, "user_id": user_id},
            )
            await db.commit()

    # ------------------------------------------------------------------
    # Extended interface (for memory_routes.py)
    # ------------------------------------------------------------------

    async def delete_memory(self, memory_id: str, user_id: str) -> bool:
        """Delete a memory by ID, scoped to the owning user."""
        async with async_session() as db:
            await db.execute(
                text("DELETE FROM user_memories WHERE id = :id AND user_id = :user_id"),
                {"id": memory_id, "user_id": user_id},
            )
            await db.commit()
        return True

    async def list_memories(self, user_id: str) -> list[MemoryItem]:
        """List all memories for a user ordered by creation time (newest first)."""
        async with async_session() as db:
            result = await db.execute(
                text(
                    """
                    SELECT id, content, category, 1.0 AS score
                    FROM user_memories
                    WHERE user_id = :user_id
                    ORDER BY created_at DESC
                    """
                ),
                {"user_id": user_id},
            )
            rows = result.fetchall()
        return [
            MemoryItem(id=str(r.id), content=str(r.content), category=str(r.category), score=1.0)
            for r in rows
        ]

    async def clear_memories(self, user_id: str) -> None:
        """Delete all memories for a user."""
        async with async_session() as db:
            await db.execute(
                text("DELETE FROM user_memories WHERE user_id = :user_id"),
                {"user_id": user_id},
            )
            await db.commit()
