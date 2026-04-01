"""
Zuralog Cloud Brain — Notification MCP Server.

Exposes a single ``send_notification`` tool so the LLM agent can send
push notifications to all of the user's registered devices. Delivery is
delegated to ``PushService.send_and_persist``, which fans out to every
FCM token and writes a ``NotificationLog`` row in a single call. This
server is always-on — no OAuth integration required.
"""

from __future__ import annotations

from collections.abc import Callable
from typing import TYPE_CHECKING, Any

from app.mcp_servers.base_server import BaseMCPServer
from app.mcp_servers.models import Resource, ToolDefinition, ToolResult

if TYPE_CHECKING:
    from app.services.push_service import PushService


class NotificationServer(BaseMCPServer):
    """MCP server for sending AI-initiated push notifications.

    Exposes one tool to the LLM agent:
    - ``send_notification``: Push a title/body notification to all of the
      user's registered devices and persist a log entry.

    The server is always available — no per-user integration or OAuth
    token is required. ``PushService`` handles FCM fan-out and gracefully
    no-ops when FCM is not configured (e.g. in local development), so
    the tool always returns ``success=True`` as long as validation passes.

    Args:
        db_factory: Callable that returns an async context manager yielding
            an ``AsyncSession`` (e.g. ``async_session`` from
            ``app.database``). Used to open a session for
            ``send_and_persist``.
        push_service: ``PushService`` instance responsible for FCM fan-out
            and notification logging.
    """

    def __init__(
        self,
        db_factory: Callable[[], Any],
        push_service: PushService,
    ) -> None:
        """Initialise the server.

        Args:
            db_factory: Async session factory — called each time a tool
                is executed to obtain a short-lived DB session.
            push_service: Injected push service that delivers FCM messages
                and persists ``NotificationLog`` rows.
        """
        self._db_factory = db_factory
        self._push_service = push_service

    # ------------------------------------------------------------------
    # BaseMCPServer properties
    # ------------------------------------------------------------------

    @property
    def name(self) -> str:
        """Unique identifier used by the MCP registry.

        Returns:
            The string ``"notification"``.
        """
        return "notification"

    @property
    def description(self) -> str:
        """Human-readable capability summary surfaced to the LLM.

        Returns:
            A description of the push notification capability.
        """
        return (
            "Send a push notification to all of the user's registered "
            "devices. Use this to deliver reminders, coaching nudges, or "
            "important updates directly to the user's phone."
        )

    # ------------------------------------------------------------------
    # Tool definitions
    # ------------------------------------------------------------------

    def get_tools(self) -> list[ToolDefinition]:
        """Return the single ``send_notification`` tool definition.

        Returns:
            A one-element list containing the tool definition.
        """
        return [
            ToolDefinition(
                name="send_notification",
                description=(
                    "Send a push notification to all of the user's "
                    "registered devices. The notification is also logged "
                    "to the database regardless of FCM delivery status."
                ),
                input_schema={
                    "type": "object",
                    "properties": {
                        "title": {
                            "type": "string",
                            "description": "Notification title shown in bold on the device (max 100 characters).",
                            "maxLength": 100,
                        },
                        "body": {
                            "type": "string",
                            "description": "Notification body text shown below the title (max 250 characters).",
                            "maxLength": 250,
                        },
                    },
                    "required": ["title", "body"],
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
        """Execute the ``send_notification`` tool on behalf of the given user.

        Validates ``title`` and ``body``, then delegates to
        ``PushService.send_and_persist`` inside a short-lived DB session.
        The ``delivered`` flag in the result payload is ``True`` when FCM
        successfully reached at least one device, and ``False`` when FCM
        is not configured (notification is still logged).

        Args:
            tool_name: Must be ``"send_notification"``.
            params: Must include ``title`` (str) and ``body`` (str).
            user_id: Authenticated user whose devices will receive the push.

        Returns:
            A ``ToolResult`` with ``data={"delivered": bool, "title": str,
            "body": str}`` on success, or an error result when validation
            fails or an unknown tool name is supplied.
        """
        if tool_name != "send_notification":
            return ToolResult(success=False, error=f"Unknown tool: {tool_name}")

        title: str = str(params.get("title", "")).strip()
        body: str = str(params.get("body", "")).strip()

        if not title:
            return ToolResult(success=False, error="title must not be empty.")
        if len(title) > 100:
            return ToolResult(
                success=False,
                error=f"title exceeds 100 characters (got {len(title)}).",
            )
        if not body:
            return ToolResult(success=False, error="body must not be empty.")
        if len(body) > 250:
            return ToolResult(
                success=False,
                error=f"body exceeds 250 characters (got {len(body)}).",
            )

        async with self._db_factory() as db:
            sent = await self._push_service.send_and_persist(
                user_id=user_id,
                title=title,
                body=body,
                notification_type="coach",
                db=db,
            )

        return ToolResult(
            success=True,
            data={"delivered": sent, "title": title, "body": body},
        )

    # ------------------------------------------------------------------
    # Resources
    # ------------------------------------------------------------------

    async def get_resources(self, user_id: str) -> list[Resource]:
        """Return data resources available for the given user.

        Notifications are write-only — there is nothing to read back via
        the resource API.

        Args:
            user_id: The authenticated user (unused).

        Returns:
            An empty list — this server has no readable resources.
        """
        return []
