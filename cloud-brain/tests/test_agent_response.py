"""
Tests for the AgentResponse model.

Validates serialization, default values, and client_action handling
for the structured response returned by the Orchestrator.
"""

from app.agent.response import AgentResponse


class TestAgentResponse:
    """Test suite for AgentResponse Pydantic model."""

    def test_text_only_response(self) -> None:
        """AgentResponse with only a message has None client_action."""
        resp = AgentResponse(message="You walked 10k steps!")
        assert resp.message == "You walked 10k steps!"
        assert resp.client_action is None

    def test_response_with_client_action(self) -> None:
        """AgentResponse carries a client_action when provided."""
        action = {"client_action": "open_url", "url": "strava://record"}
        resp = AgentResponse(message="Opening Strava...", client_action=action)
        assert resp.client_action == action
        assert resp.client_action["url"] == "strava://record"

    def test_serialization_excludes_none(self) -> None:
        """model_dump(exclude_none=True) omits absent client_action."""
        resp = AgentResponse(message="Hello")
        data = resp.model_dump(exclude_none=True)
        assert "client_action" not in data

    def test_serialization_includes_client_action(self) -> None:
        """model_dump includes client_action when present."""
        action = {"client_action": "open_url", "url": "calai://camera"}
        resp = AgentResponse(message="Opening CalAI...", client_action=action)
        data = resp.model_dump()
        assert data["client_action"]["url"] == "calai://camera"
