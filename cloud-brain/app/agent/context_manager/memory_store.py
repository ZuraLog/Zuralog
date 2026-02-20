"""
Life Logger Cloud Brain — Memory Store Abstraction.

Defines the ``MemoryStore`` protocol (abstract interface) for long-term
user context storage, and an ``InMemoryStore`` implementation for
development and testing.

The production Pinecone adapter will be added in Phase 1.8 (AI Brain)
when we have real embeddings to store. This avoids a premature
dependency on the Pinecone SDK.
"""

from __future__ import annotations

import logging
from typing import Any, Protocol, runtime_checkable

logger = logging.getLogger(__name__)


@runtime_checkable
class MemoryStore(Protocol):
    """Abstract interface for long-term user memory storage.

    Any concrete implementation (in-memory, Pinecone, pgvector, etc.)
    must satisfy this protocol to be usable by the Orchestrator.
    """

    async def add(
        self,
        user_id: str,
        text: str,
        metadata: dict[str, Any] | None = None,
    ) -> None:
        """Store a memory entry for a user.

        Args:
            user_id: The user whose context this belongs to.
            text: The content to remember (e.g. "User hurt their knee").
            metadata: Optional key-value pairs for filtering/retrieval.
        """
        ...

    async def query(
        self,
        user_id: str,
        query_text: str = "",
        limit: int = 5,
    ) -> list[dict[str, Any]]:
        """Retrieve relevant context for a user.

        In production, this performs semantic similarity search.
        The in-memory stub returns the most recent entries.

        Args:
            user_id: The user to retrieve context for.
            query_text: Search query (used for semantic matching).
            limit: Maximum number of results to return.

        Returns:
            A list of memory entries as dicts with at least ``text``
            and ``metadata`` keys.
        """
        ...


class InMemoryStore:
    """Dict-backed memory store for development and testing.

    Stores memories in a plain dictionary keyed by ``user_id``.
    Returns the most recent entries on query (no semantic matching).
    Data is lost when the process restarts — this is intentional
    for a dev stub.

    Attributes:
        _store: Internal mapping of user_id → list of memory entries.
    """

    def __init__(self) -> None:
        """Initialise an empty store."""
        self._store: dict[str, list[dict[str, Any]]] = {}

    async def add(
        self,
        user_id: str,
        text: str,
        metadata: dict[str, Any] | None = None,
    ) -> None:
        """Store a memory entry for a user.

        Args:
            user_id: The user whose context this belongs to.
            text: The content to remember.
            metadata: Optional key-value pairs.
        """
        entry = {"text": text, "metadata": metadata or {}}
        self._store.setdefault(user_id, []).append(entry)
        logger.debug("Stored memory for user '%s': %s", user_id, text[:50])

    async def query(
        self,
        user_id: str,
        query_text: str = "",
        limit: int = 5,
    ) -> list[dict[str, Any]]:
        """Return the most recent memories for a user.

        Args:
            user_id: The user to retrieve context for.
            query_text: Ignored in this stub (no semantic search).
            limit: Maximum number of results to return.

        Returns:
            A list of the most recent memory entries (newest last).
        """
        entries = self._store.get(user_id, [])
        return entries[-limit:]
