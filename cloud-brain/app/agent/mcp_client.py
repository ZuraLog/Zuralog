"""
Zuralog Cloud Brain — MCP Client (Tool Router).

Routes incoming tool execution requests to the correct MCP server
by querying the ``MCPServerRegistry``. This is the single entry point
for all tool calls in the system — the orchestrator never talks to
individual servers directly.
"""

from __future__ import annotations

import logging
from typing import TYPE_CHECKING

import sentry_sdk
from app.mcp_servers.models import ToolDefinition, ToolResult
from app.mcp_servers.registry import MCPServerRegistry

if TYPE_CHECKING:
    from sqlalchemy.ext.asyncio import AsyncSession

    from app.services.user_tool_resolver import UserToolResolver

logger = logging.getLogger(__name__)


class MCPClient:
    """Routes tool calls to the appropriate MCP server.

    The client does **not** hold its own server dictionary. It delegates
    server discovery and tool lookup entirely to the ``MCPServerRegistry``,
    keeping a single source of truth for registered integrations.

    Attributes:
        _registry: The shared server registry.
    """

    def __init__(
        self,
        registry: MCPServerRegistry,
        tool_resolver: UserToolResolver | None = None,
    ) -> None:
        """Create a new MCP client.

        Args:
            registry: The application-wide server registry containing
                all registered MCP servers.
            tool_resolver: Optional resolver for per-user tool filtering.
                If None, ``get_tools_for_user()`` falls back to returning
                all tools (backwards compatibility).
        """
        self._registry = registry
        self._tool_resolver = tool_resolver

    async def execute_tool(
        self,
        tool_name: str,
        params: dict,
        user_id: str,
    ) -> ToolResult:
        """Execute a tool call by routing to the owning server.

        Looks up which server exposes the requested tool, then
        delegates execution. Returns an error ``ToolResult`` if no
        server owns the tool or if execution raises an exception.

        Args:
            tool_name: The tool identifier (e.g. ``"get_activities"``).
            params: Parameter dict matching the tool's input schema.
            user_id: The authenticated user making the request.

        Returns:
            A ``ToolResult`` with the execution outcome.
        """
        server = self._registry.get_by_tool(tool_name)

        if server is None:
            logger.warning("Tool '%s' not found in any registered server", tool_name)
            return ToolResult(
                success=False,
                error=f"Tool '{tool_name}' not found in any registered server.",
            )

        try:
            logger.info(
                "Routing tool '%s' to server '%s' for user '%s'",
                tool_name,
                server.name,
                user_id,
            )
            return await server.execute_tool(tool_name, params, user_id)
        except Exception as exc:
            logger.exception(
                "Tool '%s' on server '%s' raised an exception",
                tool_name,
                server.name,
            )
            sentry_sdk.capture_exception(exc)
            return ToolResult(
                success=False,
                error=f"Tool execution failed: {exc}",
            )

    def get_all_tools(self) -> list[ToolDefinition]:
        """Get a consolidated list of all tools from all servers.

        Delegates to the registry's aggregation method to ensure
        an always-up-to-date view of available capabilities.

        Returns:
            A flat list of ``ToolDefinition`` models.
        """
        return self._registry.get_all_tools()

    async def get_tools_for_user(
        self,
        db: AsyncSession,
        user_id: str,
    ) -> list[ToolDefinition]:
        """Get tools filtered by the user's connected integrations.

        Delegates to the ``UserToolResolver`` if one was provided at
        construction time. Falls back to ``get_all_tools()`` if no
        resolver is available (backwards compatibility).

        Args:
            db: An active async database session.
            user_id: The authenticated user's ID.

        Returns:
            A filtered list of ``ToolDefinition`` models.
        """
        if self._tool_resolver is not None:
            return await self._tool_resolver.resolve_tools(db, user_id)
        return self._registry.get_all_tools()

    def get_skill_index(self) -> str | None:
        """Return the formatted skill index for injection into the system prompt.

        Looks up the coach_skills server in the registry and returns its
        pre-built index text — a newline-joined list of available skills
        and their one-line descriptions. Returns None if the server is not
        registered or if the index is empty.

        Returns:
            The skill index string, or None if unavailable.
        """
        server = self._registry.get("coach_skills")
        if server is None:
            return None
        from app.mcp_servers.coach_skill_server import CoachSkillMCPServer
        if isinstance(server, CoachSkillMCPServer):
            return server.get_index_text() or None
        return None
