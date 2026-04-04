"""Tests for MemoryItem dataclass and InMemoryStore."""

from __future__ import annotations

import pytest

from app.agent.context_manager.memory_store import InMemoryStore, MemoryItem


class TestMemoryItem:
    def test_fields_exist(self) -> None:
        item = MemoryItem(id="1", content="user has a knee injury", category="injury")
        assert item.id == "1"
        assert item.content == "user has a knee injury"
        assert item.category == "injury"
        assert item.score == 1.0  # default

    def test_custom_score(self) -> None:
        item = MemoryItem(id="2", content="goal: marathon", category="goal", score=0.85)
        assert item.score == 0.85


class TestInMemoryStore:
    @pytest.mark.asyncio
    async def test_add_and_query_returns_memory_items(self) -> None:
        store = InMemoryStore()
        await store.add("user1", "runs 5k twice a week", "preference")
        results = await store.query("user1", "running habits")
        assert len(results) == 1
        assert isinstance(results[0], MemoryItem)
        assert results[0].content == "runs 5k twice a week"
        assert results[0].category == "preference"

    @pytest.mark.asyncio
    async def test_query_respects_limit(self) -> None:
        store = InMemoryStore()
        for i in range(10):
            await store.add("user1", f"memory {i}", "context")
        results = await store.query("user1", limit=3)
        assert len(results) == 3

    @pytest.mark.asyncio
    async def test_query_empty_store_returns_empty_list(self) -> None:
        store = InMemoryStore()
        results = await store.query("nobody", "anything")
        assert results == []

    @pytest.mark.asyncio
    async def test_delete_removes_item(self) -> None:
        store = InMemoryStore()
        await store.add("user1", "fact to delete", "context")
        items = await store.query("user1")
        memory_id = items[0].id
        await store.delete(memory_id, user_id="user1")
        after = await store.query("user1")
        assert len(after) == 0

    @pytest.mark.asyncio
    async def test_user_isolation(self) -> None:
        store = InMemoryStore()
        await store.add("user1", "user1 fact", "context")
        await store.add("user2", "user2 fact", "context")
        user1_results = await store.query("user1")
        assert all("user1" in r.content for r in user1_results)
        user2_results = await store.query("user2")
        assert all("user2" in r.content for r in user2_results)
