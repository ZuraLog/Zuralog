"""
Zuralog Cloud Brain — Pinecone Memory Store.

Production vector-backed memory store using Pinecone for similarity search
and OpenAI embeddings for text-to-vector conversion.

Implements the same interface as ``InMemoryStore`` so it can be swapped in
as a drop-in replacement via ``app.state.memory_store`` at startup.

Each user's memories are isolated in a Pinecone namespace equal to their
``user_id``, giving row-level tenant isolation without separate indexes.

Graceful degradation: if Pinecone or OpenAI are unavailable (missing API keys
or import errors), all methods log a warning and return safe empty results
rather than raising exceptions. The ``is_available`` property can be checked
at startup to decide which implementation to use.
"""

from __future__ import annotations

import asyncio
import logging
import os
import uuid
from datetime import datetime, timezone
from typing import Any

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Optional dependency imports — graceful fallback when not installed
# ---------------------------------------------------------------------------

try:
    from pinecone import Pinecone as PineconeClient  # type: ignore

    _pinecone_available = True
except ImportError:
    _pinecone_available = False
    logger.warning(
        "pinecone package not installed. PineconeMemoryStore will be unavailable. "
        "Install with: pip install pinecone"
    )

try:
    from openai import OpenAI as OpenAIClient  # type: ignore

    _openai_available = True
except ImportError:
    _openai_available = False
    logger.warning(
        "openai package not installed. PineconeMemoryStore will be unavailable. "
        "Install with: pip install openai"
    )

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

_EMBEDDING_MODEL = "text-embedding-3-small"
_EMBEDDING_DIMENSIONS = 1536
_SCORE_THRESHOLD = 0.7


