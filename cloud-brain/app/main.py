"""
Life Logger Cloud Brain — Application Entry Point.

Initializes the FastAPI application with CORS middleware,
the health check endpoint, and the auth API router.
Manages the httpx.AsyncClient lifecycle for Supabase Auth calls.
"""

from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.auth import router as auth_router
from app.config import settings
from app.services.auth_service import AuthService


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Application lifespan handler for startup and shutdown events.

    Startup: Create shared httpx client and AuthService.
    Shutdown: Close the httpx client and clean up resources.

    Args:
        app: The FastAPI application instance.
    """
    # --- Startup ---
    print(f"🚀 Life Logger Cloud Brain starting in {settings.app_env} mode")
    http_client = httpx.AsyncClient(timeout=30.0)
    app.state.auth_service = AuthService(client=http_client)
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
