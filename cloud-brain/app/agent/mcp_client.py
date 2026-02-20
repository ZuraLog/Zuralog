"""
Life Logger Cloud Brain — MCP Client (Tool Router).

Routes incoming tool execution requests to the correct MCP server
by querying the ``MCPServerRegistry``. This is the single entry point
for all tool calls in the system — the orchestrator never talks to
individual servers directly.
"""

import logging

from app.mcp_servers.models import ToolDefinition, ToolResult
from app.mcp_servers.registry import MCPServerRegistry

logger = logging.getLogger(__name__)


class MCPClient:
    """Routes tool calls to the appropriate MCP server.

    The client does **not** hold its own server dictionary. It delegates
    server discovery and tool lookup entirely to the ``MCPServerRegistry``,
    keeping a single source of truth for registered integrations.

    Attributes:
        _registry: The shared server registry.
    """

    def __init__(self, registry: MCPServerRegistry) -> None:
        """Create a new MCP client.

        Args:
            registry: The application-wide server registry containing
                all registered MCP servers.
        """
        self._registry = registry

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
