"""
Life Logger Cloud Brain — Application Entry Point.

Initializes the FastAPI application with CORS middleware,
the health check endpoint, and the auth API router.
Manages the httpx.AsyncClient lifecycle for Supabase Auth calls
and wires up the MCP framework (registry, client, memory store).
"""

from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.agent.context_manager.memory_store import InMemoryStore
from app.agent.mcp_client import MCPClient
from app.api.v1.auth import router as auth_router
from app.config import settings
from app.mcp_servers.apple_health_server import AppleHealthServer
from app.mcp_servers.registry import MCPServerRegistry
from app.services.auth_service import AuthService


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Application lifespan handler for startup and shutdown events.

    Startup: Create shared httpx client, AuthService, MCP registry,
    MCP client, and memory store.
    Shutdown: Close the httpx client and clean up resources.

    Args:
        app: The FastAPI application instance.
    """
    # --- Startup ---
    print(f"🚀 Life Logger Cloud Brain starting in {settings.app_env} mode")

    # HTTP client (shared across services)
    http_client = httpx.AsyncClient(timeout=30.0)
    app.state.auth_service = AuthService(client=http_client)

    # MCP Framework (Phase 1.3)
    registry = MCPServerRegistry()
    registry.register(AppleHealthServer())
    app.state.mcp_registry = registry
    app.state.mcp_client = MCPClient(registry=registry)
    app.state.memory_store = InMemoryStore()

    yield

    # --- Shutdown ---
    await http_client.aclose()
    print("👋 Life Logger Cloud Brain shutting down")


app = FastAPI(
    title="Life Logger Cloud Brain",
    description="AI Health Assistant Backend — Cross-app reasoning and autonomous actions.",
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router, prefix="/api/v1")


@app.get("/health")
async def health_check() -> dict[str, str]:
    """Health check endpoint.

    Returns a simple JSON response to verify the service is running.
    Used by Docker health checks, load balancers, and monitoring.

    Returns:
        dict: A dictionary with the service status.
    """
    return {"status": "healthy"}
