"""
Zuralog Cloud Brain — Tests for PineconeMemoryStore.

Validates the full lifecycle of the Pinecone memory store:
save, query, list, delete, and clear — with Pinecone and OpenAI
clients fully mocked so no real network calls are made.

Also validates:
    - Namespace isolation between different users.
    - Graceful fallback when API keys are not set.
"""

from __future__ import annotations

import os
from typing import Any
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.pinecone_memory_store import PineconeMemoryStore


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _make_mock_match(
    memory_id: str,
    text: str,
    score: float = 0.9,
    extra_meta: dict | None = None,
) -> MagicMock:
    """Build a MagicMock that mimics a Pinecone query-result match object."""
    meta: dict[str, Any] = {"text": text, "user_id": "user-001"}
    if extra_meta:
        meta.update(extra_meta)
    match = MagicMock()
    match.id = memory_id
    match.score = score
    match.metadata = meta
    return match


def _make_pinecone_match(
    memory_id: str,
    text: str,
    score: float = 0.9,
    extra_meta: dict | None = None,
) -> dict[str, Any]:
    """Build a dict that mimics a Pinecone query-result match."""
    meta: dict[str, Any] = {"text": text, "user_id": "user-001"}
    if extra_meta:
        meta.update(extra_meta)
    return {"id": memory_id, "score": score, "metadata": meta}


def _mock_embedding(dim: int = 1536) -> list[float]:
    """Return a deterministic fake embedding vector."""
    return [0.1] * dim


def _make_enabled_store() -> tuple[PineconeMemoryStore, MagicMock, MagicMock]:
    """Construct a PineconeMemoryStore with fully mocked internals.

    Bypasses the __init__ env var checks by directly wiring mocks onto
    the store's internal attributes.

    Returns:
        (store, pinecone_index_mock, openai_client_mock)
    """
    store = PineconeMemoryStore.__new__(PineconeMemoryStore)
    index_mock = MagicMock()
    openai_mock = MagicMock()

    store._pinecone_api_key = "test-pinecone-key"
    store._pinecone_index_name = "zuralog-memories"
    store._openai_api_key = "test-openai-key"
    store._pc = MagicMock()
    store._index = index_mock
    store._openai = openai_mock

    return store, index_mock, openai_mock


def _wire_embed(openai_mock: MagicMock, dim: int = 1536) -> None:
    """Make openai_mock.embeddings.create return a fake embedding."""
    embed_response = MagicMock()
    embed_response.data = [MagicMock(embedding=_mock_embedding(dim))]
    openai_mock.embeddings = MagicMock()
    openai_mock.embeddings.create = MagicMock(return_value=embed_response)


# ---------------------------------------------------------------------------
# Graceful fallback (disabled store — no API keys)
# ---------------------------------------------------------------------------


class TestGracefulFallback:
    """Tests for PineconeMemoryStore when no API keys are set."""

    def _make_disabled_store(self) -> PineconeMemoryStore:
        store = PineconeMemoryStore.__new__(PineconeMemoryStore)
        store._pinecone_api_key = ""
        store._openai_api_key = ""
        store._pinecone_index_name = "zuralog-memories"
        store._pc = None
        store._index = None
        store._openai = None
        return store

    def test_is_available_false_when_no_keys(self) -> None:
        store = self._make_disabled_store()
        assert store.is_available is False

    @pytest.mark.asyncio
    async def test_save_memory_returns_none_when_disabled(self) -> None:
        store = self._make_disabled_store()
        memory_id = await store.save_memory("user-001", "some text")
        # Disabled store returns None (store unavailable)
        assert memory_id is None

    @pytest.mark.asyncio
    async def test_query_memory_returns_empty_when_disabled(self) -> None:
        store = self._make_disabled_store()
        results = await store.query_memory("user-001", "any query")
        assert results == []

    @pytest.mark.asyncio
    async def test_list_memories_returns_empty_when_disabled(self) -> None:
        store = self._make_disabled_store()
        results = await store.list_memories("user-001")
        assert results == []

    @pytest.mark.asyncio
    async def test_delete_returns_false_when_disabled(self) -> None:
        store = self._make_disabled_store()
        result = await store.delete_memory("user-001", "mem-xyz")
        assert result is False

    @pytest.mark.asyncio
    async def test_clear_returns_false_when_disabled(self) -> None:
        """clear_memories returns False when the store is disabled."""
        store = self._make_disabled_store()
        result = await store.clear_memories("user-001")
        assert result is False


# ---------------------------------------------------------------------------
# is_available property
# ---------------------------------------------------------------------------


class TestIsAvailable:
    def test_is_available_when_index_and_openai_wired(self) -> None:
        store, _, _ = _make_enabled_store()
        assert store.is_available is True

    def test_is_not_available_when_index_is_none(self) -> None:
        store, _, _ = _make_enabled_store()
        store._index = None
        assert store.is_available is False


# ---------------------------------------------------------------------------
# save_memory
# ---------------------------------------------------------------------------


