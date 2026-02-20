"""
Life Logger Cloud Brain — MCP Server Registry.

Central registry managing the lifecycle and discovery of all MCP
servers. The ``MCPClient`` queries this registry to route tool calls
to the correct integration server.

Instantiated once during application startup (in ``main.py`` lifespan)
and stored on ``app.state`` for dependency injection — **not** as a
module-level singleton.
"""

import logging

from app.mcp_servers.base_server import BaseMCPServer
from app.mcp_servers.models import ToolDefinition

logger = logging.getLogger(__name__)


class MCPServerRegistry:
    """Central registry for all MCP integration servers.

    Provides server registration with duplicate detection, lookup by
    name, and aggregated tool discovery across all registered servers.

    Attributes:
        _servers: Internal mapping of server name → instance.
    """

    def __init__(self) -> None:
        """Initialise an empty registry."""
        self._servers: dict[str, BaseMCPServer] = {}

    # ------------------------------------------------------------------
    # Registration
    # ------------------------------------------------------------------

    def register(self, server: BaseMCPServer) -> None:
        """Register an MCP server.

        Args:
            server: The server instance to register.

        Raises:
            ValueError: If a server with the same name is already
                registered, preventing silent overwrites.
        """
        if server.name in self._servers:
            raise ValueError(
                f"MCP server '{server.name}' is already registered. "
                "Use a unique name for each integration."
            )
        self._servers[server.name] = server
        logger.info("Registered MCP server: %s", server.name)

    # ------------------------------------------------------------------
    # Lookup
    # ------------------------------------------------------------------

    def get(self, name: str) -> BaseMCPServer | None:
        """Retrieve a server by its unique name.

        Args:
            name: The server identifier (e.g. ``"strava"``).

        Returns:
            The server instance, or ``None`` if not found.
        """
        return self._servers.get(name)

    def get_by_tool(self, tool_name: str) -> BaseMCPServer | None:
        """Find which server owns a given tool.

        Iterates registered servers and checks their tool lists.
        Returns on the first match.

        Args:
            tool_name: The tool identifier to search for.

        Returns:
            The owning server, or ``None`` if no server exposes
            a tool with that name.
        """
        for server in self._servers.values():
            tool_names = [t.name for t in server.get_tools()]
            if tool_name in tool_names:
                return server
        return None

    # ------------------------------------------------------------------
    # Aggregation
    # ------------------------------------------------------------------

    def list_all(self) -> list[BaseMCPServer]:
        """Return all registered servers.

        Returns:
            A list of server instances in registration order.
        """
        return list(self._servers.values())

    def get_all_tools(self) -> list[ToolDefinition]:
        """Aggregate tool definitions from every registered server.

        This replaces the static ``TOOLS_SCHEMA`` string from the
        original plan. The LLM prompt builder calls this at runtime
        to get an always-up-to-date view of available capabilities.

        Returns:
            A flat list of ``ToolDefinition`` models.
        """
        tools: list[ToolDefinition] = []
        for server in self._servers.values():
            tools.extend(server.get_tools())
        return tools
