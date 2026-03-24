"""
Zuralog Cloud Brain — Orchestrator (AI Brain).

The Orchestrator is the central "AI Brain" that manages the LLM
conversation loop with ReAct-style function-calling. It:

1. Injects the system prompt with user context.
2. Retrieves relevant memories for context.
3. Passes available MCP tools to the LLM.
4. Executes tool calls via MCPClient (max 5 turns).
5. Feeds tool results back to the LLM.
6. Returns the final assistant response.

Supports both non-streaming (process_message) and streaming
(process_message_stream) modes. The streaming mode yields partial
tokens to the caller so the WebSocket endpoint can forward them to
the client in real time.
"""

from __future__ import annotations

import json
import logging
from typing import TYPE_CHECKING, Any, AsyncGenerator

import sentry_sdk

from app.agent.context_manager.memory_store import MemoryStore
from app.agent.llm_client import LLMClient
from app.agent.mcp_client import MCPClient
from app.agent.prompts.system import build_system_prompt
from app.agent.response import AgentResponse
from app.services.usage_tracker import UsageTracker

if TYPE_CHECKING:
    from sqlalchemy.ext.asyncio import AsyncSession

logger = logging.getLogger(__name__)

MAX_TOOL_TURNS = 5
"""Maximum number of LLM round-trips for tool execution.

Prevents infinite loops if the model continuously requests tools
without generating a final text response.
"""

