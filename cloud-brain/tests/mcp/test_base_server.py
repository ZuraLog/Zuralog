"""
Zuralog Cloud Brain — MCP Base Server Tests.

Verifies that the ``BaseMCPServer`` ABC can be properly implemented
and that incomplete implementations are rejected at instantiation time.
"""

import pytest

from app.mcp_servers.base_server import BaseMCPServer
from app.mcp_servers.models import Resource, ToolDefinition, ToolResult

# ---------------------------------------------------------------------------
# Mock Implementation
# ---------------------------------------------------------------------------


class MockServer(BaseMCPServer):
    """A valid implementation of BaseMCPServer for testing."""

    @property
    def name(self) -> str:
        return "mock_server"

    @property
    def description(self) -> str:
        return "A mock MCP server used in tests."

    def get_tools(self) -> list[ToolDefinition]:
        return [
            ToolDefinition(
                name="mock_tool",
                description="A mock tool that echoes input.",
                input_schema={
                    "type": "object",
                    "properties": {"input": {"type": "string"}},
                    "required": ["input"],
                },
            ),
            ToolDefinition(
                name="mock_tool_2",
                description="A second mock tool.",
                input_schema={
                    "type": "object",
                    "properties": {},
                    "required": [],
                },
            ),
        ]

    async def execute_tool(
        self,
        tool_name: str,
        params: dict,
        user_id: str,
    ) -> ToolResult:
        if tool_name == "mock_tool":
            return ToolResult(
                success=True,
                data=f"Mock executed with: {params}",
            )
        return ToolResult(success=False, error=f"Unknown tool: {tool_name}")

    async def get_resources(self, user_id: str) -> list[Resource]:
        return [
            Resource(
                uri="mock://test/resource",
                name="Test Resource",
                description="A mock resource for testing.",
            )
        ]


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


class TestBaseMCPServerContract:
    """Tests that the BaseMCPServer ABC enforces its contract."""

    def test_name_property(self) -> None:
        """Server name is accessible as a string."""
        server = MockServer()
        assert server.name == "mock_server"

    def test_description_property(self) -> None:
        """Server description is accessible as a string."""
        server = MockServer()
        assert server.description == "A mock MCP server used in tests."

    def test_get_tools_returns_tool_definitions(self) -> None:
        """get_tools returns a list of ToolDefinition models."""
        server = MockServer()
        tools = server.get_tools()
        assert len(tools) == 2
        assert all(isinstance(t, ToolDefinition) for t in tools)
        assert tools[0].name == "mock_tool"
        assert tools[1].name == "mock_tool_2"

    @pytest.mark.asyncio
    async def test_execute_tool_success(self) -> None:
        """execute_tool returns a ToolResult on success."""
        server = MockServer()
        result = await server.execute_tool("mock_tool", {"input": "hello"}, "user_1")
        assert isinstance(result, ToolResult)
        assert result.success is True
        assert "hello" in str(result.data)

    @pytest.mark.asyncio
    async def test_execute_tool_unknown(self) -> None:
        """execute_tool returns error ToolResult for unknown tools."""
        server = MockServer()
        result = await server.execute_tool("nonexistent", {}, "user_1")
        assert result.success is False
        assert result.error is not None

    @pytest.mark.asyncio
    async def test_get_resources(self) -> None:
        """get_resources returns a list of Resource models."""
        server = MockServer()
        resources = await server.get_resources("user_1")
        assert len(resources) == 1
        assert isinstance(resources[0], Resource)
        assert resources[0].uri == "mock://test/resource"

    @pytest.mark.asyncio
    async def test_health_check_default(self) -> None:
        """Default health_check returns True."""
        server = MockServer()
        assert await server.health_check() is True


class TestBaseMCPServerEnforcement:
    """Tests that incomplete implementations are rejected."""

    def test_incomplete_implementation_raises_type_error(self) -> None:
        """Instantiating an ABC without all methods raises TypeError."""

        class IncompleteServer(BaseMCPServer):
            @property
            def name(self) -> str:
                return "incomplete"

            # Missing: description, get_tools, execute_tool, get_resources

        with pytest.raises(TypeError):
            IncompleteServer()  # type: ignore[abstract]
