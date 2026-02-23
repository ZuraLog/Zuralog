"""
Zuralog Cloud Brain — Strava MCP Server (Phase 1.6).

Wraps the Strava API so the LLM agent can read recent activities and
create manual entries via standard MCP tool calls. Token storage is
in-memory for the MVP phase; Phase 1.7 will migrate to database
persistence.
"""

import httpx

from app.mcp_servers.base_server import BaseMCPServer
from app.mcp_servers.models import Resource, ToolDefinition, ToolResult


class StravaServer(BaseMCPServer):
    """MCP server for Strava activity reading and writing.

    Exposes two tools to the LLM agent:
    - ``strava_get_activities``: Fetch recent runs/rides from Strava.
    - ``strava_create_activity``: Create a manual activity entry.

    Access tokens are stored in ``_tokens`` (keyed by ``user_id``) and
    injected via ``store_token()`` by the OAuth exchange endpoint once
    the user completes the Strava login flow.
    """

    def __init__(self) -> None:
        """Initialise the server with an empty in-memory token store."""
        self._tokens: dict[str, str] = {}

    # ------------------------------------------------------------------
    # BaseMCPServer properties
    # ------------------------------------------------------------------

    @property
    def name(self) -> str:
        """Unique identifier used by the MCP registry.

        Returns:
            The string ``"strava"``.
        """
        return "strava"

    @property
    def description(self) -> str:
        """Human-readable capability summary surfaced to the LLM.

        Returns:
            A description of Strava read/write capabilities.
        """
        return (
            "Read and write Strava activities (Runs, Rides, Swims, Workouts). "
            "Use this to fetch recent training history or log a manual effort."
        )

    # ------------------------------------------------------------------
    # Tool definitions
    # ------------------------------------------------------------------

    def get_tools(self) -> list[ToolDefinition]:
        """Return the two Strava tools the LLM may invoke.

        Returns:
            A list containing ``strava_get_activities`` and
            ``strava_create_activity`` tool definitions.
        """
        return [
            ToolDefinition(
                name="strava_get_activities",
                description="Fetch the most recent activities from the user's Strava account.",
                input_schema={
                    "type": "object",
                    "properties": {
                        "limit": {
                            "type": "integer",
                            "description": "Maximum number of activities to return (default 10).",
                            "default": 10,
                        },
                    },
                    "required": [],
                },
            ),
            ToolDefinition(
                name="strava_create_activity",
                description="Create a manual activity entry in the user's Strava account.",
                input_schema={
                    "type": "object",
                    "properties": {
                        "name": {
                            "type": "string",
                            "description": "Display name for the activity (e.g. 'Morning Run').",
                        },
                        "type": {
                            "type": "string",
                            "enum": ["Run", "Ride", "Swim", "Workout", "WeightTraining"],
                            "description": "Strava activity type.",
                        },
                        "elapsed_time": {
                            "type": "integer",
                            "description": "Total duration in seconds.",
                        },
                        "start_date_local": {
                            "type": "string",
                            "description": "Activity start time in ISO 8601 format (e.g. '2026-02-21T07:00:00Z').",
                        },
                        "distance": {
                            "type": "number",
                            "description": "Distance in metres (optional).",
                        },
                    },
                    "required": ["name", "type", "elapsed_time", "start_date_local"],
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
        """Execute a Strava tool on behalf of the given user.

        Looks up the user's access token from the in-memory store.
        MVP: returns mock data so the harness can be verified without
        real Strava credentials. Activate the live ``httpx`` calls by
        uncommenting the blocks below once credentials are available.

        Args:
            tool_name: One of ``strava_get_activities`` or
                ``strava_create_activity``.
            params: Parameter dict matching the tool's ``input_schema``.
            user_id: Authenticated user whose Strava token to use.

        Returns:
            A ``ToolResult`` with mock or live Strava data.
        """
        token = self._tokens.get(user_id)

        if tool_name == "strava_get_activities":
            return await self._get_activities(token, params)
        if tool_name == "strava_create_activity":
            return await self._create_activity(token, params)

        return ToolResult(success=False, error=f"Unknown tool: {tool_name}")

    async def _get_activities(
        self,
        token: str | None,
        params: dict,
    ) -> ToolResult:
        """Fetch recent activities from Strava.

        Uses live API if a token is available; returns mock data otherwise.

        Args:
            token: Strava Bearer access token, or ``None`` for mock mode.
            params: Accepts optional ``limit`` key (default 10).

        Returns:
            ``ToolResult`` containing a list of activity dicts.
        """
        limit = int(params.get("limit", 10))

        if token:
            # --- Live Strava API call (activated once token is available) ---
            try:
                async with httpx.AsyncClient(timeout=15.0) as client:
                    resp = await client.get(
                        "https://www.strava.com/api/v3/athlete/activities",
                        headers={"Authorization": f"Bearer {token}"},
                        params={"per_page": limit},
                    )
                if resp.status_code == 200:
                    return ToolResult(success=True, data=resp.json())
                return ToolResult(
                    success=False,
                    error=f"Strava API error {resp.status_code}: {resp.text}",
                )
            except httpx.RequestError as exc:
                return ToolResult(success=False, error=f"Network error: {exc}")

        # --- Mock data (no token yet — harness / unit-test mode) ---
        mock_activities = [
            {
                "id": 12345,
                "name": "Morning Run",
                "type": "Run",
                "distance": 5000,
                "elapsed_time": 1800,
                "start_date_local": "2026-02-21T07:00:00Z",
            },
            {
                "id": 67890,
                "name": "Lunch Walk",
                "type": "Walk",
                "distance": 1500,
                "elapsed_time": 900,
                "start_date_local": "2026-02-20T12:30:00Z",
            },
        ]
        return ToolResult(success=True, data=mock_activities[:limit])

    async def _create_activity(
        self,
        token: str | None,
        params: dict,
    ) -> ToolResult:
        """Create a manual activity entry in Strava.

        Uses live API if a token is available; returns a mock response otherwise.

        Args:
            token: Strava Bearer access token, or ``None`` for mock mode.
            params: Must contain ``name``, ``type``, ``elapsed_time``,
                ``start_date_local``. Optionally ``distance``.

        Returns:
            ``ToolResult`` containing the created activity dict.
        """
        if token:
            payload = {
                "name": params["name"],
                "type": params["type"],
                "elapsed_time": params["elapsed_time"],
                "start_date_local": params["start_date_local"],
            }
            if "distance" in params:
                payload["distance"] = params["distance"]

            try:
                async with httpx.AsyncClient(timeout=15.0) as client:
                    resp = await client.post(
                        "https://www.strava.com/api/v3/activities",
                        headers={"Authorization": f"Bearer {token}"},
                        json=payload,
                    )
                if resp.status_code == 201:
                    return ToolResult(success=True, data=resp.json())
                return ToolResult(
                    success=False,
                    error=f"Strava API error {resp.status_code}: {resp.text}",
                )
            except httpx.RequestError as exc:
                return ToolResult(success=False, error=f"Network error: {exc}")

        # --- Mock response ---
        return ToolResult(
            success=True,
            data={"id": 99999, "name": params.get("name", ""), "mock": True},
        )

    # ------------------------------------------------------------------
    # Resources
    # ------------------------------------------------------------------

    async def get_resources(self, user_id: str) -> list[Resource]:
        """Return a description of resources available for the LLM's context.

        Args:
            user_id: The authenticated user (unused in MVP — single resource set).

        Returns:
            A list with one ``Resource`` describing recent Strava activities.
        """
        return [
            Resource(
                uri="strava://activities/recent",
                name="Recent Strava Activities",
                description="List of the user's most recent runs, rides, and workouts from Strava.",
            )
        ]

    # ------------------------------------------------------------------
    # Health check
    # ------------------------------------------------------------------

    async def health_check(self) -> bool:
        """Verify Strava API connectivity using the first available token.

        Falls back to ``True`` when no tokens are stored (no users have
        connected Strava yet) to avoid marking the server as unhealthy
        at startup.

        Returns:
            ``True`` if the Strava API responds 200, ``False`` on error.
        """
        if not self._tokens:
            return True

        token = next(iter(self._tokens.values()))
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.get(
                    "https://www.strava.com/api/v3/athlete",
                    headers={"Authorization": f"Bearer {token}"},
                )
            return resp.status_code == 200
        except httpx.RequestError:
            return False

    # ------------------------------------------------------------------
    # Token management
    # ------------------------------------------------------------------

    def store_token(self, user_id: str, access_token: str) -> None:
        """Persist a Strava access token for a user (in-memory, MVP only).

        Called by the OAuth exchange endpoint after a successful token swap.
        Phase 1.7 will replace this with database-backed storage.

        Args:
            user_id: The user whose token is being stored.
            access_token: The Strava Bearer access token.
        """
        self._tokens[user_id] = access_token
