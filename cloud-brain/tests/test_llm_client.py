"""
Life Logger Cloud Brain — LLM Client Tests.

Unit tests for the LLMClient wrapper around AsyncOpenAI.
All tests mock the OpenAI SDK to avoid real API calls.
"""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.agent.llm_client import LLMClient


@pytest.fixture
def llm_client():
    """Create an LLMClient with mocked settings."""
    with patch("app.agent.llm_client.settings") as mock_settings:
        mock_settings.openrouter_api_key = "test-key"
        mock_settings.openrouter_referer = "https://test.app"
        mock_settings.openrouter_title = "Test App"
        mock_settings.openrouter_model = "moonshotai/kimi-k2.5"
        client = LLMClient()
        yield client


@pytest.mark.asyncio
async def test_chat_returns_message(llm_client):
    """chat() should return the full ChatCompletion response."""
    mock_response = MagicMock()
    mock_choice = MagicMock()
    mock_choice.message.content = "Hello, I'm your coach!"
    mock_choice.message.tool_calls = None
    mock_response.choices = [mock_choice]
    mock_response.usage.prompt_tokens = 50
    mock_response.usage.completion_tokens = 20

    llm_client._client.chat.completions.create = AsyncMock(return_value=mock_response)

    messages = [{"role": "user", "content": "Hi"}]
    response = await llm_client.chat(messages)

    assert response.choices[0].message.content == "Hello, I'm your coach!"
    llm_client._client.chat.completions.create.assert_called_once()


@pytest.mark.asyncio
async def test_chat_passes_tools(llm_client):
    """chat() should forward tool definitions to the API."""
    mock_response = MagicMock()
    mock_choice = MagicMock()
    mock_choice.message.content = "Let me check your steps."
    mock_choice.message.tool_calls = None
    mock_response.choices = [mock_choice]
    mock_response.usage.prompt_tokens = 100
    mock_response.usage.completion_tokens = 30

    llm_client._client.chat.completions.create = AsyncMock(return_value=mock_response)

    tools = [
        {
            "type": "function",
            "function": {
                "name": "read_steps",
                "description": "Read step count",
                "parameters": {"type": "object", "properties": {}},
            },
        }
    ]
    messages = [{"role": "user", "content": "How many steps?"}]
    await llm_client.chat(messages, tools=tools)

    call_kwargs = llm_client._client.chat.completions.create.call_args[1]
    assert call_kwargs["tools"] == tools


@pytest.mark.asyncio
async def test_chat_without_tools(llm_client):
    """chat() without tools should not pass tools parameter."""
    mock_response = MagicMock()
    mock_choice = MagicMock()
    mock_choice.message.content = "Sure!"
    mock_choice.message.tool_calls = None
    mock_response.choices = [mock_choice]
    mock_response.usage.prompt_tokens = 20
    mock_response.usage.completion_tokens = 5

    llm_client._client.chat.completions.create = AsyncMock(return_value=mock_response)

    messages = [{"role": "user", "content": "Hello"}]
    await llm_client.chat(messages)

    call_kwargs = llm_client._client.chat.completions.create.call_args[1]
    assert "tools" not in call_kwargs


def test_default_model(llm_client):
    """LLMClient should use the configured default model."""
    assert llm_client.model == "moonshotai/kimi-k2.5"


def test_custom_model():
    """LLMClient should accept a custom model override."""
    with patch("app.agent.llm_client.settings") as mock_settings:
        mock_settings.openrouter_api_key = "test-key"
        mock_settings.openrouter_referer = "https://test.app"
        mock_settings.openrouter_title = "Test App"
        mock_settings.openrouter_model = "moonshotai/kimi-k2.5"
        client = LLMClient(model="google/gemini-flash-1.5")
        assert client.model == "google/gemini-flash-1.5"
