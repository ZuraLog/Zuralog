"""
Zuralog Cloud Brain — Memory Store Abstraction.

Defines the MemoryItem dataclass, the MemoryStore protocol, and an
InMemoryStore implementation for development and testing.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Protocol, runtime_checkable

logger = logging.getLogger(__name__)


@dataclass
class MemoryItem:
    """A single retrieved memory entry with its relevance score.

    Attributes:
        id: Stable identifier for tracing and management.
        content: The remembered fact (e.g. "User has a knee injury").
        category: Semantic category — goal | injury | pr | preference | context | program.
        score: Cosine similarity (0.0–1.0). Higher = more relevant.
            Defaults to 1.0 for stores without similarity scoring.
    """

    id: str
    content: str
    category: str
    score: float = 1.0


@runtime_checkable
class MemoryStore(Protocol):
    """Abstract interface for long-term user memory storage."""

    async def add(
        self,
        user_id: str,
        content: str,
        category: str,
        source_conversation_id: str | None = None,
    ) -> None:
        """Store a memory entry for a user."""
        ...

    async def query(
        self,
        user_id: str,
        query_text: str = "",
        limit: int = 5,
    ) -> list[MemoryItem]:
        """Retrieve relevant memories for a user.

        Args:
            user_id: The user to retrieve context for.
            query_text: Search query (used for semantic matching in production).
            limit: Maximum number of results to return.

        Returns:
            A list of MemoryItem objects ordered by relevance (most relevant last
            for InMemoryStore; most relevant first for vector stores).
        """
        ...

    async def delete(self, memory_id: str) -> None:
        """Hard-delete a memory by ID."""
        ...


class InMemoryStore:
    """Dict-backed memory store for development and testing.

    Returns the most recent entries on query (no semantic matching).
    Data is lost when the process restarts — intentional for a dev stub.
    """

    def __init__(self) -> None:
        self._store: dict[str, list[MemoryItem]] = {}
        self._id_counter = 0

    async def add(
        self,
        user_id: str,
        content: str,
        category: str,
        source_conversation_id: str | None = None,
    ) -> None:
        self._id_counter += 1
        item = MemoryItem(
            id=str(self._id_counter),
            content=content,
            category=category,
            score=1.0,
        )
        self._store.setdefault(user_id, []).append(item)
        logger.debug("Stored memory for user '%s': %s", user_id, content[:50])

    async def query(
        self,
        user_id: str,
        query_text: str = "",
        limit: int = 5,
    ) -> list[MemoryItem]:
        entries = self._store.get(user_id, [])
        return entries[-limit:]

    async def delete(self, memory_id: str) -> None:
        for uid in list(self._store.keys()):
            self._store[uid] = [i for i in self._store[uid] if i.id != memory_id]