class TestSaveMemory:
    @pytest.mark.asyncio
    async def test_save_returns_nonempty_id(self) -> None:
        store, index_mock, openai_mock = _make_enabled_store()
        _wire_embed(openai_mock)

        memory_id = await store.save_memory("user-001", "Ran 5km this morning")
        assert isinstance(memory_id, str)
        assert len(memory_id) > 0

    @pytest.mark.asyncio
    async def test_save_upserts_to_correct_namespace(self) -> None:
        store, index_mock, openai_mock = _make_enabled_store()
        _wire_embed(openai_mock)

        await store.save_memory("user-001", "My goal is to run a marathon")

        index_mock.upsert.assert_called_once()
        call_kwargs = index_mock.upsert.call_args
        namespace = call_kwargs.kwargs.get("namespace") or call_kwargs[1].get("namespace")
        assert namespace == "user-001"


# ---------------------------------------------------------------------------
# query_memory
# ---------------------------------------------------------------------------


class TestQueryMemory:
    @pytest.mark.asyncio
    async def test_query_returns_dict_list(self) -> None:
        store, index_mock, openai_mock = _make_enabled_store()
        _wire_embed(openai_mock)

        # The Pinecone SDK returns an object with a .matches attribute (not a dict)
        query_response = MagicMock()
        query_response.matches = [
            _make_mock_match("mem-001", "Ran 5km", score=0.95),
            _make_mock_match("mem-002", "Knee injury noted", score=0.88),
        ]
        index_mock.query.return_value = query_response

        results = await store.query_memory("user-001", "running injury", limit=5)
        assert len(results) == 2

    @pytest.mark.asyncio
    async def test_query_uses_correct_namespace(self) -> None:
        store, index_mock, openai_mock = _make_enabled_store()
        _wire_embed(openai_mock)
        index_mock.query.return_value = {"matches": []}

        await store.query_memory("user-special-42", "any query")

        index_mock.query.assert_called_once()
        call_kwargs = index_mock.query.call_args.kwargs
        assert call_kwargs.get("namespace") == "user-special-42"

    @pytest.mark.asyncio
    async def test_query_returns_empty_on_no_matches(self) -> None:
        store, index_mock, openai_mock = _make_enabled_store()
        _wire_embed(openai_mock)
        index_mock.query.return_value = {"matches": []}

        results = await store.query_memory("user-001", "no relevant data")
        assert results == []


# ---------------------------------------------------------------------------
# delete_memory
# ---------------------------------------------------------------------------


class TestDeleteMemory:
    @pytest.mark.asyncio
    async def test_delete_returns_true_on_success(self) -> None:
        store, index_mock, _ = _make_enabled_store()
        index_mock.delete.return_value = None

        result = await store.delete_memory("user-001", "mem-abc")
        assert result is True

    @pytest.mark.asyncio
    async def test_delete_calls_pinecone_with_correct_args(self) -> None:
        store, index_mock, _ = _make_enabled_store()
        index_mock.delete.return_value = None

        await store.delete_memory("user-001", "mem-xyz")

        index_mock.delete.assert_called_once_with(
            ids=["mem-xyz"],
            namespace="user-001",
        )

    @pytest.mark.asyncio
    async def test_delete_returns_false_on_exception(self) -> None:
        store, index_mock, _ = _make_enabled_store()
        index_mock.delete.side_effect = Exception("Pinecone error")

        result = await store.delete_memory("user-001", "mem-bad")
        assert result is False


# ---------------------------------------------------------------------------
# Namespace isolation
# ---------------------------------------------------------------------------


class TestNamespaceIsolation:
    @pytest.mark.asyncio
    async def test_query_scoped_to_user_namespace(self) -> None:
        store, index_mock, openai_mock = _make_enabled_store()
        _wire_embed(openai_mock)
        index_mock.query.return_value = {"matches": []}

        await store.query_memory("user-A", "my data")

        call_kwargs = index_mock.query.call_args.kwargs
        assert call_kwargs.get("namespace") == "user-A"
        assert call_kwargs.get("namespace") != "user-B"

    @pytest.mark.asyncio
    async def test_save_scoped_to_user_namespace(self) -> None:
        store, index_mock, openai_mock = _make_enabled_store()
        _wire_embed(openai_mock)

        await store.save_memory("user-B", "User B's private memory")

        call_kwargs = index_mock.upsert.call_args.kwargs
        assert call_kwargs.get("namespace") == "user-B"

    @pytest.mark.asyncio
    async def test_delete_scoped_to_user_namespace(self) -> None:
        store, index_mock, _ = _make_enabled_store()
        index_mock.delete.return_value = None

        await store.delete_memory("user-A", "mem-123")

        call_kwargs = index_mock.delete.call_args.kwargs
        assert call_kwargs.get("namespace") == "user-A"


# ---------------------------------------------------------------------------
# Protocol compatibility (add / query shims)
# ---------------------------------------------------------------------------


class TestProtocolCompatibility:
    @pytest.mark.asyncio
    async def test_add_delegates_to_save_memory(self) -> None:
        store, index_mock, openai_mock = _make_enabled_store()
        _wire_embed(openai_mock)

        await store.add("user-001", "Protocol shim test")
        index_mock.upsert.assert_called_once()

    @pytest.mark.asyncio
    async def test_query_shim_returns_list(self) -> None:
        store, index_mock, openai_mock = _make_enabled_store()
        _wire_embed(openai_mock)
        index_mock.query.return_value = {"matches": [_make_pinecone_match("m1", "Some memory")]}

        results = await store.query("user-001", query_text="test", limit=3)
        assert isinstance(results, list)
