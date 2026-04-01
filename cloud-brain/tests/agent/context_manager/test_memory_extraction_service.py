"""Tests for the memory extraction service."""

from __future__ import annotations

import json
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.agent.context_manager.memory_extraction_service import extract_and_store_memories
from app.agent.context_manager.memory_store import InMemoryStore, MemoryItem


def _mock_llm_response(facts: list[dict]) -> MagicMock:
    response = MagicMock()
    response.choices[0].message.content = json.dumps(facts)
    return response


class TestExtractAndStoreMemories:
    @pytest.mark.asyncio
    async def test_extracts_and_stores_new_facts(self) -> None:
        mock_llm = AsyncMock()
        mock_llm.chat.return_value = _mock_llm_response([
            {"content": "User runs 5K twice a week", "category": "preference"},
            {"content": "User's goal is to lose 10kg", "category": "goal"},
        ])
        store = InMemoryStore()

        with patch(
            "app.agent.context_manager.memory_extraction_service.async_session"
        ) as mock_session_factory:
            mock_db = AsyncMock()
            mock_session_factory.return_value.__aenter__.return_value = mock_db
            mock_result = MagicMock()
            mock_result.scalars.return_value.all.return_value = [
                MagicMock(role="user", content="I run 5K twice a week"),
                MagicMock(role="assistant", content="Great habit. What's your goal?"),
                MagicMock(role="user", content="I want to lose 10kg"),
            ]
            mock_db.execute.return_value = mock_result

            await extract_and_store_memories("conv-1", "user-1", mock_llm, store)

        items = await store.query("user-1")
        assert len(items) == 2
        contents = {i.content for i in items}
        assert "User runs 5K twice a week" in contents
        assert "User's goal is to lose 10kg" in contents

    @pytest.mark.asyncio
    async def test_deduplicates_near_duplicate_facts(self) -> None:
        """A fact with score > 0.92 against an existing memory updates rather than duplicates."""
        mock_llm = AsyncMock()
        mock_llm.chat.return_value = _mock_llm_response([
            {"content": "User wants to run a marathon", "category": "goal"},
        ])

        # Pre-populate store with a near-duplicate
        store = InMemoryStore()
        await store.add("user-1", "User wants to complete a marathon", "goal")
        existing = await store.query("user-1")
        assert len(existing) == 1

        # Patch InMemoryStore.query to return high score for the near-duplicate
        original_query = store.query

        async def mock_query(user_id, query_text="", limit=5):
            if query_text:
                # Simulate high similarity for the near-duplicate
                return [MemoryItem(id=existing[0].id, content=existing[0].content, category="goal", score=0.95)]
            return await original_query(user_id, query_text, limit)

        store.query = mock_query

        with patch(
            "app.agent.context_manager.memory_extraction_service.async_session"
        ) as mock_session_factory:
            mock_db = AsyncMock()
            mock_session_factory.return_value.__aenter__.return_value = mock_db
            mock_result = MagicMock()
            mock_result.scalars.return_value.all.return_value = [
                MagicMock(role="user", content="I want to run a marathon"),
            ]
            mock_db.execute.return_value = mock_result

            await extract_and_store_memories("conv-1", "user-1", mock_llm, store)

        # The old item was deleted and new one added — still only 1 item
        # (InMemoryStore.query is patched so we check via original)
        store.query = original_query
        items = await store.query("user-1")
        assert len(items) == 1
        assert items[0].content == "User wants to run a marathon"

    @pytest.mark.asyncio
    async def test_handles_malformed_llm_response_gracefully(self) -> None:
        mock_llm = AsyncMock()
        mock_llm.chat.return_value = _mock_llm_response([])
        # Override with broken JSON
        mock_llm.chat.return_value.choices[0].message.content = "not valid json"

        store = InMemoryStore()

        with patch(
            "app.agent.context_manager.memory_extraction_service.async_session"
        ) as mock_session_factory:
            mock_db = AsyncMock()
            mock_session_factory.return_value.__aenter__.return_value = mock_db
            mock_result = MagicMock()
            mock_result.scalars.return_value.all.return_value = [
                MagicMock(role="user", content="Hello")
            ]
            mock_db.execute.return_value = mock_result

            # Should not raise
            await extract_and_store_memories("conv-1", "user-1", mock_llm, store)

        items = await store.query("user-1")
        assert len(items) == 0
