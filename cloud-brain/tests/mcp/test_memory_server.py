"""Tests for the MemoryMCPServer MCP server.
"""

from __future__ import annotations
from dataclasses import dataclass
from unittest.mock import AsyncMock
import pytest
from app.mcp_servers.models import ToolDefinition, ToolResult

@dataclass
class FakeMemoryItem:
    id: str
    content: str
    category: str
    score: float = 1.0

class FakeMemoryStore:
    """In-process fake."""
    def __init__(self) -> None:
        self.add_calls: list[dict] = []
        self.query_calls: list[dict] = []
    async def add(self, user_id, content, category, source_conversation_id=None):
        self.add_calls.append({"user_id": user_id, "content": content, "category": category})
    async def query(self, user_id, query_text="", limit=5):
        self.query_calls.append({"user_id": user_id, "query_text": query_text, "limit": limit})
        if not query_text: return []
        return [FakeMemoryItem(id="mem-1", content="runs 5k", category="preference", score=0.92)]

@pytest.fixture
def fake_store():
    return FakeMemoryStore()

@pytest.fixture
def server(fake_store):
    from app.mcp_servers.memory_server import MemoryMCPServer
    return MemoryMCPServer(memory_store=fake_store)

class TestProps:
    def test_name(self, server):
        assert server.name == "memory"
    def test_desc(self, server):
        assert len(server.description) > 0

class TestTools:
    def test_count(self, server):
        assert len(server.get_tools()) == 2
    def test_save_schema(self, server):
        tools = server.get_tools()
        save = next(t for t in tools if t.name == "save_memory")
        assert "content" in save.input_schema["properties"]
        assert "category" in save.input_schema["properties"]
    def test_query_schema(self, server):
        tools = server.get_tools()
        q = next(t for t in tools if t.name == "query_memory")
        assert "query" in q.input_schema["properties"]
        assert q.input_schema["properties"]["limit"]["maximum"] == 10

class TestSave:
    @pytest.mark.asyncio
    async def test_success(self, server, fake_store):
        r = await server.execute_tool("save_memory", {"content": "marathon goal", "category": "goal"}, "u1")
        assert r.success is True
        assert r.data["message"] == "Memory saved."
    @pytest.mark.asyncio
    async def test_all_categories(self, server, fake_store):
        for c in ["goal", "injury", "pr", "preference", "context", "program"]:
            r = await server.execute_tool("save_memory", {"content": "t", "category": c}, "u1")
            assert r.success is True
    @pytest.mark.asyncio
    async def test_invalid_category(self, server, fake_store):
        r = await server.execute_tool("save_memory", {"content": "t", "category": "bad"}, "u1")
        assert r.success is False
        assert "Invalid category" in r.error
    @pytest.mark.asyncio
    async def test_exception(self, server):
        from app.mcp_servers.memory_server import MemoryMCPServer
        s = AsyncMock(); s.add = AsyncMock(side_effect=RuntimeError("boom"))
        r = await MemoryMCPServer(memory_store=s).execute_tool("save_memory", {"content": "t", "category": "goal"}, "u1")
        assert r.success is False

class TestQuery:
    @pytest.mark.asyncio
    async def test_success(self, server, fake_store):
        r = await server.execute_tool("query_memory", {"query": "running"}, "u1")
        assert r.success is True
        assert len(r.data["memories"]) == 1
    @pytest.mark.asyncio
    async def test_limit_cap(self, server, fake_store):
        await server.execute_tool("query_memory", {"query": "g", "limit": 50}, "u1")
        assert fake_store.query_calls[0]["limit"] == 10
    @pytest.mark.asyncio
    async def test_empty_query(self, server, fake_store):
        r = await server.execute_tool("query_memory", {"query": ""}, "u1")
        assert r.data["memories"] == []
    @pytest.mark.asyncio
    async def test_exception(self, server):
        from app.mcp_servers.memory_server import MemoryMCPServer
        s = AsyncMock(); s.query = AsyncMock(side_effect=RuntimeError("boom"))
        r = await MemoryMCPServer(memory_store=s).execute_tool("query_memory", {"query": "x"}, "u1")
        assert r.success is False

class TestMisc:
    @pytest.mark.asyncio
    async def test_unknown_tool(self, server):
        r = await server.execute_tool("nope", {}, "u1")
        assert r.success is False
    @pytest.mark.asyncio
    async def test_resources_empty(self, server):
        assert await server.get_resources("u1") == []