# Lightweight model used only for auto-generating conversation titles.
# A small, cheap model is preferred since this is a one-shot, low-stakes call.
_TITLE_MODEL = "openai/gpt-4.1-nano"


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
        # Dedicated lightweight client for title generation only.
        self._title_client = LLMClient(model=_TITLE_MODEL)

    def _build_tools_for_llm(
        self,
        mcp_tools: list | None = None,
    ) -> list[dict[str, Any]]:
        """Convert MCP ToolDefinitions to OpenAI function-calling format.

        Maps the internal ``ToolDefinition`` model to the format expected
        by the OpenAI API's tools parameter.

        Args:
            mcp_tools: Pre-resolved tool list. If None, fetches all tools
                from the MCP client (legacy behaviour, no db session).

        Returns:
            A list of tool dicts in OpenAI function-calling schema.
        """
        if mcp_tools is None:
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

    def _build_messages(
        self,
        system_prompt: str,
        message: str,
        conversation_history: list[dict[str, Any]] | None = None,
    ) -> list[dict[str, Any]]:
        """Build the initial messages list for an LLM request.

        Injects the system prompt, optional conversation history (for
        multi-turn context), and the current user message.

        Args:
            system_prompt: The fully-assembled system prompt string.
            message: The current user message text.
            conversation_history: Optional prior messages in
                ``[{"role": ..., "content": ...}]`` format. Injected
                between the system prompt and the new user message.

        Returns:
            A list of message dicts ready for the LLM API.
        """
        messages: list[dict[str, Any]] = [
            {"role": "system", "content": system_prompt},
        ]
        if conversation_history:
            messages.extend(conversation_history)
        messages.append({"role": "user", "content": message})
        return messages

    async def generate_title(self, first_user_message: str) -> str:
        """Generate a short, descriptive conversation title.

        Uses a lightweight model (gpt-4.1-nano) to produce a concise title
        from the user's first message. Falls back to a truncated version of
        the message if the LLM call fails.

        Args:
            first_user_message: The user's opening message in the conversation.

        Returns:
            A short title string (typically 3-8 words, no trailing period).
        """
        try:
            response = await self._title_client.chat(
                messages=[
                    {
                        "role": "system",
                        "content": (
                            "You are a title generator. Given the user's first message "
                            "in a health coaching conversation, produce a concise title "
                            "(3-7 words, title case, no trailing punctuation) that captures "
                            "the topic. Output ONLY the title text, nothing else."
                        ),
                    },
                    {"role": "user", "content": first_user_message[:300]},
                ],
                temperature=0.3,
            )
            title = (response.choices[0].message.content or "").strip().strip('"').strip("'")
            # Fallback if the model returns something odd.
            if not title or len(title) > 80:
                raise ValueError("title out of range")
            return title
        except Exception:
            logger.warning("Title generation failed; falling back to truncation")
            truncated = first_user_message[:60].strip()
            return truncated + ("…" if len(first_user_message) > 60 else "")

    async def process_message(
        self,
        user_id: str,
        message: str,
        user_context_suffix: str | None = None,
        persona: str = "balanced",
        proactivity: str = "medium",
        db: AsyncSession | None = None,
        conversation_history: list[dict[str, Any]] | None = None,
    ) -> AgentResponse:
        """Process a user message through the AI Brain.

        Implements the full ReAct-style conversation loop:
        1. Build system prompt with user context (persona + proactivity).
        2. Retrieve relevant memories and inject into prompt.
        3. Get available tools from MCP registry.
        4. Loop: LLM inference -> tool execution -> feed results back.
        5. Return a structured ``AgentResponse`` with the text and
           optional client-side action.

        Args:
            user_id: The authenticated user's ID.
            message: The user's chat message.
            user_context_suffix: Optional legacy context to append to prompt.
            persona: Coach persona: ``tough_love``, ``balanced``, or ``gentle``.
            proactivity: Proactivity level: ``low``, ``medium``, or ``high``.
            db: Optional async database session. When provided, tools are
                filtered to only those for integrations the user has
                connected. When None, all tools are injected (legacy).
            conversation_history: Prior messages for multi-turn context.
                Injected between the system prompt and the current user
                message. Each entry must have ``role`` and ``content`` keys.

        Returns:
            An ``AgentResponse`` containing the assistant's message and
            an optional ``client_action`` dict for the Edge Agent.
        """
        with sentry_sdk.start_transaction(op="ai.process_message", name="orchestrator.process_message") as txn:
            txn.set_tag("user_id", user_id)
            txn.set_tag("tool_injection_mode", "dynamic" if db is not None else "static")

            # 1. Retrieve relevant memories first (needed for prompt injection)
            context_entries_raw = await self.memory_store.query(user_id, query_text=message, limit=5)
            memory_texts = [e.get("text", "") for e in context_entries_raw if e.get("text")]

            # Build system prompt with persona, proactivity, and memory context
            system_prompt = build_system_prompt(
                persona=persona,
                proactivity=proactivity,
                memories=memory_texts if memory_texts else None,
                user_context_suffix=user_context_suffix,
            )

            # 2. Build initial messages (with optional history for multi-turn context)
            messages = self._build_messages(system_prompt, message, conversation_history)

            # 3. Get available tools — filtered per user if DB session provided
            if db is not None:
                mcp_tools = await self.mcp_client.get_tools_for_user(db, user_id)
            else:
                mcp_tools = self.mcp_client.get_all_tools()
            tools = self._build_tools_for_llm(mcp_tools)

            injection_mode = "dynamic" if db is not None else "static"
            logger.info(
                "Processing message for user '%s': %d memory items, %d tools (%s)",
                user_id,
                len(memory_texts),
                len(tools),
                injection_mode,
            )

            # 4. ReAct loop (max MAX_TOOL_TURNS turns)
            last_client_action: dict[str, Any] | None = None
            for turn in range(MAX_TOOL_TURNS):
                with sentry_sdk.start_span(op="ai.llm_call", description=f"LLM turn {turn + 1}") as llm_span:
                    llm_span.set_tag("turn", turn + 1)
                    try:
                        response = await self.llm_client.chat(
                            messages,
                            tools=tools if tools else None,
                        )
                    except Exception as llm_exc:
                        sentry_sdk.set_tag("ai.error_type", "llm_failure")
                        with sentry_sdk.push_scope() as scope:
                            scope.fingerprint = ["llm_failure", "{{ default }}"]
                            sentry_sdk.capture_exception(llm_exc)
                        raise

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

                if not response.choices:
                    logger.warning(
                        "Orchestrator: empty choices in LLM response for user '%s' on turn %d — stopping",
                        user_id,
                        turn + 1,
                    )
                    break

                assistant_message = response.choices[0].message

                # Check for tool calls
                if assistant_message.tool_calls:
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

                        with sentry_sdk.start_span(op="ai.tool_call", description=func_name) as tool_span:
                            tool_span.set_tag("tool.name", func_name)
                            tool_span.set_tag("turn", turn + 1)
                            try:
                                result = await self.mcp_client.execute_tool(func_name, arguments, user_id)
                            except Exception as tool_exc:
                                sentry_sdk.set_tag("ai.error_type", "tool_call_failure")
                                with sentry_sdk.push_scope() as scope:
                                    scope.fingerprint = ["tool_call_failure", func_name]
                                    sentry_sdk.capture_exception(tool_exc)
                                raise

                        if result.success and isinstance(result.data, dict) and "client_action" in result.data:
                            last_client_action = result.data

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

    async def process_message_stream(
        self,
        user_id: str,
        message: str,
        user_context_suffix: str | None = None,
        persona: str = "balanced",
        proactivity: str = "medium",
        response_length: str | None = None,
        db: AsyncSession | None = None,
        conversation_history: list[dict[str, Any]] | None = None,
    ) -> AsyncGenerator[dict[str, Any], None]:
        """Process a user message and stream the final response token-by-token.

        Identical to :meth:`process_message` for the ReAct tool-call turns
        (non-streaming, to support function-calling). Once the LLM produces a
        final text response with no tool calls, the response is streamed back
        as individual ``stream_token`` events followed by a ``stream_end`` event.

        Yields:
            - ``{"type": "tool_start", "tool_name": str}`` — tool execution begins.
            - ``{"type": "tool_end", "tool_name": str}`` — tool execution completes.
            - ``{"type": "stream_token", "content": str}`` — partial response token.
            - ``{"type": "stream_end", "content": str, "client_action": ...}`` — done.
            - ``{"type": "error", "content": str}`` — unrecoverable error.

        Args:
            user_id: The authenticated user's ID.
            message: The user's chat message.
            user_context_suffix: Optional legacy context suffix.
            persona: Coach persona key (``"balanced"``, etc.).
            proactivity: Proactivity level key (``"medium"``, etc.).
            db: Optional DB session for per-user tool filtering.
            conversation_history: Prior messages for multi-turn context.
        """
        with sentry_sdk.start_transaction(
            op="ai.process_message_stream", name="orchestrator.process_message_stream"
        ) as txn:
            txn.set_tag("user_id", user_id)

            try:
                # Build context (same as process_message)
                context_entries_raw = await self.memory_store.query(user_id, query_text=message, limit=5)
                memory_texts = [e.get("text", "") for e in context_entries_raw if e.get("text")]

                system_prompt = build_system_prompt(
                    persona=persona,
                    proactivity=proactivity,
                    response_length=response_length,
                    memories=memory_texts if memory_texts else None,
                    user_context_suffix=user_context_suffix,
                )

                messages = self._build_messages(system_prompt, message, conversation_history)

                if db is not None:
                    mcp_tools = await self.mcp_client.get_tools_for_user(db, user_id)
                else:
                    mcp_tools = self.mcp_client.get_all_tools()
                tools = self._build_tools_for_llm(mcp_tools)

                last_client_action: dict[str, Any] | None = None

                for turn in range(MAX_TOOL_TURNS):
                    # Check if we should stream this turn.
                    # We use non-streaming for all tool-call turns and only
                    # stream the final text response.
                    with sentry_sdk.start_span(op="ai.llm_call", description=f"Stream turn {turn + 1}") as llm_span:
                        llm_span.set_tag("turn", turn + 1)
                        response = await self.llm_client.chat(
                            messages,
                            tools=tools if tools else None,
                        )

                    if self.usage_tracker:
                        try:
                            await self.usage_tracker.track_from_response(user_id, response)
                        except Exception:
                            pass

                    if not response.choices:
                        break

                    assistant_message = response.choices[0].message

                    if assistant_message.tool_calls:
                        # Tool-call turn: emit progress events, execute tools.
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

                        for tool_call in assistant_message.tool_calls:
                            func_name = tool_call.function.name
                            try:
                                arguments = json.loads(tool_call.function.arguments)
                            except json.JSONDecodeError:
                                arguments = {}

                            yield {"type": "tool_start", "tool_name": func_name}

                            with sentry_sdk.start_span(op="ai.tool_call", description=func_name):
                                try:
                                    result = await self.mcp_client.execute_tool(func_name, arguments, user_id)
                                except Exception as tool_exc:
                                    sentry_sdk.capture_exception(tool_exc)
                                    yield {"type": "tool_end", "tool_name": func_name}
                                    yield {"type": "error", "content": f"Tool error: {tool_exc!s}"}
                                    return

                            yield {"type": "tool_end", "tool_name": func_name}

                            if result.success and isinstance(result.data, dict) and "client_action" in result.data:
                                last_client_action = result.data

                            result_content = (
                                json.dumps(result.data)
                                if result.success
                                else json.dumps({"error": result.error or "Tool execution failed"})
                            )

                            messages.append(
                                {
                                    "role": "tool",
                                    "tool_call_id": tool_call.id,
                                    "content": result_content,
                                }
                            )

                        continue  # Next ReAct turn

                    # No tool calls — this is the final response; stream it.
                    # Re-invoke the LLM in streaming mode with the accumulated messages.
                    with sentry_sdk.start_span(op="ai.stream_final", description="streaming final response"):
                        stream = await self.llm_client.stream_chat(
                            messages,
                            tools=None,  # No tools on final streaming turn
                        )

                        full_content = ""
                        async for chunk in stream:
                            delta = chunk.choices[0].delta if chunk.choices else None
                            if delta and delta.content:
                                full_content += delta.content
                                yield {"type": "stream_token", "content": delta.content}

                    yield {
                        "type": "stream_end",
                        "content": full_content or (assistant_message.content or ""),
                        "client_action": last_client_action,
                    }
                    return

                # Max turns exceeded
                yield {
                    "type": "stream_end",
                    "content": "I'm having trouble retrieving all the information right now. Please try again.",
                    "client_action": None,
                }

            except Exception as exc:
                sentry_sdk.capture_exception(exc)
                logger.exception("process_message_stream error for user '%s'", user_id)
                yield {"type": "error", "content": f"Processing error: {exc!s}"}
