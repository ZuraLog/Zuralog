"""
Zuralog Cloud Brain — PgVector Memory Store.

Production vector-backed memory store using pgvector (Supabase) for
similarity search and Jina AI jina-embeddings-v3 for embeddings.

All DB calls use asyncpg via SQLAlchemy async sessions.
Embedding calls use httpx (already a project dependency) against the
Jina AI embeddings API — no OpenAI dependency.

Implements the full MemoryStore protocol plus list_memories, delete_memory,
and clear_memories for compatibility with memory_routes.py.
"""

from __future__ import annotations

import logging
import uuid

import httpx
from sqlalchemy import text

from app.agent.context_manager.memory_store import MemoryItem
from app.database import async_session

logger = logging.getLogger(__name__)

_JINA_EMBEDDINGS_URL = "https://api.jina.ai/v1/embeddings"
_EMBEDDING_MODEL = "jina-embeddings-v3"
_EMBEDDING_DIMENSIONS = 1536  # matches the vector(1536) column in user_memories


def _vec_str(embedding: list[float]) -> str:
    """Serialize a float list to pgvector literal format: '[v1,v2,...]'."""
    return "[" + ",".join(f"{v:.8f}" for v in embedding) + "]"


class PgVectorMemoryStore:
    """Vector-backed memory store using pgvector and Jina AI embeddings.

    Each user's memories are isolated by WHERE user_id = :user_id on every
    query. RLS provides a second layer of isolation at the DB level.

    Attributes:
        is_available: True when JINA_API_KEY is configured.
    """

    def __init__(self) -> None:
        from app.config import settings

        self._api_key = settings.jina_api_key.get_secret_value()
        if self._api_key:
            logger.info("PgVectorMemoryStore initialised with Jina AI embeddings.")
        else:
            logger.info("PgVectorMemoryStore: JINA_API_KEY not set — embedding calls will fail.")

    @property
    def is_available(self) -> bool:
        """True when the Jina API key is configured."""
        return bool(self._api_key)

    async def _embed(self, text_to_embed: str, task: str = "retrieval.passage") -> list[float] | None:
        """Embed text using the Jina AI embeddings API.

        Args:
            text_to_embed: The text to embed.
            task: Jina task type — 'retrieval.passage' for storing,
                  'retrieval.query' for searching.

        Returns:
            A list of floats, or None on failure.
        """
        if not self._api_key:
            logger.warning("Embedding skipped — JINA_API_KEY not set.")
            return None
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.post(
                    _JINA_EMBEDDINGS_URL,
                    headers={
                        "Authorization": f"Bearer {self._api_key}",
                        "Content-Type": "application/json",
                    },
                    json={
                        "model": _EMBEDDING_MODEL,
                        "input": [text_to_embed],
                        "dimensions": _EMBEDDING_DIMENSIONS,
                        "task": task,
                    },
                )
                resp.raise_for_status()
                return resp.json()["data"][0]["embedding"]
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
        embedding = await self._embed(content, task="retrieval.passage")
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
        embedding = await self._embed(query_text, task="retrieval.query")
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
        """Hard-delete a memory by ID (no user scope — internal use only)."""
        async with async_session() as db:
            await db.execute(
                text("DELETE FROM user_memories WHERE id = :id"),
                {"id": memory_id},
            )
            await db.commit()

    # ------------------------------------------------------------------
    # Extended interface (for memory_routes.py)
    # ------------------------------------------------------------------

    async def delete_memory(self, memory_id: str, user_id: str) -> bool:
        """Delete a memory by ID, scoped to the owning user. Returns True when acknowledged."""
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
