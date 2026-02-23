"""
Zuralog Cloud Brain — Abstract MCP Server Base Class.

All external integrations (Strava, Apple Health, Google Health Connect,
etc.) must inherit from ``BaseMCPServer`` and implement its abstract
methods. This enforces a consistent interface that the ``MCPClient``
can route tool calls through without per-server special-casing.
"""

from abc import ABC, abstractmethod

from app.mcp_servers.models import Resource, ToolDefinition, ToolResult


class BaseMCPServer(ABC):
    """Abstract base class for all MCP integration servers.

    Subclasses must implement:
    - ``name`` — unique server identifier.
    - ``description`` — human-readable summary for LLM system prompts.
    - ``get_tools()`` — list of tools this server exposes.
    - ``execute_tool()`` — run a named tool and return a ``ToolResult``.
    - ``get_resources()`` — list of data resources available to the LLM.

    The optional ``health_check()`` method returns ``True`` by default
    and can be overridden to verify connectivity to external APIs.
    """

    # ------------------------------------------------------------------
    # Abstract properties
    # ------------------------------------------------------------------

    @property
    @abstractmethod
    def name(self) -> str:
        """Unique machine-readable identifier for this server.

        Used as the key in ``MCPServerRegistry`` and for log correlation.

        Returns:
            A short lowercase string (e.g. ``"strava"``, ``"healthkit"``).
        """

    @property
    @abstractmethod
    def description(self) -> str:
        """Human-readable summary of this server's capabilities.

        Included in the LLM system prompt so the AI understands what
        this integration can do.

        Returns:
            A descriptive sentence or short paragraph.
        """

    # ------------------------------------------------------------------
    # Abstract methods
    # ------------------------------------------------------------------

    @abstractmethod
    def get_tools(self) -> list[ToolDefinition]:
        """Return the tool schemas this server exposes.

        The orchestrator aggregates tools from all registered servers
        and presents them to the LLM for function-calling.

        Returns:
            A list of ``ToolDefinition`` models.
        """

    @abstractmethod
    async def execute_tool(
        self,
        tool_name: str,
        params: dict,
        user_id: str,
    ) -> ToolResult:
        """Execute a named tool with the given parameters.

        Args:
            tool_name: The tool to invoke (must match a name from
                ``get_tools()``).
            params: Parameter dict matching the tool's ``input_schema``.
            user_id: The authenticated user requesting the action.

        Returns:
            A ``ToolResult`` indicating success or failure.
        """

    @abstractmethod
    async def get_resources(self, user_id: str) -> list[Resource]:
        """Return data resources available for the given user.

        Resources provide read-only context the AI can reference
        during a conversation (e.g. recent workout history).

        Args:
            user_id: The authenticated user.

        Returns:
            A list of ``Resource`` models.
        """

    # ------------------------------------------------------------------
    # Optional overrides
    # ------------------------------------------------------------------

    async def health_check(self) -> bool:
        """Verify that the external service is reachable.

        Override in subclasses that connect to third-party APIs.
        The default implementation always returns ``True``.

        Returns:
            ``True`` if the service is healthy, ``False`` otherwise.
        """
        return True
