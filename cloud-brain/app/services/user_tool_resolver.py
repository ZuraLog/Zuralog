"""
Zuralog Cloud Brain — User Tool Resolver.

Determines which MCP tools to present to the LLM for a given user,
based on their connected integrations. This is the core of the dynamic
tool injection system.

Always-on servers (Apple Health, Health Connect, DeepLink, Memory) are injected
unconditionally. OAuth-dependent servers (Strava, Fitbit, Oura,
Withings, Polar) are only included if the user has an active integration
row in the database.
"""

import logging

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.mcp_servers.models import ToolDefinition
from app.mcp_servers.registry import MCPServerRegistry
from app.models.integration import Integration

logger = logging.getLogger(__name__)

# Servers that are always available regardless of OAuth state.
# These read from local DB tables populated by native bridges (Apple
# Health, Health Connect) or return static payloads (DeepLink).
ALWAYS_ON_SERVERS: frozenset[str] = frozenset({
    "apple_health",
    "coach_skills",
    "deep_link",
    "health_connect",
    "memory",
    "notification",
    "user_progress",
    "user_wellbeing",
})

# Maps Integration.provider column values to MCP server names.
# Currently 1:1, but this mapping exists so they can diverge safely.
PROVIDER_TO_SERVER: dict[str, str] = {
    "strava": "strava",
    "fitbit": "fitbit",
    "oura": "oura",
    "withings": "withings",
    "polar": "polar",
}


class UserToolResolver:
    """Resolves the filtered set of MCP tools for a specific user.

    Queries the ``integrations`` table for the user's active providers,
    maps them to MCP server names, unions with always-on servers, and
    returns the filtered tool list from the registry.

    Fail-open: if the DB query fails, returns ALL tools (same as the
    previous behaviour before dynamic injection was implemented). This
    ensures a transient DB error never blocks the chat entirely.

    Attributes:
        _registry: The application-wide MCP server registry.
    """

    def __init__(self, registry: MCPServerRegistry) -> None:
        self._registry = registry

    async def resolve_tools(
        self,
        db: AsyncSession,
        user_id: str,
    ) -> list[ToolDefinition]:
        """Return the MCP tools this user should see.

        Args:
            db: An active async database session.
            user_id: The authenticated user's ID.

        Returns:
            Filtered list of ``ToolDefinition`` objects.
        """
        try:
            # Query only the provider column — we don't need tokens or metadata.
            # Single indexed query on ix_integrations_user_id.
            stmt = (
                select(Integration.provider)
                .where(
                    Integration.user_id == user_id,
                    Integration.is_active.is_(True),
                )
            )
            result = await db.execute(stmt)
            providers = result.scalars().all()

            # Map provider names → server names via allowlist.
            # Unknown providers (data bugs, future providers) are silently dropped.
            connected_servers: set[str] = set()
            for provider in providers:
                server_name = PROVIDER_TO_SERVER.get(provider)
                if server_name:
                    connected_servers.add(server_name)

            # Union with always-on servers
            server_names = ALWAYS_ON_SERVERS | connected_servers

            logger.debug(
                "User '%s': %d active integrations → servers: %s",
                user_id,
                len(providers),
                sorted(server_names),
            )

            return self._registry.get_tools_for_servers(server_names)

        except Exception:
            logger.exception(
                "Failed to resolve tools for user '%s' — falling back to all tools",
                user_id,
            )
            return self._registry.get_all_tools()
