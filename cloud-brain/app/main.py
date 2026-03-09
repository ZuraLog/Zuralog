"""
Zuralog Cloud Brain — Application Entry Point.

Initializes the FastAPI application with CORS middleware,
the health check endpoint, and the auth API router.
Manages the httpx.AsyncClient lifecycle for Supabase Auth calls
and wires up the MCP framework (registry, client, memory store).
"""

import logging
import subprocess
from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager
from pathlib import Path

import httpx
import sentry_sdk
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sentry_sdk.integrations.fastapi import FastApiIntegration
from sentry_sdk.integrations.starlette import StarletteIntegration
from sentry_sdk.integrations.celery import CeleryIntegration
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from app.agent.context_manager.memory_store import InMemoryStore
from app.services.pinecone_memory_store import PineconeMemoryStore
from app.middleware.posthog_analytics import PostHogAnalyticsMiddleware
from app.middleware.sentry_context import SentryUserContextMiddleware
from app.agent.llm_client import LLMClient
from app.agent.mcp_client import MCPClient
from app.api.v1.achievement_routes import router as achievement_router
from app.api.v1.analytics import router as analytics_router
from app.api.v1.attachments import attachments_router
from app.api.v1.auth import router as auth_router
from app.api.v1.chat import router as chat_router
from app.api.v1.dev import router as dev_router
from app.api.v1.devices import router as devices_router
from app.api.v1.emergency_card_routes import router as emergency_card_router
from app.api.v1.fitbit_routes import router as fitbit_router
from app.api.v1.fitbit_webhooks import router as fitbit_webhook_router
from app.api.v1.health_ingest import router as health_ingest_router
from app.api.v1.health_score_history_routes import router as health_score_history_router
from app.api.v1.health_score_routes import router as health_score_router
from app.api.v1.insight_routes import router as insight_router
from app.api.v1.integrations import router as integrations_router
from app.api.v1.journal_routes import router as journal_router
from app.api.v1.memory_routes import router as memory_router
from app.api.v1.notification_routes import router as notification_router
from app.api.v1.oura_routes import router as oura_router
from app.api.v1.oura_webhooks import webhook_router as oura_webhook_router
from app.api.v1.polar_routes import router as polar_router
from app.api.v1.polar_webhooks import webhook_router as polar_webhook_router
from app.api.v1.preferences_routes import router as preferences_router
from app.api.v1.progress_routes import router as progress_router
from app.api.v1.prompt_suggestions import router as prompt_suggestions_router
from app.api.v1.quick_actions import router as quick_actions_router
from app.api.v1.quick_log_routes import router as quick_log_router
from app.api.v1.report_routes import router as report_router
from app.api.v1.strava_webhooks import router as strava_webhook_router
from app.api.v1.streak_routes import router as streak_router
from app.api.v1.trends_routes import router as trends_router
from app.api.v1.users import router as users_router
from app.api.v1.webhooks import router as webhooks_router
from app.api.v1.withings_routes import router as withings_router
from app.api.v1.withings_webhooks import webhook_router as withings_webhook_router
from app.config import settings
from app.database import async_session
from app.limiter import limiter
from app.mcp_servers.apple_health_server import AppleHealthServer
from app.mcp_servers.deep_link_server import DeepLinkServer
from app.mcp_servers.health_connect_server import HealthConnectServer
from app.mcp_servers.fitbit_server import FitbitServer
from app.mcp_servers.oura_server import OuraServer
from app.mcp_servers.polar_server import PolarServer
from app.mcp_servers.withings_server import WithingsServer
from app.mcp_servers.registry import MCPServerRegistry
from app.mcp_servers.strava_server import StravaServer
from app.services.auth_service import AuthService
from app.services.device_write_service import DeviceWriteService
from app.services.fitbit_rate_limiter import FitbitRateLimiter
from app.services.fitbit_token_service import FitbitTokenService
from app.services.oura_rate_limiter import OuraRateLimiter
from app.services.oura_token_service import OuraTokenService
from app.services.polar_rate_limiter import PolarRateLimiter
from app.services.polar_token_service import PolarTokenService
from app.services.withings_rate_limiter import WithingsRateLimiter
from app.services.withings_signature_service import WithingsSignatureService
from app.services.withings_token_service import WithingsTokenService
from app.services.push_service import PushService
from app.services.rate_limiter import RateLimiter
from app.services.strava_rate_limiter import StravaRateLimiter
from app.services.strava_token_service import StravaTokenService
from app.services.analytics import AnalyticsService
from app.services.cache_service import CacheService
from app.services.user_tool_resolver import UserToolResolver

