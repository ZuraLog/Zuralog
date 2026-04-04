"""Tests for PgVectorMemoryStore — uses mocked DB and embedding calls."""

from __future__ import annotations

import uuid
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.agent.context_manager.memory_store import MemoryItem
from app.agent.context_manager.pgvector_memory_store import PgVectorMemoryStore


def _fake_embedding(text: str) -> list[float]:
    """Deterministic fake embedding for testing (not meaningful for similarity)."""
    import hashlib
    seed = int(hashlib.md5(text.encode()).hexdigest(), 16)
    rng = __import__("random").Random(seed)
    return [rng.uniform(-1, 1) for _ in range(1536)]


class TestPgVectorMemoryStore:
    @pytest.mark.asyncio
    async def test_add_embeds_and_inserts(self) -> None:
        store = PgVectorMemoryStore()

        with (
            patch.object(store, "_embed_sync", side_effect=_fake_embedding),
            patch(
                "app.agent.context_manager.pgvector_memory_store.async_session"
            ) as mock_session_factory,
        ):
            mock_db = AsyncMock()
            mock_session_factory.return_value.__aenter__.return_value = mock_db

            await store.add("user1", "user runs 5K weekly", "preference")

            mock_db.execute.assert_called_once()
            mock_db.commit.assert_called_once()

    @pytest.mark.asyncio
    async def test_query_returns_memory_items(self) -> None:
        store = PgVectorMemoryStore()

        fake_row = MagicMock()
        fake_row.id = str(uuid.uuid4())
        fake_row.content = "user has knee injury"
        fake_row.category = "injury"
        fake_row.score = 0.85

        with (
            patch.object(store, "_embed_sync", side_effect=_fake_embedding),
            patch(
                "app.agent.context_manager.pgvector_memory_store.async_session"
            ) as mock_session_factory,
        ):
            mock_db = AsyncMock()
            mock_result = MagicMock()
            mock_result.fetchall.return_value = [fake_row]
            mock_db.execute.return_value = mock_result
            mock_session_factory.return_value.__aenter__.return_value = mock_db

            results = await store.query("user1", "running injury")

        assert len(results) == 1
        assert isinstance(results[0], MemoryItem)
        assert results[0].content == "user has knee injury"
        assert results[0].category == "injury"
        assert results[0].score == 0.85

    @pytest.mark.asyncio
    async def test_query_empty_text_returns_empty_list(self) -> None:
        store = PgVectorMemoryStore()
        results = await store.query("user1", query_text="")
        assert results == []

    @pytest.mark.asyncio
    async def test_user_isolation_different_user_ids(self) -> None:
        """Query uses WHERE user_id = :user_id — verified by checking the SQL call."""
        store = PgVectorMemoryStore()

        with (
            patch.object(store, "_embed_sync", side_effect=_fake_embedding),
            patch(
                "app.agent.context_manager.pgvector_memory_store.async_session"
            ) as mock_session_factory,
        ):
            mock_db = AsyncMock()
            mock_result = MagicMock()
            mock_result.fetchall.return_value = []
            mock_db.execute.return_value = mock_result
            mock_session_factory.return_value.__aenter__.return_value = mock_db

            await store.query("user_A", "anything")

            # The execute call must include user_A's ID as a bound parameter
            call_kwargs = mock_db.execute.call_args
            params = call_kwargs[0][1] if len(call_kwargs[0]) > 1 else call_kwargs[1]
            assert params.get("user_id") == "user_A"

    @pytest.mark.asyncio
    async def test_delete_executes_delete_sql(self) -> None:
        store = PgVectorMemoryStore()

        with patch(
            "app.agent.context_manager.pgvector_memory_store.async_session"
        ) as mock_session_factory:
            mock_db = AsyncMock()
            mock_session_factory.return_value.__aenter__.return_value = mock_db

            await store.delete("memory-123", user_id="user-abc")

            mock_db.execute.assert_called_once()
            mock_db.commit.assert_called_once()

    @pytest.mark.asyncio
    async def test_delete_scopes_by_user_id(self):
        """delete() must include user_id in the WHERE clause."""
        store = PgVectorMemoryStore()
        captured_params = {}

        async def _capture_execute(query, params):
            captured_params.update(params)
            return MagicMock()

        with patch("app.agent.context_manager.pgvector_memory_store.async_session") as mock_sf:
            mock_db = AsyncMock()
            mock_db.execute.side_effect = _capture_execute
            mock_db.commit = AsyncMock()
            mock_sf.return_value.__aenter__.return_value = mock_db
            await store.delete("mem-123", user_id="user-abc")

        assert "user_id" in captured_params
        assert captured_params["user_id"] == "user-abc"
        assert captured_params["id"] == "mem-123"
