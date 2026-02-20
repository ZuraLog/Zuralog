"""Google Health Connect MCP Server.

Exposes Health Connect capabilities as semantic tools for the LLM agent.
In the MVP, tool execution queues a request for the Edge Agent
(via future FCM/REST push). The tool schema defines what the AI
*can* do with Android health data.

Registered in main.py lifespan via app.state.mcp_registry.
"""

from app.mcp_servers.base_server import BaseMCPServer
from app.mcp_servers.models import Resource, ToolDefinition, ToolResult


class HealthConnectServer(BaseMCPServer):
    """MCP server for Google Health Connect data via Edge Agent.

    Provides read and write tools for health metrics:
    - Read: steps, calories, workouts, sleep, weight
    - Write: nutrition, workout, weight

    Mirrors ``AppleHealthServer`` to give the AI symmetric
    capabilities across iOS and Android devices. In later phases,
    ``execute_tool`` will trigger a push notification to the
    Android Edge Agent.
    """

    @property
    def name(self) -> str:
        """Unique server identifier used for registry lookup."""
        return "health_connect"

    @property
    def description(self) -> str:
        """Human-readable description for LLM system prompts."""
        return (
            "Read and write health data on Android via Google Health Connect. "
            "Supports steps, calories, workouts, sleep analysis, and body weight."
        )

    def get_tools(self) -> list[ToolDefinition]:
        """Return tool schemas the LLM agent can call.

        Returns two tools:
        - health_connect_read_metrics: Read health data by type and date range.
        - health_connect_write_entry: Write health data (nutrition, workout, weight).
        """
        return [
            ToolDefinition(
                name="health_connect_read_metrics",
                description=(
                    "Read health metrics from Google Health Connect. "
                    "Supports: steps, calories, workouts, sleep, weight."
                ),
                input_schema={
                    "type": "object",
                    "properties": {
                        "data_type": {
                            "type": "string",
                            "enum": [
                                "steps",
                                "calories",
                                "workouts",
                                "sleep",
                                "weight",
                            ],
                            "description": "The type of health metric to read.",
                        },
                        "start_date": {
                            "type": "string",
                            "description": "Start date in ISO 8601 format (e.g., 2026-02-20).",
                        },
                        "end_date": {
                            "type": "string",
                            "description": "End date in ISO 8601 format (e.g., 2026-02-20).",
                        },
                    },
                    "required": ["data_type", "start_date", "end_date"],
                },
            ),
            ToolDefinition(
                name="health_connect_write_entry",
                description=(
                    "Write health data to Google Health Connect. "
                    "Supports: nutrition (calories), workout, weight."
                ),
                input_schema={
                    "type": "object",
                    "properties": {
                        "data_type": {
                            "type": "string",
                            "enum": ["nutrition", "workout", "weight"],
                            "description": "The type of health entry to write.",
                        },
                        "value": {
                            "type": "number",
                            "description": (
                                "The value to write. For nutrition: calories (kcal). "
                                "For weight: kilograms. For workout: energy burned (kcal)."
                            ),
                        },
                        "date": {
                            "type": "string",
                            "description": "Date/time in ISO 8601 format.",
                        },
                        "metadata": {
                            "type": "object",
                            "description": (
                                'Additional data. For workouts: {"activity_type": "running", "duration_seconds": 1800}'
                            ),
                        },
                    },
                    "required": ["data_type", "value", "date"],
                },
            ),
        ]

    async def execute_tool(self, tool_name: str, params: dict, user_id: str) -> ToolResult:
        """Execute a tool by queuing a command for the Edge Agent.

        In the MVP, this returns a 'pending_device_sync' status.
        In later phases (1.10+), this will trigger an FCM push
        to the user's Android device, which will execute the
        Health Connect operation and confirm via REST callback.

        Parameters:
            tool_name: The tool to execute.
            params: Tool-specific parameters.
            user_id: The authenticated user's ID.

        Returns:
            ToolResult with success status and queued message.
        """
        if tool_name == "health_connect_read_metrics":
            required = ("data_type", "start_date", "end_date")
            missing = [k for k in required if k not in params]
            if missing:
                return ToolResult(
                    success=False,
                    error=f"Missing required parameters: {', '.join(missing)}",
                )
            return ToolResult(
                success=True,
                data={
                    "status": "pending_device_sync",
                    "message": f"Read request queued for {params.get('data_type', 'unknown')} data",
                    "params": params,
                },
            )

        if tool_name == "health_connect_write_entry":
            required = ("data_type", "value", "date")
            missing = [k for k in required if k not in params]
            if missing:
                return ToolResult(
                    success=False,
                    error=f"Missing required parameters: {', '.join(missing)}",
                )
            return ToolResult(
                success=True,
                data={
                    "status": "pending_device_sync",
                    "message": f"Write request queued for {params.get('data_type', 'unknown')} entry",
                    "params": params,
                },
            )

        return ToolResult(
            success=False,
            error=f"Unknown tool: {tool_name}",
        )

    async def get_resources(self, user_id: str) -> list[Resource]:
        """Return available data resources.

        Currently empty -- resources will be populated when the Edge
        Agent reports available data types after authorization.
        """
        return []
