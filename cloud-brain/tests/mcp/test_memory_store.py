"""
Zuralog Cloud Brain — InMemoryStore Tests.

Verifies that the in-memory MemoryStore stub correctly stores and
retrieves user context entries with proper isolation between users.
"""

import pytest

from app.agent.context_manager.memory_store import InMemoryStore, MemoryStore


class TestInMemoryStore:
    """Tests for the InMemoryStore development stub."""

    def test_implements_memory_store_protocol(self) -> None:
        """InMemoryStore satisfies the MemoryStore protocol."""
        store = InMemoryStore()
        assert isinstance(store, MemoryStore)

    @pytest.mark.asyncio
    async def test_add_and_query(self) -> None:
        """Stored entries are returned by query."""
        store = InMemoryStore()
        await store.add("user_1", "I hurt my knee yesterday")
        await store.add("user_1", "I prefer low-impact cardio")

        results = await store.query("user_1")
        assert len(results) == 2
        assert results[0]["text"] == "I hurt my knee yesterday"
        assert results[1]["text"] == "I prefer low-impact cardio"

    @pytest.mark.asyncio
    async def test_query_limit(self) -> None:
        """Query respects the limit parameter."""
        store = InMemoryStore()
        for i in range(10):
            await store.add("user_1", f"Memory {i}")

        results = await store.query("user_1", limit=3)
        assert len(results) == 3
        # Returns most recent entries
        assert results[0]["text"] == "Memory 7"
        assert results[2]["text"] == "Memory 9"

    @pytest.mark.asyncio
    async def test_user_isolation(self) -> None:
        """Memories from user A do not leak to user B."""
        store = InMemoryStore()
        await store.add("user_a", "User A memory")
        await store.add("user_b", "User B memory")

        results_a = await store.query("user_a")
        results_b = await store.query("user_b")

        assert len(results_a) == 1
        assert results_a[0]["text"] == "User A memory"
        assert len(results_b) == 1
        assert results_b[0]["text"] == "User B memory"

    @pytest.mark.asyncio
    async def test_query_unknown_user_returns_empty(self) -> None:
        """Querying an unknown user returns an empty list."""
        store = InMemoryStore()
        results = await store.query("nonexistent")
        assert results == []

    @pytest.mark.asyncio
    async def test_metadata_is_stored(self) -> None:
        """Metadata dict is preserved with the entry."""
        store = InMemoryStore()
        await store.add("user_1", "Ran 5k", metadata={"type": "workout", "distance": 5000})

        results = await store.query("user_1")
        assert results[0]["metadata"]["type"] == "workout"
        assert results[0]["metadata"]["distance"] == 5000

    @pytest.mark.asyncio
    async def test_metadata_defaults_to_empty_dict(self) -> None:
        """Passing no metadata stores an empty dict."""
        store = InMemoryStore()
        await store.add("user_1", "Simple memory")

        results = await store.query("user_1")
        assert results[0]["metadata"] == {}
