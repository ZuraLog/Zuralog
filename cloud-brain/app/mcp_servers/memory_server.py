"""
Zuralog Cloud Brain — Memory MCP Server.

Exposes save_memory and query_memory tools so the LLM agent can
save and search user memories mid-conversation. Backed by
PgVectorMemoryStore for persistent, vector-indexed recall.
"""

from __future__ import annotations

import logging
from typing import TYPE_CHECKING

from app.mcp_servers.base_server import BaseMCPServer
from app.mcp_servers.models import Resource, ToolDefinition, ToolResult

if TYPE_CHECKING:
    from app.agent.context_manager.pgvector_memory_store import PgVectorMemoryStore

logger = logging.getLogger(__name__)

VALID_CATEGORIES: frozenset[str] = frozenset({
    "goal",
    "injury",
    "pr",
    "preference",
    "context",
    "program",
})


class MemoryMCPServer(BaseMCPServer):
    """MCP server exposing save_memory and query_memory to the LLM agent.

    Delegates all persistence to the injected memory store. Only
    registered when PgVectorMemoryStore is available (i.e. when
    JINA_API_KEY is configured) so memories are never silently lost
    to an in-memory fallback.

    Args:
        memory_store: A ``PgVectorMemoryStore`` instance that provides
            the async ``add()`` and ``query()`` interface.
    """

    _store: PgVectorMemoryStore

    def __init__(self, memory_store: PgVectorMemoryStore) -> None:
        """Initialise the server with an injected memory store.

        Args:
            memory_store: ``PgVectorMemoryStore`` instance exposing async add() and query().
        """
        self._store = memory_store

    # ------------------------------------------------------------------
    # BaseMCPServer properties
    # ------------------------------------------------------------------

    @property
    def name(self) -> str:
        """Unique identifier used by the MCP registry.

        Returns:
            The string ``"memory"``.
        """
        return "memory"

    @property
    def description(self) -> str:
        """Human-readable capability summary surfaced to the LLM.

        Returns:
            A description of the memory save/search capability.
        """
        return (
            "Save and search the user's long-term memories. Use "
            "save_memory to store important facts the user shares, "
            "and query_memory to find previously stored context "
            "relevant to the current conversation."
        )

    # ------------------------------------------------------------------
    # Tool definitions
    # ------------------------------------------------------------------

    def get_tools(self) -> list[ToolDefinition]:
        """Return the save_memory and query_memory tool definitions.

        Returns:
            A two-element list containing both tool definitions.
        """
        return [
            ToolDefinition(
                name="save_memory",
                description=(
                    "Save an important fact about the user to long-term "
                    "memory so it can be recalled in future conversations."
                ),
                input_schema={
                    "type": "object",
                    "properties": {
                        "content": {
                            "type": "string",
                            "description": "The fact to remember.",
                        },
                        "category": {
                            "type": "string",
                            "enum": sorted(VALID_CATEGORIES),
                            "description": (
                                "Semantic category: one of context, goal, "
                                "injury, preference, pr, program."
                            ),
                        },
                    },
                    "required": ["content", "category"],
                },
            ),
            ToolDefinition(
                name="query_memory",
                description=(
                    "Search stored memories for context relevant to the "
                    "current conversation."
                ),
                input_schema={
                    "type": "object",
                    "properties": {
                        "query": {
                            "type": "string",
                            "description": "What to search for.",
                        },
                        "limit": {
                            "type": "integer",
                            "description": "Maximum number of results to return (1–10).",
                            "default": 5,
                            "maximum": 10,
                        },
                    },
                    "required": ["query"],
                },
            ),
        ]

    # ------------------------------------------------------------------
    # Tool execution
    # ------------------------------------------------------------------

    async def execute_tool(
        self,
        tool_name: str,
        params: dict,
        user_id: str,
    ) -> ToolResult:
        """Dispatch a tool call to the appropriate handler.

        Args:
            tool_name: One of ``save_memory`` or ``query_memory``.
            params: Parameter dict matching the tool's ``input_schema``.
            user_id: The authenticated user whose memories to read/write.

        Returns:
            A ``ToolResult`` with the operation outcome.
        """
        if tool_name == "save_memory":
            return await self._save_memory(params, user_id)
        if tool_name == "query_memory":
            return await self._query_memory(params, user_id)
        return ToolResult(success=False, error=f"Unknown tool: {tool_name}")

    async def _save_memory(self, params: dict, user_id: str) -> ToolResult:
        """Validate and persist a memory fact for the user.

        Args:
            params: Must contain ``content`` (str) and ``category`` (str).
            user_id: The user whose memory store to write to.

        Returns:
            Success result with confirmation message, or error result
            when category is invalid or the store raises an exception.
        """
        content: str = params.get("content", "")
        category: str = params.get("category", "")

        if not content.strip():
            return ToolResult(success=False, error="content must not be empty.")

        if category not in VALID_CATEGORIES:
            return ToolResult(
                success=False,
                error=(
                    f"Invalid category: '{category}'. "
                    f"Must be one of: {sorted(VALID_CATEGORIES)}"
                ),
            )

        try:
            await self._store.add(user_id=user_id, content=content, category=category)
            return ToolResult(success=True, data={"message": "Memory saved."})
        except Exception as exc:
            logger.exception("save_memory failed for user '%s'", user_id[:8])
            return ToolResult(success=False, error=str(exc))

    async def _query_memory(self, params: dict, user_id: str) -> ToolResult:
        """Search the user's memories for relevant context.

        The ``limit`` parameter is capped at 10 server-side regardless
        of what the caller passes in.

        Args:
            params: Must contain ``query`` (str); optionally ``limit`` (int).
            user_id: The user whose memories to search.

        Returns:
            Success result with a ``memories`` list, or error result when
            the store raises an exception. Returns an empty list when
            ``query`` is empty (the store short-circuits on empty queries).
        """
        query_text: str = params.get("query", "")
        limit: int = min(int(params.get("limit", 5)), 10)

        if not query_text:
            return ToolResult(success=True, data={"memories": []})

        try:
            items = await self._store.query(
                user_id=user_id,
                query_text=query_text,
                limit=limit,
            )
            memories = [
                {
                    "id": item.id,
                    "content": item.content,
                    "category": item.category,
                    "score": item.score,
                }
                for item in items
            ]
            return ToolResult(success=True, data={"memories": memories})
        except Exception as exc:
            logger.exception("query_memory failed for user '%s'", user_id[:8])
            return ToolResult(success=False, error=str(exc))

    # ------------------------------------------------------------------
    # Resources
    # ------------------------------------------------------------------

    async def get_resources(self, user_id: str) -> list[Resource]:
        """Return data resources available for the given user.

        The memory server has no readable resources — memories are
        accessed exclusively through the query_memory tool.

        Args:
            user_id: The authenticated user (unused).

        Returns:
            An empty list.
        """
        return []
