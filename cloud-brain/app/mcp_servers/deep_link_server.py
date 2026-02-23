"""
Zuralog Cloud Brain — Deep Link MCP Server (Phase 1.12).

Exposes a single ``open_external_app`` tool so the LLM agent can
instruct the Edge Agent to launch third-party apps (Strava, Cal.ai,
etc.) via native deep link URLs. The actual URL resolution is delegated
to ``DeepLinkRegistry``; this server only handles MCP protocol plumbing.
"""

from app.mcp_servers.base_server import BaseMCPServer
from app.mcp_servers.deep_link_registry import DeepLinkRegistry
from app.mcp_servers.models import Resource, ToolDefinition, ToolResult


class DeepLinkServer(BaseMCPServer):
    """MCP server for opening external apps via deep links.

    Wraps ``DeepLinkRegistry`` in a standard MCP tool interface so the
    orchestrator can route ``open_external_app`` calls from the LLM to
    the Edge Agent without custom wiring.
    """

    # ------------------------------------------------------------------
    # BaseMCPServer properties
    # ------------------------------------------------------------------

    @property
    def name(self) -> str:
        """Unique identifier used by the MCP registry.

        Returns:
            The string ``"deep_link"``.
        """
        return "deep_link"

    @property
    def description(self) -> str:
        """Human-readable capability summary surfaced to the LLM.

        Returns:
            A description of the deep-link opening capability.
        """
        return (
            "Open external apps (Strava, Cal.ai, etc.) on the user's "
            "device via native deep links. Use this when the user wants "
            "to start a workout, log a meal, or perform another action "
            "in a third-party app."
        )

    # ------------------------------------------------------------------
    # Tool definitions
    # ------------------------------------------------------------------

    def get_tools(self) -> list[ToolDefinition]:
        """Return the single ``open_external_app`` tool definition.

        The ``app_name`` enum is populated dynamically from the
        ``DeepLinkRegistry`` so newly added apps appear automatically.

        Returns:
            A one-element list containing the tool definition.
        """
        return [
            ToolDefinition(
                name="open_external_app",
                description=(
                    "Open an external app on the user's device via a "
                    "deep link URL. Returns the URL for the Edge Agent "
                    "to handle."
                ),
                input_schema={
                    "type": "object",
                    "properties": {
                        "app_name": {
                            "type": "string",
                            "enum": DeepLinkRegistry.get_supported_apps(),
                            "description": "Target application identifier.",
                        },
                        "action": {
                            "type": "string",
                            "description": "In-app action to trigger (e.g. 'record', 'camera', 'search').",
                        },
                        "query": {
                            "type": "string",
                            "description": "Optional query parameter for search-style actions.",
                        },
                    },
                    "required": ["app_name", "action"],
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
        """Execute a deep-link tool on behalf of the given user.

        Resolves the deep link URL via ``DeepLinkRegistry`` and returns
        a ``client_action`` payload that the Edge Agent interprets to
        open the native app.

        Args:
            tool_name: Must be ``"open_external_app"``.
            params: Must include ``app_name`` and ``action``; optionally
                ``query``.
            user_id: Authenticated user requesting the action.

        Returns:
            A ``ToolResult`` with the deep link URL and fallback, or an
            error if the app/action pair is not registered.
        """
        if tool_name != "open_external_app":
            return ToolResult(success=False, error=f"Unknown tool: {tool_name}")

        app_name: str = params.get("app_name", "")
        action: str = params.get("action", "")
        query: str = params.get("query", "")

        deep_link = DeepLinkRegistry.get_deep_link(app_name, action, query=query)
        if deep_link is None:
            return ToolResult(
                success=False,
                error=f"Unsupported deep link: {app_name}/{action}",
            )

        fallback_url = DeepLinkRegistry.get_fallback_url(app_name)

        return ToolResult(
            success=True,
            data={
                "client_action": "open_url",
                "url": deep_link,
                "fallback_url": fallback_url,
                "message": f"Opening {app_name}...",
            },
        )

    # ------------------------------------------------------------------
    # Resources
    # ------------------------------------------------------------------

    async def get_resources(self, user_id: str) -> list[Resource]:
        """Return data resources available for the given user.

        The deep-link server has no user-specific resources to expose.

        Args:
            user_id: The authenticated user (unused).

        Returns:
            An empty list — this server has no readable resources.
        """
        return []
