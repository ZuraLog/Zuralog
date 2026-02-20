"""
Life Logger Cloud Brain — Orchestrator Scaffold.

The Orchestrator is the "AI Brain" that will eventually hold the LLM
conversation loop, function-calling logic, and context injection.
This module is a scaffold — Phase 1.8 (AI Brain) will add the full
LLM integration.
"""

import logging

from app.agent.context_manager.memory_store import MemoryStore
from app.agent.mcp_client import MCPClient

logger = logging.getLogger(__name__)


class Orchestrator:
    """LLM Agent that orchestrates MCP tool calls.

    Currently a skeleton that demonstrates the dependency wiring
    between the MCP client and the memory store. The actual LLM
    conversation loop (OpenAI / Kimi function-calling) will be
    implemented in Phase 1.8.

    Attributes:
        mcp_client: Routes tool calls to MCP servers.
        memory_store: Stores and retrieves long-term user context.
    """

    def __init__(
        self,
        mcp_client: MCPClient,
        memory_store: MemoryStore,
    ) -> None:
        """Create a new Orchestrator.

        Args:
            mcp_client: The tool routing client.
            memory_store: The long-term memory backend.
        """
        self.mcp_client = mcp_client
        self.memory_store = memory_store

    async def process_message(self, user_id: str, message: str) -> str:
        """Process a user message and return an AI response.

        This is a simplified scaffold. The full implementation in
        Phase 1.8 will:
        1. Retrieve relevant context from the memory store.
        2. Build a system prompt with available tools.
        3. Call the LLM with function-calling enabled.
        4. Execute any tool calls via the MCP client.
        5. Return the final AI response.

        Args:
            user_id: The authenticated user.
            message: The user's chat message.

        Returns:
            A placeholder response string.
        """
        # 1. Get user context (scaffold — will use real queries in Phase 1.8)
        context = await self.memory_store.query(user_id, query_text=message, limit=5)
        logger.info(
            "Processing message for user '%s' with %d context items",
            user_id,
            len(context),
        )

        # 2. Get available tools for the system prompt
        tools = self.mcp_client.get_all_tools()
        logger.info("Available tools: %d", len(tools))

        # 3. Placeholder — Phase 1.8 adds LLM function-calling here
        return (
            f"[Orchestrator scaffold] Received: '{message}'. "
            f"Context items: {len(context)}, Available tools: {len(tools)}."
        )
