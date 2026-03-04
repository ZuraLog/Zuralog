"""
Zuralog Cloud Brain — Pinecone Memory Store.

Production implementation of the ``MemoryStore`` protocol backed by
Pinecone vector storage and OpenAI text embeddings.  Each user's
memories are isolated in a dedicated Pinecone namespace keyed by their
Supabase user ID, preventing cross-user data leakage.

Architecture:
    - Embeddings: OpenAI ``text-embedding-3-small`` (1 536 dims, fast, cheap).
    - Storage: Pinecone serverless index ``zuralog-memories`` (default).
    - Namespace isolation: per Supabase user_id.
    - Graceful fallback: disabled when ``api_key`` is empty/None — logs a
      warning and returns safe empty responses instead of raising.

Usage::

    store = PineconeMemoryStore(api_key=settings.pinecone_api_key)
    memory_id = await store.save_memory(user_id, "User's knee injury note")
    results = await store.query_memory(user_id, "knee pain history", top_k=3)
"""

from __future__ import annotations

import hashlib
import logging
import re
import uuid
from dataclasses import dataclass
from typing import Any

import sentry_sdk

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Health-keyword heuristics for metadata extraction
# ---------------------------------------------------------------------------

_HEALTH_KEYWORDS: frozenset[str] = frozenset(
    {
        "steps",
        "calories",
        "sleep",
        "heart",
        "hrv",
        "vo2",
        "weight",
        "run",
        "running",
        "cycle",
        "cycling",
        "workout",
        "exercise",
        "injury",
        "pain",
        "knee",
        "back",
        "shoulder",
        "nutrition",
        "protein",
        "carbs",
        "fat",
        "water",
        "hydration",
        "goal",
        "target",
        "glucose",
        "blood",
        "pressure",
        "oxygen",
        "resting",
        "recovery",
        "stress",
        "fatigue",
        "energy",
        "mood",
        "meditation",
        "breathing",
        "respiratory",
        "body",
        "fat",
        "bmi",
    }
)

_NUMBER_PATTERN: re.Pattern[str] = re.compile(r"\b\d+(?:\.\d+)?\b")


def _extract_health_tags(text: str) -> list[str]:
    """Extract health-domain keyword tags from free text.

    Uses a simple heuristic: any token in the text that appears in
    ``_HEALTH_KEYWORDS`` is included as a tag.  Numbers are extracted
    separately to help with value-based filtering.

    Args:
        text: Raw memory text (e.g. "User runs 5km every morning").

    Returns:
        Deduplicated, lowercase list of matched health keywords.
    """
    tokens = re.findall(r"\b\w+\b", text.lower())
    tags = sorted({t for t in tokens if t in _HEALTH_KEYWORDS})
    return tags


def _extract_numbers(text: str) -> list[float]:
    """Extract numeric values mentioned in text.

    Args:
        text: Raw memory text.

    Returns:
        List of float values found in the text, up to 10.
    """
    return [float(m) for m in _NUMBER_PATTERN.findall(text)][:10]


# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------


@dataclass
class MemoryEntry:
    """A single memory record retrieved from the vector store.

    Attributes:
        id: Unique memory identifier (UUID string).
        text: The original text content stored in this memory.
        metadata: Arbitrary key-value pairs attached at save time.
        score: Cosine similarity score when returned from a query (None
            when fetched via ``list_memories``).
    """

    id: str
    text: str
    metadata: dict[str, Any]
    score: float | None = None


# ---------------------------------------------------------------------------
# PineconeMemoryStore
# ---------------------------------------------------------------------------


