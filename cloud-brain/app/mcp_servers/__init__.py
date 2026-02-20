"""
Life Logger Cloud Brain — MCP Servers Package.

Public API for the MCP server abstractions. Import the base class
and shared models from here rather than reaching into sub-modules.
"""

from app.mcp_servers.apple_health_server import AppleHealthServer
from app.mcp_servers.base_server import BaseMCPServer
from app.mcp_servers.models import Resource, ToolDefinition, ToolResult
from app.mcp_servers.registry import MCPServerRegistry

__all__ = [
    "AppleHealthServer",
    "BaseMCPServer",
    "MCPServerRegistry",
    "Resource",
    "ToolDefinition",
    "ToolResult",
]
