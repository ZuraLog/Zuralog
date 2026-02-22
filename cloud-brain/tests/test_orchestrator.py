"""
Life Logger Cloud Brain — Orchestrator Tests.

Tests the ReAct-style tool execution loop in the Orchestrator.
All LLM and MCP calls are mocked.
"""

import json
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.agent.orchestrator import Orchestrator


@pytest.fixture
def mock_mcp_client():
    """Create a mocked MCPClient."""
    client = MagicMock()
    client.get_all_tools.return_value = []
    client.execute_tool = AsyncMock()
    return client


@pytest.fixture
def mock_memory_store():
    """Create a mocked MemoryStore."""
    store = MagicMock()
    store.query = AsyncMock(return_value=[])
    return store


@pytest.fixture
def mock_llm_client():
    """Create a mocked LLMClient."""
    client = MagicMock()
    client.chat = AsyncMock()
    return client


@pytest.fixture
def orchestrator(mock_mcp_client, mock_memory_store, mock_llm_client):
    """Create an Orchestrator with all mocked dependencies."""
    return Orchestrator(
        mcp_client=mock_mcp_client,
        memory_store=mock_memory_store,
        llm_client=mock_llm_client,
    )


@pytest.mark.asyncio
async def test_simple_text_response(orchestrator, mock_llm_client):
    """Orchestrator returns LLM text when no tool calls are made."""
    mock_message = MagicMock()
    mock_message.content = "You walked 10,000 steps today. Great job!"
    mock_message.tool_calls = None

    mock_response = MagicMock()
    mock_response.choices = [MagicMock(message=mock_message)]
    mock_response.usage.prompt_tokens = 100
    mock_response.usage.completion_tokens = 30

    mock_llm_client.chat.return_value = mock_response

    result = await orchestrator.process_message("user-1", "How are my steps?")
    assert result == "You walked 10,000 steps today. Great job!"


@pytest.mark.asyncio
async def test_single_tool_call(orchestrator, mock_mcp_client, mock_llm_client):
    """Orchestrator executes a single tool call and returns final response."""
    # First LLM response: tool call
    tool_call = MagicMock()
    tool_call.id = "call_123"
    tool_call.function.name = "read_metrics"
    tool_call.function.arguments = json.dumps({"data_type": "steps"})

    msg_with_tool = MagicMock()
    msg_with_tool.content = None
    msg_with_tool.tool_calls = [tool_call]

    response_1 = MagicMock()
    response_1.choices = [MagicMock(message=msg_with_tool)]
    response_1.usage.prompt_tokens = 100
    response_1.usage.completion_tokens = 20

    # Second LLM response: final text
    msg_final = MagicMock()
    msg_final.content = "You hit 12,400 steps today!"
    msg_final.tool_calls = None

    response_2 = MagicMock()
    response_2.choices = [MagicMock(message=msg_final)]
    response_2.usage.prompt_tokens = 200
    response_2.usage.completion_tokens = 25

    mock_llm_client.chat.side_effect = [response_1, response_2]

    # MCP tool result
    tool_result = MagicMock()
    tool_result.success = True
    tool_result.data = {"steps": 12400}
    tool_result.error = None
    mock_mcp_client.execute_tool.return_value = tool_result

    result = await orchestrator.process_message("user-1", "How many steps?")
    assert result == "You hit 12,400 steps today!"
    mock_mcp_client.execute_tool.assert_called_once()


@pytest.mark.asyncio
async def test_max_turns_safety(orchestrator, mock_llm_client):
    """Orchestrator stops after max turns to prevent infinite loops."""
    tool_call = MagicMock()
    tool_call.id = "call_loop"
    tool_call.function.name = "read_metrics"
    tool_call.function.arguments = json.dumps({})

    msg_loop = MagicMock()
    msg_loop.content = None
    msg_loop.tool_calls = [tool_call]

    response_loop = MagicMock()
    response_loop.choices = [MagicMock(message=msg_loop)]
    response_loop.usage.prompt_tokens = 100
    response_loop.usage.completion_tokens = 10

    mock_llm_client.chat.return_value = response_loop

    orchestrator.mcp_client.execute_tool = AsyncMock(return_value=MagicMock(success=True, data={}, error=None))

    result = await orchestrator.process_message("user-1", "Loop test")
    assert "trouble" in result.lower() or "try again" in result.lower()
    assert mock_llm_client.chat.call_count == 5


@pytest.mark.asyncio
async def test_tool_error_fed_back(orchestrator, mock_mcp_client, mock_llm_client):
    """When a tool fails, the error is fed back to the LLM."""
    tool_call = MagicMock()
    tool_call.id = "call_err"
    tool_call.function.name = "bad_tool"
    tool_call.function.arguments = json.dumps({})

    msg_tool = MagicMock()
    msg_tool.content = None
    msg_tool.tool_calls = [tool_call]

    response_1 = MagicMock()
    response_1.choices = [MagicMock(message=msg_tool)]
    response_1.usage.prompt_tokens = 100
    response_1.usage.completion_tokens = 10

    msg_final = MagicMock()
    msg_final.content = "Sorry, I couldn't fetch that data."
    msg_final.tool_calls = None

    response_2 = MagicMock()
    response_2.choices = [MagicMock(message=msg_final)]
    response_2.usage.prompt_tokens = 200
    response_2.usage.completion_tokens = 20

    mock_llm_client.chat.side_effect = [response_1, response_2]

    mock_mcp_client.execute_tool.return_value = MagicMock(success=False, data=None, error="Tool not found")

    result = await orchestrator.process_message("user-1", "Bad request")
    assert "Sorry" in result or "couldn't" in result.lower()
