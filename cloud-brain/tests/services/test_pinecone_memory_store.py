"""
Zuralog Cloud Brain — Tests for PineconeMemoryStore.

Validates the full lifecycle of the Pinecone memory store:
save, query, list, delete, and clear — with Pinecone and OpenAI
clients fully mocked so no real network calls are made.

Also validates:
    - Namespace isolation between different users.
    - Graceful fallback when API key is None/empty.
    - Health-tag and number extraction heuristics.
"""

from __future__ import annotations

import sys
from typing import Any
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.pinecone_memory_store import (
    MemoryEntry,
    PineconeMemoryStore,
    _extract_health_tags,
    _extract_numbers,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


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


def _make_store(
    pinecone_mock: MagicMock | None = None,
    openai_mock: MagicMock | None = None,
    api_key: str = "test-pinecone-key",
    openai_api_key: str = "test-openai-key",
) -> tuple[PineconeMemoryStore, MagicMock, MagicMock]:
    """Construct a PineconeMemoryStore with fully mocked dependencies.

    Patches ``pinecone.Pinecone`` and ``openai.AsyncOpenAI`` at the
    point of use inside PineconeMemoryStore's ``__init__``.

    Args:
        pinecone_mock: Optional pre-built Pinecone client mock.
        openai_mock: Optional pre-built AsyncOpenAI client mock.
        api_key: Pinecone API key string.
        openai_api_key: OpenAI API key string.

    Returns:
        Tuple of (store, pinecone_index_mock, openai_mock).
    """
    if pinecone_mock is None:
        pinecone_mock = MagicMock()

    index_mock = MagicMock()
    pinecone_mock.return_value.Index.return_value = index_mock

    if openai_mock is None:
        openai_mock = MagicMock()

    with (
        patch("app.services.pinecone_memory_store.Pinecone", pinecone_mock, create=True),
        patch("app.services.pinecone_memory_store.AsyncOpenAI", openai_mock, create=True),
    ):
        # We need to patch inside the method's import scope
        pass

    # Patch at module import time via sys.modules
    fake_pinecone_module = MagicMock()
    fake_pinecone_module.Pinecone = MagicMock(return_value=pinecone_mock.return_value)

    fake_openai_module = MagicMock()
    async_openai_instance = MagicMock()
    fake_openai_module.AsyncOpenAI = MagicMock(return_value=async_openai_instance)

    with patch.dict(
        sys.modules,
        {
            "pinecone": fake_pinecone_module,
            "openai": fake_openai_module,
        },
    ):
        store = PineconeMemoryStore(api_key=api_key, openai_api_key=openai_api_key)

    # Manually wire mocks so tests can control them directly
    store._index = index_mock
    store._openai = async_openai_instance
    store._enabled = True

    return store, index_mock, async_openai_instance


def _mock_embedding(dim: int = 1536) -> list[float]:
    """Return a deterministic fake embedding vector."""
    return [0.1] * dim


async def _fake_embed(store: PineconeMemoryStore, text: str) -> list[float]:
    """Patch store._embed to return a fake vector."""
    return _mock_embedding()


# ---------------------------------------------------------------------------
# Health-tag extraction tests
# ---------------------------------------------------------------------------


class TestExtractHealthTags:
    """Unit tests for the _extract_health_tags heuristic."""

    def test_extracts_known_keywords(self) -> None:
        """Relevant health terms are extracted."""
        tags = _extract_health_tags("My knee injury is causing pain during running")
        assert "knee" in tags
        assert "injury" in tags
        assert "pain" in tags
        assert "running" in tags

    def test_ignores_irrelevant_words(self) -> None:
        """Generic words are not tagged."""
        tags = _extract_health_tags("I went to the store and bought milk")
        assert tags == []

    def test_case_insensitive(self) -> None:
        """Tags are matched case-insensitively."""
        tags = _extract_health_tags("USER HAS HIGH BLOOD PRESSURE")
        assert "blood" in tags
        assert "pressure" in tags

    def test_deduplicated(self) -> None:
        """Repeated keywords appear once."""
        tags = _extract_health_tags("run run run run")
        assert tags.count("run") == 1


class TestExtractNumbers:
    """Unit tests for the _extract_numbers heuristic."""

    def test_extracts_integers(self) -> None:
        """Integer values are extracted."""
        numbers = _extract_numbers("User walked 8500 steps and burned 420 calories")
        assert 8500.0 in numbers
        assert 420.0 in numbers

    def test_extracts_floats(self) -> None:
        """Floating-point values are extracted."""
        numbers = _extract_numbers("Weight is 82.5 kg, body fat 18.3%")
        assert 82.5 in numbers
        assert 18.3 in numbers

    def test_caps_at_10(self) -> None:
        """At most 10 numbers are returned."""
        text = " ".join(str(i) for i in range(20))
        numbers = _extract_numbers(text)
        assert len(numbers) <= 10

    def test_no_numbers_returns_empty(self) -> None:
        """Text without numbers returns empty list."""
        assert _extract_numbers("no numbers here") == []


# ---------------------------------------------------------------------------
# PineconeMemoryStore tests
# ---------------------------------------------------------------------------


class TestSaveMemory:
    """Tests for PineconeMemoryStore.save_memory."""

    @pytest.mark.asyncio
    async def test_save_memory_returns_uuid_id(self) -> None:
        """save_memory returns a non-empty UUID string."""
        store, index_mock, openai_mock = _make_store()

        # Mock the embedding call
        embed_response = MagicMock()
        embed_response.data = [MagicMock(embedding=_mock_embedding())]
        openai_mock.embeddings = MagicMock()
        openai_mock.embeddings.create = AsyncMock(return_value=embed_response)

        memory_id = await store.save_memory("user-001", "Ran 5km this morning")
        assert isinstance(memory_id, str)
        assert len(memory_id) > 0

    @pytest.mark.asyncio
    async def test_save_memory_upserts_to_pinecone(self) -> None:
        """save_memory calls index.upsert with correct namespace."""
        store, index_mock, openai_mock = _make_store()

        embed_response = MagicMock()
        embed_response.data = [MagicMock(embedding=_mock_embedding())]
        openai_mock.embeddings = MagicMock()
        openai_mock.embeddings.create = AsyncMock(return_value=embed_response)

        await store.save_memory("user-001", "My goal is to run a marathon")

        index_mock.upsert.assert_called_once()
        call_kwargs = index_mock.upsert.call_args
        namespace = call_kwargs.kwargs.get("namespace") or call_kwargs[1].get("namespace")
        assert namespace == "user-001"

    @pytest.mark.asyncio
    async def test_save_memory_includes_health_tags_in_metadata(self) -> None:
        """save_memory auto-enriches metadata with health-domain tags."""
        store, index_mock, openai_mock = _make_store()

        embed_response = MagicMock()
        embed_response.data = [MagicMock(embedding=_mock_embedding())]
        openai_mock.embeddings = MagicMock()
        openai_mock.embeddings.create = AsyncMock(return_value=embed_response)

        await store.save_memory("user-001", "User has a knee injury and runs 5km daily")

        vectors = index_mock.upsert.call_args.kwargs.get("vectors") or index_mock.upsert.call_args[1].get("vectors")
        metadata = vectors[0]["metadata"]
        assert "knee" in metadata["health_tags"] or "injury" in metadata["health_tags"]


class TestQueryMemory:
    """Tests for PineconeMemoryStore.query_memory."""

    @pytest.mark.asyncio
    async def test_query_returns_memory_entries(self) -> None:
        """query_memory returns MemoryEntry objects from Pinecone matches."""
        store, index_mock, openai_mock = _make_store()

        embed_response = MagicMock()
        embed_response.data = [MagicMock(embedding=_mock_embedding())]
        openai_mock.embeddings = MagicMock()
        openai_mock.embeddings.create = AsyncMock(return_value=embed_response)

        index_mock.query.return_value = {
            "matches": [
                _make_pinecone_match("mem-001", "Ran 5km", score=0.95),
                _make_pinecone_match("mem-002", "Knee injury noted", score=0.88),
            ]
        }

        results = await store.query_memory("user-001", "running injury", top_k=5)
        assert len(results) == 2
        assert results[0].id == "mem-001"
        assert results[0].text == "Ran 5km"
        assert results[0].score == pytest.approx(0.95)
        assert results[1].score == pytest.approx(0.88)

    @pytest.mark.asyncio
    async def test_query_uses_correct_namespace(self) -> None:
        """query_memory passes user_id as namespace to Pinecone."""
        store, index_mock, openai_mock = _make_store()

        embed_response = MagicMock()
        embed_response.data = [MagicMock(embedding=_mock_embedding())]
        openai_mock.embeddings = MagicMock()
        openai_mock.embeddings.create = AsyncMock(return_value=embed_response)

        index_mock.query.return_value = {"matches": []}

        await store.query_memory("user-special-42", "any query")

        index_mock.query.assert_called_once()
        call_kwargs = index_mock.query.call_args.kwargs
        assert call_kwargs.get("namespace") == "user-special-42"

    @pytest.mark.asyncio
    async def test_query_returns_empty_on_no_matches(self) -> None:
        """query_memory returns empty list when Pinecone returns no matches."""
        store, index_mock, openai_mock = _make_store()

        embed_response = MagicMock()
        embed_response.data = [MagicMock(embedding=_mock_embedding())]
        openai_mock.embeddings = MagicMock()
        openai_mock.embeddings.create = AsyncMock(return_value=embed_response)

        index_mock.query.return_value = {"matches": []}

        results = await store.query_memory("user-001", "no relevant data")
        assert results == []


class TestDeleteMemory:
    """Tests for PineconeMemoryStore.delete_memory."""

    @pytest.mark.asyncio
    async def test_delete_returns_true_on_success(self) -> None:
        """delete_memory returns True when Pinecone call succeeds."""
        store, index_mock, _ = _make_store()
        index_mock.delete.return_value = None  # Pinecone delete returns None

        result = await store.delete_memory("user-001", "mem-abc")
        assert result is True

    @pytest.mark.asyncio
    async def test_delete_calls_pinecone_with_correct_args(self) -> None:
        """delete_memory passes correct ID and namespace to Pinecone."""
        store, index_mock, _ = _make_store()
        index_mock.delete.return_value = None

        await store.delete_memory("user-001", "mem-xyz")

        index_mock.delete.assert_called_once_with(
            ids=["mem-xyz"],
            namespace="user-001",
        )

    @pytest.mark.asyncio
    async def test_delete_returns_false_on_exception(self) -> None:
        """delete_memory returns False when Pinecone raises an exception."""
        store, index_mock, _ = _make_store()
        index_mock.delete.side_effect = Exception("Pinecone error")

        result = await store.delete_memory("user-001", "mem-bad")
        assert result is False


class TestClearMemories:
    """Tests for PineconeMemoryStore.clear_memories."""

    @pytest.mark.asyncio
    async def test_clear_returns_count_of_deleted_memories(self) -> None:
        """clear_memories returns number of memories that were present."""
        store, index_mock, openai_mock = _make_store()

        # Mock list_memories to return 3 entries
        embed_response = MagicMock()
        embed_response.data = [MagicMock(embedding=_mock_embedding())]
        openai_mock.embeddings = MagicMock()
        openai_mock.embeddings.create = AsyncMock(return_value=embed_response)

        # list_memories uses a zero-vector query
        index_mock.query.return_value = {"matches": [_make_pinecone_match(f"mem-{i}", f"Memory {i}") for i in range(3)]}
        index_mock.delete.return_value = None

        count = await store.clear_memories("user-001")
        assert count == 3

    @pytest.mark.asyncio
    async def test_clear_calls_delete_all_on_namespace(self) -> None:
        """clear_memories calls Pinecone delete with delete_all=True."""
        store, index_mock, openai_mock = _make_store()

        embed_response = MagicMock()
        embed_response.data = [MagicMock(embedding=_mock_embedding())]
        openai_mock.embeddings = MagicMock()
        openai_mock.embeddings.create = AsyncMock(return_value=embed_response)

        index_mock.query.return_value = {"matches": []}
        index_mock.delete.return_value = None

        await store.clear_memories("user-001")

        # The final call should be delete_all=True on the correct namespace
        delete_calls = index_mock.delete.call_args_list
        assert len(delete_calls) >= 1
        last_call_kwargs = delete_calls[-1].kwargs
        assert last_call_kwargs.get("delete_all") is True
        assert last_call_kwargs.get("namespace") == "user-001"


# ---------------------------------------------------------------------------
# Namespace isolation
# ---------------------------------------------------------------------------


class TestNamespaceIsolation:
    """Verify that user A cannot access user B's memories."""

    @pytest.mark.asyncio
    async def test_user_a_query_uses_user_a_namespace(self) -> None:
        """Query for user-A passes user-A namespace; never user-B."""
        store, index_mock, openai_mock = _make_store()

        embed_response = MagicMock()
        embed_response.data = [MagicMock(embedding=_mock_embedding())]
        openai_mock.embeddings = MagicMock()
        openai_mock.embeddings.create = AsyncMock(return_value=embed_response)

        index_mock.query.return_value = {"matches": []}

        await store.query_memory("user-A", "my data")

        call_kwargs = index_mock.query.call_args.kwargs
        assert call_kwargs.get("namespace") == "user-A"
        assert call_kwargs.get("namespace") != "user-B"

    @pytest.mark.asyncio
    async def test_user_b_save_uses_user_b_namespace(self) -> None:
        """save_memory for user-B upserts to user-B namespace only."""
        store, index_mock, openai_mock = _make_store()

        embed_response = MagicMock()
        embed_response.data = [MagicMock(embedding=_mock_embedding())]
        openai_mock.embeddings = MagicMock()
        openai_mock.embeddings.create = AsyncMock(return_value=embed_response)

        await store.save_memory("user-B", "User B's private memory")

        call_kwargs = index_mock.upsert.call_args.kwargs
        assert call_kwargs.get("namespace") == "user-B"

    @pytest.mark.asyncio
    async def test_delete_scoped_to_user_namespace(self) -> None:
        """delete_memory for user-A only targets user-A's namespace."""
        store, index_mock, _ = _make_store()
        index_mock.delete.return_value = None

        await store.delete_memory("user-A", "mem-123")

        call_kwargs = index_mock.delete.call_args.kwargs
        assert call_kwargs.get("namespace") == "user-A"


# ---------------------------------------------------------------------------
# Graceful fallback (disabled store)
# ---------------------------------------------------------------------------


class TestGracefulFallback:
    """Tests for PineconeMemoryStore behaviour when api_key is None or empty."""

    def _make_disabled_store(self) -> PineconeMemoryStore:
        """Create a store with no API key (disabled mode)."""
        store = PineconeMemoryStore.__new__(PineconeMemoryStore)
        store._enabled = False
        store._index = None
        store._openai = None
        store._index_name = "zuralog-memories"
        store._embed_model = "text-embedding-3-small"
        return store

    @pytest.mark.asyncio
    async def test_save_returns_dummy_id_when_disabled(self) -> None:
        """save_memory returns a dummy ID when the store is disabled."""
        store = self._make_disabled_store()
        memory_id = await store.save_memory("user-001", "some text")
        assert isinstance(memory_id, str)
        assert len(memory_id) > 0

    @pytest.mark.asyncio
    async def test_query_returns_empty_when_disabled(self) -> None:
        """query_memory returns empty list when the store is disabled."""
        store = self._make_disabled_store()
        results = await store.query_memory("user-001", "any query")
        assert results == []

    @pytest.mark.asyncio
    async def test_list_returns_empty_when_disabled(self) -> None:
        """list_memories returns empty list when the store is disabled."""
        store = self._make_disabled_store()
        results = await store.list_memories("user-001")
        assert results == []

    @pytest.mark.asyncio
    async def test_delete_returns_false_when_disabled(self) -> None:
        """delete_memory returns False when the store is disabled."""
        store = self._make_disabled_store()
        result = await store.delete_memory("user-001", "mem-xyz")
        assert result is False

    @pytest.mark.asyncio
    async def test_clear_returns_zero_when_disabled(self) -> None:
        """clear_memories returns 0 when the store is disabled."""
        store = self._make_disabled_store()
        count = await store.clear_memories("user-001")
        assert count == 0

    def test_init_with_none_api_key_creates_disabled_store(self) -> None:
        """Constructing with api_key='' results in a disabled store."""
        # No patching needed — empty key prevents Pinecone import path
        store = PineconeMemoryStore(api_key="")
        assert store._enabled is False

    def test_init_with_none_api_key_logs_warning(self, caplog: pytest.LogCaptureFixture) -> None:
        """Constructing with empty api_key logs a warning."""
        import logging

        with caplog.at_level(logging.WARNING, logger="app.services.pinecone_memory_store"):
            PineconeMemoryStore(api_key="")

        assert any("disabled" in r.message.lower() for r in caplog.records)


# ---------------------------------------------------------------------------
# Protocol compatibility
# ---------------------------------------------------------------------------


class TestProtocolCompatibility:
    """Verify PineconeMemoryStore satisfies the MemoryStore protocol shims."""

    @pytest.mark.asyncio
    async def test_add_delegates_to_save_memory(self) -> None:
        """add() is a thin alias for save_memory — should not raise."""
        store, index_mock, openai_mock = _make_store()

        embed_response = MagicMock()
        embed_response.data = [MagicMock(embedding=_mock_embedding())]
        openai_mock.embeddings = MagicMock()
        openai_mock.embeddings.create = AsyncMock(return_value=embed_response)

        # Should complete without raising
        await store.add("user-001", "Protocol shim test")
        index_mock.upsert.assert_called_once()

    @pytest.mark.asyncio
    async def test_query_method_returns_dicts(self) -> None:
        """query() (protocol shim) returns list[dict] not list[MemoryEntry]."""
        store, index_mock, openai_mock = _make_store()

        embed_response = MagicMock()
        embed_response.data = [MagicMock(embedding=_mock_embedding())]
        openai_mock.embeddings = MagicMock()
        openai_mock.embeddings.create = AsyncMock(return_value=embed_response)

        index_mock.query.return_value = {"matches": [_make_pinecone_match("m1", "Some memory")]}

        results = await store.query("user-001", query_text="test", limit=3)
        assert isinstance(results, list)
        assert all(isinstance(r, dict) for r in results)
        assert results[0]["text"] == "Some memory"