# Configure root logger based on environment.
logging.basicConfig(
    level=logging.DEBUG if settings.app_debug else logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)


def _get_release() -> str:
    """Return a Sentry release string derived from the current git SHA.

    Falls back to ``cloud-brain@unknown`` if git is unavailable (e.g. in
    Docker images built without the ``.git`` directory).
    """
    try:
        sha = (
            subprocess.check_output(
                ["git", "rev-parse", "--short", "HEAD"],
                stderr=subprocess.DEVNULL,
                cwd=Path(__file__).parent,
            )
            .decode()
            .strip()
        )
        return f"cloud-brain@{sha}"
    except Exception:
        return "cloud-brain@unknown"


if settings.sentry_dsn:
    sentry_sdk.init(
        dsn=settings.sentry_dsn,
        environment=settings.app_env,
        release=_get_release(),
        traces_sample_rate=settings.sentry_traces_sample_rate,
        profiles_sample_rate=settings.sentry_profiles_sample_rate,
        send_default_pii=False,
        enable_tracing=True,
        integrations=[
            FastApiIntegration(transaction_style="endpoint"),
            StarletteIntegration(transaction_style="endpoint"),
            CeleryIntegration(),
        ],
    )
    logging.info("Sentry initialized for Cloud Brain (%s)", settings.app_env)


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
    # DeviceWriteService must be created before MCP servers that need it.
    push_svc = PushService()
    device_write_svc = DeviceWriteService(push_service=push_svc)
    registry.register(
        AppleHealthServer(
            db_factory=async_session,
            device_write_service=device_write_svc,
        )
    )
    registry.register(
        HealthConnectServer(
            db_factory=async_session,
            device_write_service=device_write_svc,
        )
    )
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

    # Fitbit wiring (Phase 5.1 / Task-3)
    fitbit_token_service = FitbitTokenService()
    fitbit_rate_limiter = FitbitRateLimiter(redis_url=settings.redis_url)
    fitbit_server = FitbitServer(
        token_service=fitbit_token_service,
        db_factory=async_session,
        rate_limiter=fitbit_rate_limiter,
    )
    registry.register(fitbit_server)
    app.state.fitbit_token_service = fitbit_token_service
    app.state.fitbit_rate_limiter = fitbit_rate_limiter

    # Oura wiring (Phase 5.2)
    oura_token_service = OuraTokenService()
    oura_rate_limiter = OuraRateLimiter(redis_url=settings.redis_url)
    oura_server = OuraServer(
        token_service=oura_token_service,
        db_factory=async_session,
    )
    registry.register(oura_server)
    app.state.oura_token_service = oura_token_service
    app.state.oura_rate_limiter = oura_rate_limiter

    # Withings wiring
    withings_signature_service = WithingsSignatureService(
        client_id=settings.withings_client_id,
        client_secret=settings.withings_client_secret,
    )
    withings_token_service = WithingsTokenService()
    withings_rate_limiter = WithingsRateLimiter(redis_url=settings.redis_url)
    withings_server = WithingsServer(
        token_service=withings_token_service,
        signature_service=withings_signature_service,
        db_factory=async_session,
        rate_limiter=withings_rate_limiter,
    )
    registry.register(withings_server)
    app.state.withings_token_service = withings_token_service
    app.state.withings_signature_service = withings_signature_service
    app.state.withings_rate_limiter = withings_rate_limiter

    # Polar wiring
    polar_token_service = PolarTokenService()
    polar_rate_limiter = PolarRateLimiter(redis_url=settings.redis_url)
    polar_server = PolarServer(
        token_service=polar_token_service,
        db_factory=async_session,
        rate_limiter=polar_rate_limiter,
    )
    registry.register(polar_server)
    app.state.polar_token_service = polar_token_service
    app.state.polar_rate_limiter = polar_rate_limiter

    # Dynamic tool injection: resolve tools per user at chat time
    tool_resolver = UserToolResolver(registry=registry)
    app.state.mcp_client = MCPClient(registry=registry, tool_resolver=tool_resolver)
    # Use Pinecone for long-term memory when configured, fall back to in-memory
    _pinecone_store = PineconeMemoryStore()
    app.state.memory_store = _pinecone_store if _pinecone_store.is_available else InMemoryStore()
    app.state.llm_client = LLMClient()
    app.state.rate_limiter = RateLimiter()
    app.state.cache_service = CacheService()
    app.state.analytics_service = AnalyticsService()
    # Reuse push_svc / device_write_svc created above for the MCP server.
    app.state.push_service = push_svc
    app.state.device_write_service = device_write_svc

    yield

    # --- Shutdown ---
    if getattr(app.state, "rate_limiter", None) is not None:
        await app.state.rate_limiter.close()
    await http_client.aclose()
    if hasattr(app.state, "analytics_service"):
        app.state.analytics_service.shutdown()
    print("Zuralog Cloud Brain shutting down")