class PineconeMemoryStore:
    """Pinecone-backed implementation of the MemoryStore protocol.

    Stores long-term user context as vector embeddings in Pinecone.
    Each Supabase user ID is mapped to an isolated Pinecone namespace,
    guaranteeing that memory queries never leak across users.

    When ``api_key`` is empty or None the store operates in a
    *disabled* mode: all write operations return a dummy ID and all
    read operations return empty results.  This prevents startup
    failures in development environments without Pinecone credentials.

    Attributes:
        _enabled: Whether the Pinecone client is active.
        _index_name: Name of the Pinecone index.
        _embed_model: OpenAI model identifier used for embedding.
        _pc: Pinecone client instance (None when disabled).
        _index: Pinecone index handle (None when disabled).
        _openai: AsyncOpenAI client instance (None when disabled).
    """

    def __init__(
        self,
        api_key: str,
        index_name: str = "zuralog-memories",
        embed_model: str = "text-embedding-3-small",
        openai_api_key: str = "",
    ) -> None:
        """Create a PineconeMemoryStore.

        Attempts to initialise the Pinecone client and the AsyncOpenAI
        client.  If ``api_key`` is falsy the store is disabled and all
        methods become safe no-ops.

        Args:
            api_key: Pinecone API key. If empty/None, disables the store.
            index_name: Name of the Pinecone index to use.
            embed_model: OpenAI embedding model identifier.
            openai_api_key: OpenAI API key for embedding calls. Falls back
                to ``settings.openai_api_key`` when empty.
        """
        self._index_name = index_name
        self._embed_model = embed_model
        self._pc: Any = None
        self._index: Any = None
        self._openai: Any = None

        if not api_key:
            logger.warning(
                "PineconeMemoryStore: PINECONE_API_KEY is not configured — "
                "memory store is disabled. Calls will return safe empty results."
            )
            self._enabled = False
            return

        try:
            from pinecone import Pinecone  # type: ignore[import]

            self._pc = Pinecone(api_key=api_key)
            self._index = self._pc.Index(index_name)
            logger.info("PineconeMemoryStore: connected to index '%s'", index_name)
        except Exception:
            logger.exception("PineconeMemoryStore: failed to initialise Pinecone client — memory store disabled")
            self._enabled = False
            return

        # Resolve OpenAI API key
        _openai_key = openai_api_key
        if not _openai_key:
            try:
                from app.config import settings as _settings  # avoid circular at module level

                _openai_key = _settings.openai_api_key
            except Exception:
                pass

        if not _openai_key:
            logger.warning(
                "PineconeMemoryStore: OPENAI_API_KEY is not configured — embedding calls will fail at runtime"
            )

        try:
            from openai import AsyncOpenAI  # type: ignore[import]

            self._openai = AsyncOpenAI(api_key=_openai_key or "placeholder")
        except Exception:
            logger.exception("PineconeMemoryStore: failed to initialise OpenAI client")
            self._enabled = False
            return

        self._enabled = True

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    async def _embed(self, text: str) -> list[float]:
        """Generate a text embedding via the OpenAI Embeddings API.

        Args:
            text: The text to embed. Truncated to 8 000 characters to
                respect API limits.

        Returns:
            A list of floats representing the embedding vector.

        Raises:
            RuntimeError: If the OpenAI client is not initialised.
        """
        if self._openai is None:
            raise RuntimeError("OpenAI client is not initialised")

        truncated = text[:8000]
        response = await self._openai.embeddings.create(
            input=truncated,
            model=self._embed_model,
        )
        return response.data[0].embedding

    @staticmethod
    def _namespace(user_id: str) -> str:
        """Convert a Supabase user ID into a Pinecone namespace.

        Namespaces keep each user's vectors strictly isolated within the
        same Pinecone index.

        Args:
            user_id: The raw Supabase user UUID string.

        Returns:
            The namespace string (identity mapping — user IDs are valid
            namespace names in Pinecone).
        """
        return user_id

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    async def save_memory(
        self,
        user_id: str,
        text: str,
        metadata: dict[str, Any] | None = None,
    ) -> str:
        """Embed text and upsert it into the user's namespace.

        Automatically enriches ``metadata`` with health-domain tags and
        extracted numeric values using lightweight heuristics.

        Args:
            user_id: The user whose memory namespace to write to.
            text: The memory content to store.
            metadata: Optional caller-supplied key-value metadata.

        Returns:
            The ``memory_id`` (UUID string) assigned to this record.
            When the store is disabled, returns a deterministic dummy ID
            derived from the text hash.
        """
        if not self._enabled:
            # Return a stable dummy ID so callers don't crash
            dummy_id = hashlib.sha256(text.encode()).hexdigest()[:36]
            logger.debug("PineconeMemoryStore disabled — returning dummy id %s", dummy_id)
            return dummy_id

        memory_id = str(uuid.uuid4())
        enriched_meta: dict[str, Any] = {
            "user_id": user_id,
            "text": text,
            "health_tags": _extract_health_tags(text),
            "numbers": _extract_numbers(text),
        }
        if metadata:
            enriched_meta.update(metadata)

        try:
            vector = await self._embed(text)
            self._index.upsert(
                vectors=[
                    {
                        "id": memory_id,
                        "values": vector,
                        "metadata": enriched_meta,
                    }
                ],
                namespace=self._namespace(user_id),
            )
            logger.debug(
                "PineconeMemoryStore: saved memory '%s' for user '%s'",
                memory_id,
                user_id,
            )
        except Exception:
            logger.exception("PineconeMemoryStore: failed to save memory for user '%s'", user_id)
            with sentry_sdk.push_scope() as scope:
                scope.set_tag("ai.error_type", "memory_store_error")
                scope.set_tag("memory.operation", "save")
                scope.fingerprint = ["memory_store_failure", "{{ default }}"]
                sentry_sdk.capture_exception()
            raise

        return memory_id

    async def query_memory(
        self,
        user_id: str,
        query: str,
        top_k: int = 5,
    ) -> list[MemoryEntry]:
        """Perform semantic similarity search in the user's namespace.

        Embeds the query text and retrieves the ``top_k`` most similar
        memories from the user's Pinecone namespace.

        Args:
            user_id: The user whose namespace to search.
            query: The natural-language query string.
            top_k: Maximum number of results to return (default 5).

        Returns:
            A list of :class:`MemoryEntry` objects ordered by similarity
            (highest score first).  Returns an empty list when the store
            is disabled or no results are found.
        """
        if not self._enabled:
            logger.debug("PineconeMemoryStore disabled — returning empty query results")
            return []

        try:
            query_vector = await self._embed(query)
            response = self._index.query(
                vector=query_vector,
                top_k=top_k,
                include_metadata=True,
                namespace=self._namespace(user_id),
            )
            entries: list[MemoryEntry] = []
            for match in response.get("matches", []):
                meta = match.get("metadata", {})
                entries.append(
                    MemoryEntry(
                        id=match["id"],
                        text=meta.get("text", ""),
                        metadata={k: v for k, v in meta.items() if k != "text"},
                        score=match.get("score"),
                    )
                )
            return entries
        except Exception:
            logger.exception("PineconeMemoryStore: failed to query memory for user '%s'", user_id)
            with sentry_sdk.push_scope() as scope:
                scope.set_tag("ai.error_type", "memory_store_error")
                scope.set_tag("memory.operation", "query")
                scope.fingerprint = ["memory_store_failure", "{{ default }}"]
                sentry_sdk.capture_exception()
            return []

    async def list_memories(self, user_id: str) -> list[MemoryEntry]:
        """Fetch all stored memories for a user.

        Uses a zero-vector query to retrieve all records in the user's
        namespace without semantic ranking.  Results are not ordered by
        relevance.

        Note:
            This method does *not* perform real similarity search — it
            uses a zero vector as a dummy to fetch via Pinecone's query
            API.  For large namespaces consider pagination.

        Args:
            user_id: The user whose namespace to enumerate.

        Returns:
            A list of :class:`MemoryEntry` objects (``score`` is None).
            Returns an empty list when the store is disabled.
        """
        if not self._enabled:
            return []

        try:
            # Use a zero vector as a dummy to trigger a full namespace scan
            # Pinecone serverless supports this for listing purposes.
            # We request a large top_k to approximate "all" records.
            dimension = 1536  # text-embedding-3-small output dimension
            dummy_vector = [0.0] * dimension
            response = self._index.query(
                vector=dummy_vector,
                top_k=1000,
                include_metadata=True,
                namespace=self._namespace(user_id),
            )
            entries: list[MemoryEntry] = []
            for match in response.get("matches", []):
                meta = match.get("metadata", {})
                entries.append(
                    MemoryEntry(
                        id=match["id"],
                        text=meta.get("text", ""),
                        metadata={k: v for k, v in meta.items() if k != "text"},
                        score=None,
                    )
                )
            return entries
        except Exception:
            logger.exception("PineconeMemoryStore: failed to list memories for user '%s'", user_id)
            return []

    async def delete_memory(self, user_id: str, memory_id: str) -> bool:
        """Delete a single memory by ID from the user's namespace.

        Args:
            user_id: The user whose namespace to write to.
            memory_id: The UUID string of the memory to delete.

        Returns:
            ``True`` if the deletion was issued successfully, ``False``
            if the store is disabled or the operation failed.
        """
        if not self._enabled:
            return False

        try:
            self._index.delete(
                ids=[memory_id],
                namespace=self._namespace(user_id),
            )
            logger.debug(
                "PineconeMemoryStore: deleted memory '%s' for user '%s'",
                memory_id,
                user_id,
            )
            return True
        except Exception:
            logger.exception(
                "PineconeMemoryStore: failed to delete memory '%s' for user '%s'",
                memory_id,
                user_id,
            )
            return False

    async def clear_memories(self, user_id: str) -> int:
        """Delete all memories stored for a user.

        Calls ``delete_all`` on the user's Pinecone namespace, which
        removes every vector in that namespace atomically.

        Args:
            user_id: The user whose namespace to clear.

        Returns:
            The number of memories that were deleted, or 0 if the store
            is disabled or the namespace was already empty.  Because
            Pinecone's delete-namespace API does not return a count,
            this method first fetches the current count via
            ``list_memories`` before deleting.
        """
        if not self._enabled:
            return 0

        try:
            # Count existing records before deletion
            existing = await self.list_memories(user_id)
            count = len(existing)

            self._index.delete(
                delete_all=True,
                namespace=self._namespace(user_id),
            )
            logger.info(
                "PineconeMemoryStore: cleared %d memories for user '%s'",
                count,
                user_id,
            )
            return count
        except Exception:
            logger.exception("PineconeMemoryStore: failed to clear memories for user '%s'", user_id)
            return 0

    # ------------------------------------------------------------------
    # MemoryStore protocol compatibility shim
    # ------------------------------------------------------------------

    async def add(
        self,
        user_id: str,
        text: str,
        metadata: dict[str, Any] | None = None,
    ) -> None:
        """Alias for ``save_memory`` to satisfy the MemoryStore protocol.

        The protocol requires ``add()`` but callers within the Orchestrator
        use this method.  Internally delegates to ``save_memory``.

        Args:
            user_id: The user to store context for.
            text: The memory content.
            metadata: Optional key-value metadata.
        """
        await self.save_memory(user_id, text, metadata)

    async def query(
        self,
        user_id: str,
        query_text: str = "",
        limit: int = 5,
    ) -> list[dict[str, Any]]:
        """Alias for ``query_memory`` to satisfy the MemoryStore protocol.

        Converts :class:`MemoryEntry` results to plain dicts matching the
        protocol's return type (``list[dict[str, Any]]``).

        Args:
            user_id: The user to retrieve context for.
            query_text: Semantic search query.
            limit: Maximum number of results.

        Returns:
            A list of dicts with at least ``text`` and ``metadata`` keys.
        """
        entries = await self.query_memory(user_id, query_text, top_k=limit)
        return [{"text": e.text, "metadata": e.metadata, "score": e.score} for e in entries]