class PineconeMemoryStore:
    """Vector-backed memory store using Pinecone and OpenAI embeddings.

    Provides semantic similarity search for user memories. Each user's
    vectors are stored in a dedicated Pinecone namespace (``user_id``),
    providing tenant isolation within a single shared index.

    When ``PINECONE_API_KEY`` or ``OPENAI_API_KEY`` are not set, or when the
    required packages are not installed, the store degrades gracefully — all
    write operations become no-ops and read operations return empty lists.

    Attributes:
        is_available: True when Pinecone and OpenAI are fully configured.
    """

    def __init__(self) -> None:
        """Initialise the store and attempt to connect to Pinecone/OpenAI."""
        self._pinecone_api_key = os.getenv("PINECONE_API_KEY", "")
        self._pinecone_index_name = os.getenv("PINECONE_INDEX_NAME", "zuralog-memories")
        self._openai_api_key = os.getenv("OPENAI_API_KEY", "")

        self._pc: Any = None  # Pinecone client
        self._index: Any = None  # Pinecone Index
        self._openai: Any = None  # OpenAI client

        configured = bool(self._pinecone_api_key and self._openai_api_key)
        packages_ok = _pinecone_available and _openai_available

        if configured and packages_ok:
            try:
                self._pc = PineconeClient(api_key=self._pinecone_api_key)
                self._index = self._pc.Index(self._pinecone_index_name)
                self._openai = OpenAIClient(api_key=self._openai_api_key)
                logger.info(
                    "PineconeMemoryStore initialised. Index: '%s'",
                    self._pinecone_index_name,
                )
            except Exception:
                logger.warning(
                    "PineconeMemoryStore failed to initialise.",
                    exc_info=True,
                )
                self._pc = None
                self._index = None
                self._openai = None
        else:
            if not configured:
                logger.info(
                    "PineconeMemoryStore: PINECONE_API_KEY or OPENAI_API_KEY not set. "
                    "Falling back to no-op mode."
                )

    @property
    def is_available(self) -> bool:
        """True when Pinecone and OpenAI are fully configured and connected."""
        return self._index is not None and self._openai is not None

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    def _embed_sync(self, text: str) -> list[float]:
        """Embed text to a vector using OpenAI (synchronous call).

        Args:
            text: The text to embed.

        Returns:
            A list of floats representing the embedding vector.

        Raises:
            RuntimeError: If the OpenAI client is not initialised.
        """
        if self._openai is None:
            raise RuntimeError("OpenAI client not initialised.")
        response = self._openai.embeddings.create(
            model=_EMBEDDING_MODEL,
            input=text,
        )
        return response.data[0].embedding

    async def _embed(self, text: str) -> list[float]:
        """Async wrapper around the synchronous OpenAI embedding call.

        Uses ``asyncio.to_thread`` to avoid blocking the event loop.

        Args:
            text: The text to embed.

        Returns:
            A list of floats representing the embedding vector.
        """
        return await asyncio.to_thread(self._embed_sync, text)

    # ------------------------------------------------------------------
    # Core interface (matches InMemoryStore / MemoryStore protocol)
    # ------------------------------------------------------------------

    async def add(
        self,
        user_id: str,
        text: str,
        metadata: dict[str, Any] | None = None,
    ) -> None:
        """Store a memory entry for a user (MemoryStore protocol alias).

        Delegates to ``save_memory``. Provided for compatibility with the
        ``MemoryStore`` protocol used by the Orchestrator.

        Args:
            user_id: The user whose context this belongs to.
            text: The content to remember.
            metadata: Optional key-value pairs for filtering/retrieval.
        """
        await self.save_memory(user_id, text, metadata)

    async def query(
        self,
        user_id: str,
        query_text: str = "",
        limit: int = 5,
    ) -> list[dict[str, Any]]:
        """Retrieve relevant memories (MemoryStore protocol alias).

        Delegates to ``query_memory``. Provided for compatibility with the
        ``MemoryStore`` protocol used by the Orchestrator.

        Args:
            user_id: The user to retrieve context for.
            query_text: Search query (used for semantic matching).
            limit: Maximum number of results to return.

        Returns:
            A list of memory entries as dicts with at least ``text``
            and ``metadata`` keys.
        """
        return await self.query_memory(user_id, query_text, limit)

    # ------------------------------------------------------------------
    # Extended interface
    # ------------------------------------------------------------------

    async def save_memory(
        self,
        user_id: str,
        text: str,
        metadata: dict[str, Any] | None = None,
    ) -> str | None:
        """Embed text and upsert it as a vector in the user's namespace.

        The metadata stored alongside the vector always includes ``text``,
        ``user_id``, and ``created_at`` in addition to any caller-supplied
        extra fields.

        Args:
            user_id: The user whose namespace to write to.
            text: The natural-language memory to store.
            metadata: Optional extra key-value pairs to attach to the vector.

        Returns:
            The UUID string assigned as the vector ID, or ``None`` if the
            store is unavailable.
        """
        if not self.is_available:
            logger.warning("PineconeMemoryStore.save_memory: store unavailable, skipping.")
            return None

        try:
            vector = await self._embed(text)
            memory_id = str(uuid.uuid4())
            payload_metadata: dict[str, Any] = {
                "text": text,
                "user_id": user_id,
                "created_at": datetime.now(timezone.utc).isoformat(),
                **(metadata or {}),
            }

            await asyncio.to_thread(
                self._index.upsert,
                vectors=[{"id": memory_id, "values": vector, "metadata": payload_metadata}],
                namespace=user_id,
            )
            logger.debug(
                "Saved memory for user '%s' [id=%s]: %s",
                user_id,
                memory_id,
                text[:60],
            )
            return memory_id
        except Exception:
            logger.exception("PineconeMemoryStore.save_memory failed for user '%s'.", user_id)
            return None

    async def query_memory(
        self,
        user_id: str,
        query_text: str,
        limit: int = 5,
    ) -> list[dict[str, Any]]:
        """Semantic similarity search for a user's stored memories.

        Embeds the query text, queries the user's Pinecone namespace, and
        returns results whose similarity score exceeds ``_SCORE_THRESHOLD``
        (0.7).

        Args:
            user_id: The user whose namespace to search.
            query_text: The natural-language query to match against.
            limit: Maximum number of results to return.

        Returns:
            A list of dicts with keys ``id``, ``text``, ``score``, and
            ``metadata``. Returns an empty list if the store is unavailable
            or an error occurs.
        """
        if not self.is_available:
            logger.warning("PineconeMemoryStore.query_memory: store unavailable, returning [].")
            return []

        try:
            vector = await self._embed(query_text)

            def _query() -> Any:
                return self._index.query(
                    vector=vector,
                    top_k=limit,
                    namespace=user_id,
                    include_metadata=True,
                )

            result = await asyncio.to_thread(_query)

            memories = []
            for match in result.matches:
                if match.score < _SCORE_THRESHOLD:
                    continue
                meta = match.metadata or {}
                memories.append(
                    {
                        "id": match.id,
                        "text": meta.get("text", ""),
                        "score": match.score,
                        "metadata": meta,
                    }
                )
            logger.debug(
                "query_memory for user '%s': %d/%d results above threshold",
                user_id,
                len(memories),
                len(result.matches),
            )
            return memories
        except Exception:
            logger.exception("PineconeMemoryStore.query_memory failed for user '%s'.", user_id)
            return []

    async def list_memories(self, user_id: str) -> list[dict[str, Any]]:
        """List all stored memories for a user.

        Uses a zero-vector query with a generous top_k to approximate a
        full namespace scan. This is the most portable approach across
        Pinecone plan tiers (``list`` is only available on Serverless).

        Args:
            user_id: The user whose memories to list.

        Returns:
            A list of dicts with keys ``id``, ``text``, and ``metadata``.
            Returns an empty list if the store is unavailable or an error
            occurs.
        """
        if not self.is_available:
            logger.warning("PineconeMemoryStore.list_memories: store unavailable, returning [].")
            return []

        try:
            zero_vector = [0.0] * _EMBEDDING_DIMENSIONS

            def _list() -> Any:
                return self._index.query(
                    vector=zero_vector,
                    top_k=1000,
                    namespace=user_id,
                    include_metadata=True,
                )

            result = await asyncio.to_thread(_list)

            memories = []
            for match in result.matches:
                meta = match.metadata or {}
                memories.append(
                    {
                        "id": match.id,
                        "text": meta.get("text", ""),
                        "metadata": meta,
                    }
                )
            logger.debug(
                "list_memories for user '%s': %d results", user_id, len(memories)
            )
            return memories
        except Exception:
            logger.exception("PineconeMemoryStore.list_memories failed for user '%s'.", user_id)
            return []

    async def delete_memory(self, user_id: str, memory_id: str) -> bool:
        """Delete a single memory vector by ID.

        Args:
            user_id: The user whose namespace to delete from.
            memory_id: The UUID of the vector to delete.

        Returns:
            ``True`` if the delete was issued successfully, ``False`` if the
            store is unavailable or an error occurs.
        """
        if not self.is_available:
            logger.warning("PineconeMemoryStore.delete_memory: store unavailable, skipping.")
            return False

        try:
            await asyncio.to_thread(
                self._index.delete,
                ids=[memory_id],
                namespace=user_id,
            )
            logger.debug(
                "Deleted memory id='%s' for user '%s'.", memory_id, user_id
            )
            return True
        except Exception:
            logger.exception(
                "PineconeMemoryStore.delete_memory failed for user '%s', id='%s'.",
                user_id,
                memory_id,
            )
            return False

    async def clear_memories(self, user_id: str) -> bool:
        """Delete all vectors in a user's namespace.

        Args:
            user_id: The user whose entire namespace to wipe.

        Returns:
            ``True`` if the namespace was cleared successfully, ``False`` if
            the store is unavailable or an error occurs.
        """
        if not self.is_available:
            logger.warning("PineconeMemoryStore.clear_memories: store unavailable, skipping.")
            return False

        try:
            await asyncio.to_thread(
                self._index.delete,
                delete_all=True,
                namespace=user_id,
            )
            logger.info("Cleared all memories for user '%s'.", user_id)
            return True
        except Exception:
            logger.exception(
                "PineconeMemoryStore.clear_memories failed for user '%s'.", user_id
            )
            return False

    # ------------------------------------------------------------------
    # Aliases for forward-compatibility
    # ------------------------------------------------------------------

    async def save(self, user_id: str, text: str) -> str | None:
        """Alias for ``save_memory`` to match InMemoryStore interface.

        Args:
            user_id: The user whose context this belongs to.
            text: The content to remember.

        Returns:
            The UUID assigned as the vector ID, or ``None`` on failure.
        """
        return await self.save_memory(user_id, text)