app = FastAPI(
    title="Zuralog Cloud Brain",
    description="AI Health Assistant Backend — Cross-app reasoning and autonomous actions.",
    version="0.1.0",
    lifespan=lifespan,
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# Parse CORS origins from config. Supports "*" or comma-separated list.
_origins: list[str] = (
    ["*"]
    if settings.allowed_origins.strip() == "*"
    else [o.strip() for o in settings.allowed_origins.split(",") if o.strip()]
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_middleware(SentryUserContextMiddleware)
app.add_middleware(PostHogAnalyticsMiddleware)

app.include_router(auth_router, prefix="/api/v1")
app.include_router(chat_router, prefix="/api/v1")  # Phase 1.9
app.include_router(integrations_router, prefix="/api/v1")  # Phase 1.6
app.include_router(users_router, prefix="/api/v1")  # Phase 1.8.6
app.include_router(preferences_router, prefix="/api/v1")  # Phase 2.1
app.include_router(devices_router, prefix="/api/v1")  # Phase 1.10
app.include_router(dev_router, prefix="/api/v1")  # Phase 1.10 (dev-only)
app.include_router(analytics_router, prefix="/api/v1")  # Phase 1.11
app.include_router(webhooks_router, prefix="/api/v1")  # Phase 1.13
app.include_router(strava_webhook_router, prefix="/api/v1")  # Phase 1.7
app.include_router(health_ingest_router, prefix="/api/v1")  # Apple Health Full Integration
app.include_router(fitbit_router, prefix="/api/v1")  # Phase 5.1
app.include_router(fitbit_webhook_router, prefix="/api/v1")  # Phase 5.1
app.include_router(oura_router, prefix="/api/v1")  # Phase 5.2
app.include_router(oura_webhook_router, prefix="/api/v1")  # Phase 5.2
app.include_router(polar_router, prefix="/api/v1")  # Polar integration
app.include_router(polar_webhook_router, prefix="/api/v1")  # Polar webhooks
app.include_router(withings_router, prefix="/api/v1")  # Withings integration
app.include_router(withings_webhook_router, prefix="/api/v1")  # Withings webhooks
app.include_router(health_score_router, prefix="/api/v1")  # Phase 2.2 — health score
app.include_router(health_score_history_router, prefix="/api/v1")  # Phase 2.2 — health score history
app.include_router(memory_router, prefix="/api/v1")  # Phase 2.4 — memory management
app.include_router(insight_router, prefix="/api/v1")  # Phase 2.6 — insight cards
app.include_router(prompt_suggestions_router, prefix="/api/v1")  # Phase 2.8 — prompt suggestions
app.include_router(quick_actions_router, prefix="/api/v1")  # Phase 2.9 — quick actions
app.include_router(achievement_router, prefix="/api/v1")  # Phase 2.10 — achievements
app.include_router(streak_router, prefix="/api/v1")  # Phase 2.11 — streaks
app.include_router(journal_router, prefix="/api/v1")  # Phase 2.12 — journal
app.include_router(quick_log_router, prefix="/api/v1")  # Phase 2.13 — quick log
app.include_router(emergency_card_router, prefix="/api/v1")  # Phase 2.14 — emergency card
app.include_router(notification_router, prefix="/api/v1")  # Phase 2.15 — notification centre
app.include_router(report_router, prefix="/api/v1")  # Phase 2.18 — health reports
app.include_router(attachments_router, prefix="/api/v1")  # Phase 2.22 — chat file attachments
app.include_router(progress_router, prefix="/api/v1")  # Phase 3 — progress home
app.include_router(trends_router, prefix="/api/v1")  # Phase 3 — trends home


@app.get("/health")
async def health_check() -> dict[str, str]:
    """Health check endpoint.

    Returns a simple JSON response to verify the service is running.
    Used by Docker health checks, load balancers, and monitoring.

    Returns:
        dict: A dictionary with the service status.
    """
    return {"status": "healthy"}
