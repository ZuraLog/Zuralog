"""
Life Logger Cloud Brain — Orchestrator (AI Brain).

The Orchestrator is the central "AI Brain" that manages the LLM
conversation loop with ReAct-style function-calling. It:

1. Injects the system prompt with user context.
2. Retrieves relevant memories for context.
3. Passes available MCP tools to the LLM.
4. Executes tool calls via MCPClient (max 5 turns).
5. Feeds tool results back to the LLM.
6. Returns the final assistant response.

This replaces the Phase 1.3 scaffold with a production-ready
implementation.
"""

import json
import logging
from typing import Any

from app.agent.context_manager.memory_store import MemoryStore
from app.agent.llm_client import LLMClient
from app.agent.mcp_client import MCPClient
from app.agent.prompts.system import build_system_prompt
from app.agent.response import AgentResponse
from app.services.usage_tracker import UsageTracker

logger = logging.getLogger(__name__)

MAX_TOOL_TURNS = 5
"""Maximum number of LLM round-trips for tool execution.

Prevents infinite loops if the model continuously requests tools
without generating a final text response.
"""


class Orchestrator:
    """LLM Agent that orchestrates MCP tool calls with ReAct-style loop.

    Manages the full conversation lifecycle: context injection,
    LLM inference, tool execution, and response generation.

    Attributes:
        mcp_client: Routes tool calls to MCP servers.
        memory_store: Stores and retrieves long-term user context.
        llm_client: Async LLM client for chat completions.
    """

    def __init__(
        self,
        mcp_client: MCPClient,
        memory_store: MemoryStore,
        llm_client: LLMClient | None = None,
        usage_tracker: UsageTracker | None = None,
    ) -> None:
        """Create a new Orchestrator.

        Args:
            mcp_client: The tool routing client.
            memory_store: The long-term memory backend.
            llm_client: The LLM client. If None, creates a default instance.
            usage_tracker: Optional tracker for recording per-request
                LLM token consumption to the database.
        """
        self.mcp_client = mcp_client
        self.memory_store = memory_store
        self.llm_client = llm_client or LLMClient()
        self.usage_tracker = usage_tracker

    def _build_tools_for_llm(self) -> list[dict[str, Any]]:
        """Convert MCP ToolDefinitions to OpenAI function-calling format.

        Maps the internal ``ToolDefinition`` model to the format expected
        by the OpenAI API's tools parameter.

        Returns:
            A list of tool dicts in OpenAI function-calling schema.
        """
        mcp_tools = self.mcp_client.get_all_tools()
        openai_tools = []

        for tool in mcp_tools:
            openai_tools.append(
                {
                    "type": "function",
                    "function": {
                        "name": tool.name,
                        "description": tool.description,
                        "parameters": tool.input_schema,
                    },
                }
            )

        return openai_tools

    async def process_message(
        self,
        user_id: str,
        message: str,
        user_context_suffix: str | None = None,
    ) -> AgentResponse:
        """Process a user message through the AI Brain.

        Implements the full ReAct-style conversation loop:
        1. Build system prompt with user context.
        2. Retrieve relevant memories.
        3. Get available tools from MCP registry.
        4. Loop: LLM inference -> tool execution -> feed results back.
        5. Return a structured ``AgentResponse`` with the text and
           optional client-side action.

        Args:
            user_id: The authenticated user's ID.
            message: The user's chat message.
            user_context_suffix: Optional user profile context to append
                to the system prompt.

        Returns:
            An ``AgentResponse`` containing the assistant's message and
            an optional ``client_action`` dict for the Edge Agent.
        """
        # 1. Build system prompt
        system_prompt = build_system_prompt(user_context_suffix)

        # 2. Retrieve relevant context from memory
        context_entries = await self.memory_store.query(user_id, query_text=message, limit=5)
        context_text = ""
        if context_entries:
            context_text = "\n\n## Relevant Context\n"
            for entry in context_entries:
                context_text += f"- {entry.get('text', '')}\n"

        # 3. Build initial messages
        messages: list[dict[str, Any]] = [
            {"role": "system", "content": system_prompt + context_text},
            {"role": "user", "content": message},
        ]

        # 4. Get available tools
        tools = self._build_tools_for_llm()

        logger.info(
            "Processing message for user '%s' with %d context items and %d tools",
            user_id,
            len(context_entries),
            len(tools),
        )

        # 5. ReAct loop (max MAX_TOOL_TURNS turns)
        last_client_action: dict[str, Any] | None = None
        for turn in range(MAX_TOOL_TURNS):
            response = await self.llm_client.chat(
                messages,
                tools=tools if tools else None,
            )

            # Track token usage for billing / analytics
            if self.usage_tracker:
                try:
                    await self.usage_tracker.track_from_response(user_id, response)
                except Exception:
                    logger.warning(
                        "Failed to track usage for user '%s' on turn %d",
                        user_id,
                        turn + 1,
                        exc_info=True,
                    )

            assistant_message = response.choices[0].message

            # Check for tool calls
            if assistant_message.tool_calls:
                # Add assistant message with tool calls to history
                messages.append(
                    {
                        "role": "assistant",
                        "content": assistant_message.content,
                        "tool_calls": [
                            {
                                "id": tc.id,
                                "type": "function",
                                "function": {
                                    "name": tc.function.name,
                                    "arguments": tc.function.arguments,
                                },
                            }
                            for tc in assistant_message.tool_calls
                        ],
                    }
                )

                # Execute each tool call
                for tool_call in assistant_message.tool_calls:
                    func_name = tool_call.function.name
                    try:
                        arguments = json.loads(tool_call.function.arguments)
                    except json.JSONDecodeError:
                        arguments = {}

                    logger.info(
                        "Turn %d: executing tool '%s' with args %s",
                        turn + 1,
                        func_name,
                        arguments,
                    )

                    # Execute via MCP
                    result = await self.mcp_client.execute_tool(func_name, arguments, user_id)

                    # Extract client_action if tool returned one (e.g. deep links)
                    if result.success and isinstance(result.data, dict) and "client_action" in result.data:
                        last_client_action = result.data

                    # Build tool result message
                    if result.success:
                        result_content = json.dumps(result.data)
                    else:
                        result_content = json.dumps({"error": result.error or "Tool execution failed"})

                    messages.append(
                        {
                            "role": "tool",
                            "tool_call_id": tool_call.id,
                            "content": result_content,
                        }
                    )

                # Continue loop — LLM will process tool results
                continue

            # No tool calls — return final text response
            final_content = assistant_message.content or ""
            logger.info(
                "Final response for user '%s' after %d turn(s)",
                user_id,
                turn + 1,
            )
            return AgentResponse(
                message=final_content,
                client_action=last_client_action,
            )

        # Safety: max turns exceeded
        logger.warning(
            "Max tool turns (%d) exceeded for user '%s'",
            MAX_TOOL_TURNS,
            user_id,
        )
        return AgentResponse(
            message="I'm having trouble retrieving all the information right now. "
            "Please try again or rephrase your question.",
        )
