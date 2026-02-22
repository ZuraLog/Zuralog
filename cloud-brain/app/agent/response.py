"""
Life Logger Cloud Brain — Agent Response Model.

Defines the structured response returned by the Orchestrator.
Replaces the previous plain ``str`` return with a Pydantic model
that can carry optional client-side actions (deep links, navigation).
"""

from typing import Any

from pydantic import BaseModel, Field


class AgentResponse(BaseModel):
    """Structured response from the AI Orchestrator.

    Contains the assistant's text message and an optional
    ``client_action`` dict that the Edge Agent should execute.

    Attributes:
        message: The assistant's text response to display in chat.
        client_action: Optional action payload for the client.
            When present, the Edge Agent should interpret this
            (e.g. open a deep link, navigate to a screen).
            Structure: ``{"client_action": "open_url", "url": "...", ...}``
    """

    message: str = Field(
        ...,
        min_length=0,
        description="The assistant's text response.",
    )
    client_action: dict[str, Any] | None = Field(
        default=None,
        description="Optional client-side action payload.",
    )
