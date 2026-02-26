"""
Zuralog Cloud Brain — Application Entry Point.

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
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from app.agent.context_manager.memory_store import InMemoryStore
from app.agent.llm_client import LLMClient
from app.agent.mcp_client import MCPClient
from app.api.v1.analytics import router as analytics_router
from app.api.v1.auth import router as auth_router
from app.api.v1.chat import router as chat_router
from app.api.v1.dev import router as dev_router
from app.api.v1.devices import router as devices_router
from app.api.v1.integrations import router as integrations_router
from app.api.v1.strava_webhooks import router as strava_webhook_router
from app.api.v1.transcribe import router as transcribe_router
from app.api.v1.users import router as users_router
from app.api.v1.webhooks import router as webhooks_router
from app.config import settings
from app.database import async_session
from app.limiter import limiter
from app.mcp_servers.apple_health_server import AppleHealthServer
from app.mcp_servers.deep_link_server import DeepLinkServer
from app.mcp_servers.health_connect_server import HealthConnectServer
from app.mcp_servers.registry import MCPServerRegistry
from app.mcp_servers.strava_server import StravaServer
from app.services.auth_service import AuthService
from app.services.device_write_service import DeviceWriteService
from app.services.push_service import PushService
from app.services.rate_limiter import RateLimiter
from app.services.strava_rate_limiter import StravaRateLimiter
from app.services.strava_token_service import StravaTokenService


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
    print(f"Zuralog Cloud Brain starting in {settings.app_env} mode")

    # HTTP client (shared across services)
    http_client = httpx.AsyncClient(timeout=30.0)
    app.state.auth_service = AuthService(client=http_client)

    # MCP Framework (Phase 1.3+)
    registry = MCPServerRegistry()
    registry.register(AppleHealthServer())
    registry.register(HealthConnectServer())
    # Phase 1.7: DB-backed token service wired into StravaServer
    strava_token_service = StravaTokenService()
    strava_server = StravaServer(
        token_service=strava_token_service,
        db_factory=async_session,
        rate_limiter=StravaRateLimiter(redis_url=settings.redis_url),
    )
    registry.register(strava_server)  # Phase 1.6 + 1.7
    registry.register(DeepLinkServer())  # Phase 1.12
    app.state.mcp_registry = registry
    app.state.strava_token_service = strava_token_service
    app.state.mcp_client = MCPClient(registry=registry)
    app.state.memory_store = InMemoryStore()
    app.state.llm_client = LLMClient()
    app.state.rate_limiter = RateLimiter()
    app.state.push_service = PushService()
    app.state.device_write_service = DeviceWriteService(push_service=app.state.push_service)

    yield

    # --- Shutdown ---
    if getattr(app.state, "rate_limiter", None) is not None:
        await app.state.rate_limiter.close()
    await http_client.aclose()
    print("Zuralog Cloud Brain shutting down")


app = FastAPI(
    title="Zuralog Cloud Brain",
    description="AI Health Assistant Backend — Cross-app reasoning and autonomous actions.",
    version="0.1.0",
    lifespan=lifespan,
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router, prefix="/api/v1")
app.include_router(chat_router, prefix="/api/v1")  # Phase 1.9
app.include_router(integrations_router, prefix="/api/v1")  # Phase 1.6
app.include_router(transcribe_router, prefix="/api/v1")  # Phase 1.8.5
app.include_router(users_router, prefix="/api/v1")  # Phase 1.8.6
app.include_router(devices_router, prefix="/api/v1")  # Phase 1.10
app.include_router(dev_router, prefix="/api/v1")  # Phase 1.10 (dev-only)
app.include_router(analytics_router, prefix="/api/v1")  # Phase 1.11
app.include_router(webhooks_router, prefix="/api/v1")  # Phase 1.13
app.include_router(strava_webhook_router, prefix="/api/v1")  # Phase 1.7


@app.get("/health")
async def health_check() -> dict[str, str]:
    """Health check endpoint.

    Returns a simple JSON response to verify the service is running.
    Used by Docker health checks, load balancers, and monitoring.

    Returns:
        dict: A dictionary with the service status.
    """
    return {"status": "healthy"}
