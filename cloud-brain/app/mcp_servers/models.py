"""
Zuralog Cloud Brain — MCP Server Pydantic Models.

Defines the shared data contracts used across all MCP servers.
These models enforce type safety at the boundary between the
orchestration layer and individual integration servers.
"""

from typing import Any

from pydantic import BaseModel, Field


class ToolDefinition(BaseModel):
    """Schema describing a single tool that an MCP server exposes.

    This model is passed to the LLM so it knows what functions are
    available and how to call them. The ``input_schema`` field must
    conform to JSON Schema (draft-07+).

    Attributes:
        name: Machine-readable identifier (e.g. ``get_activities``).
        description: Human-readable explanation for the LLM prompt.
        input_schema: JSON Schema object defining accepted parameters.
    """

    name: str = Field(..., min_length=1, description="Unique tool identifier.")
    description: str = Field(..., min_length=1, description="What the tool does (shown to the LLM).")
    input_schema: dict[str, Any] = Field(
        default_factory=lambda: {"type": "object", "properties": {}, "required": []},
        description="JSON Schema for tool parameters.",
    )


class ToolResult(BaseModel):
    """Standardised return value from any ``execute_tool`` call.

    Every MCP server must return this model so the orchestrator can
    handle success/failure uniformly without per-server logic.

    Attributes:
        success: Whether the tool call completed without error.
        data: Arbitrary payload (list, dict, scalar, etc.).
        error: Human-readable error message when ``success`` is False.
    """

    success: bool
    data: Any = None
    error: str | None = None


class Resource(BaseModel):
    """Describes a data resource that an MCP server can expose.

    Resources represent read-only data the AI can reference in context
    (e.g. "recent Strava activities", "latest sleep data").

    Attributes:
        uri: Unique resource identifier (e.g. ``strava://activities/recent``).
        name: Short display name.
        description: Explanation of what the resource contains.
        mime_type: Content type hint (defaults to ``application/json``).
    """

    uri: str
    name: str
    description: str = ""
    mime_type: str = "application/json"
