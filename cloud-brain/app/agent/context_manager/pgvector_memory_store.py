"""
Zuralog Cloud Brain — PgVector Memory Store.

Production vector-backed memory store using pgvector (Supabase) for
similarity search and OpenAI text-embedding-3-small for embeddings.

Replaces PineconeMemoryStore. Uses the same embedding model and
dimensions (1536) so existing embeddings would be compatible.

All DB calls use asyncpg via SQLAlchemy async sessions.
Embedding calls use the synchronous OpenAI SDK wrapped in asyncio.to_thread
to avoid blocking the event loop.

Implements the full MemoryStore protocol plus list_memories, delete_memory,
and clear_memories for compatibility with memory_routes.py.
"""

from __future__ import annotations

import asyncio
import logging
import uuid
from typing import Any

from sqlalchemy import text

from app.agent.context_manager.memory_store import MemoryItem
from app.database import async_session

logger = logging.getLogger(__name__)

_EMBEDDING_MODEL = "text-embedding-3-small"
_EMBEDDING_DIMENSIONS = 1536


def _vec_str(embedding: list[float]) -> str:
    """Serialize a float list to pgvector literal format: '[v1,v2,...]'."""
    return "[" + ",".join(f"{v:.8f}" for v in embedding) + "]"


class PgVectorMemoryStore:
    """Vector-backed memory store using pgvector and OpenAI embeddings.

    Each user's memories are isolated by WHERE user_id = :user_id on every
    query. RLS provides a second layer of isolation at the DB level.

    Attributes:
        is_available: True when OpenAI is configured and the store is ready.
    """

    def __init__(self) -> None:
        from app.config import settings

        api_key = settings.openai_api_key.get_secret_value()
        self._openai_client: Any = None
        if api_key:
            try:
                from openai import OpenAI

                self._openai_client = OpenAI(api_key=api_key)
                logger.info("PgVectorMemoryStore initialised.")
            except Exception:
                logger.warning("PgVectorMemoryStore: failed to create OpenAI client.", exc_info=True)
        else:
            logger.info("PgVectorMemoryStore: OPENAI_API_KEY not set — embedding calls will fail.")

    @property
    def is_available(self) -> bool:
        """True when the OpenAI client is configured."""
        return self._openai_client is not None

    def _embed_sync(self, text_to_embed: str) -> list[float]:
        """Synchronous embedding call (run via asyncio.to_thread)."""
        if self._openai_client is None:
            raise RuntimeError("OpenAI client not configured — set OPENAI_API_KEY.")
        response = self._openai_client.embeddings.create(
            model=_EMBEDDING_MODEL,
            input=text_to_embed,
        )
        return response.data[0].embedding

    async def _embed(self, text_to_embed: str) -> list[float] | None:
        """Async wrapper: embeds text without blocking the event loop."""
        try:
            return await asyncio.to_thread(self._embed_sync, text_to_embed)
        except Exception:
            logger.exception("Embedding failed for text: %.50s", text_to_embed)
            return None

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
        """Embed content and insert into user_memories."""
        embedding = await self._embed(content)
        async with async_session() as db:
            await db.execute(
                text(
                    """
                    INSERT INTO user_memories
                        (id, user_id, content, category, embedding, source_conversation_id)
                    VALUES
                        (:id, :user_id, :content, :category,
                         CAST(:embedding AS vector), :source_conv_id)
                    """
                ),
                {
                    "id": str(uuid.uuid4()),
                    "user_id": user_id,
                    "content": content,
                    "category": category,
                    "embedding": _vec_str(embedding) if embedding else None,
                    "source_conv_id": source_conversation_id,
                },
            )
            await db.commit()

    async def query(
        self,
        user_id: str,
        query_text: str = "",
        limit: int = 5,
    ) -> list[MemoryItem]:
        """Retrieve top-k memories by cosine similarity.

        Returns an empty list if query_text is empty or embedding fails.

        Args:
            user_id: The user whose memories to search.
            query_text: The query to embed and match against.
            limit: Maximum number of results to return.

        Returns:
            List of MemoryItem objects ordered by descending similarity score.
        """
        if not query_text:
            return []
        embedding = await self._embed(query_text)
        if embedding is None:
            return []

        vec = _vec_str(embedding)
        async with async_session() as db:
            result = await db.execute(
                text(
                    """
                    SELECT id, content, category,
                           1 - (embedding <=> CAST(:embedding AS vector)) AS score
                    FROM user_memories
                    WHERE user_id = :user_id
                      AND embedding IS NOT NULL
                    ORDER BY embedding <=> CAST(:embedding AS vector)
                    LIMIT :limit
                    """
                ),
                {"user_id": user_id, "embedding": vec, "limit": limit},
            )
            rows = result.fetchall()

        return [
            MemoryItem(
                id=str(row.id),
                content=str(row.content),
                category=str(row.category),
                score=float(row.score),
            )
            for row in rows
        ]

    async def delete(self, memory_id: str) -> None:
        """Hard-delete a memory by ID."""
        async with async_session() as db:
            await db.execute(
                text("DELETE FROM user_memories WHERE id = :id"),
                {"id": memory_id},
            )
            await db.commit()

    # ------------------------------------------------------------------
    # Extended interface (for memory_routes.py)
    # ------------------------------------------------------------------

    async def delete_memory(self, memory_id: str) -> bool:
        """Delete a memory by ID. Returns True when acknowledged."""
        await self.delete(memory_id)
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
