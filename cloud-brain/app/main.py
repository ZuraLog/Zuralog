"""
Life Logger Cloud Brain — Application Entry Point.

Initializes the FastAPI application with CORS middleware and
the health check endpoint. This is the root of the backend.
"""

from contextlib import asynccontextmanager
from collections.abc import AsyncGenerator

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Application lifespan handler for startup and shutdown events.

    Startup: Log environment and verify configuration.
    Shutdown: Clean up resources (database connections, etc.).

    Args:
        app: The FastAPI application instance.
    """
    # --- Startup ---
    print(f"🚀 Life Logger Cloud Brain starting in {settings.app_env} mode")
    yield
    # --- Shutdown ---
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


@app.get("/health")
async def health_check() -> dict[str, str]:
    """Health check endpoint.

    Returns a simple JSON response to verify the service is running.
    Used by Docker health checks, load balancers, and monitoring.

    Returns:
        dict: A dictionary with the service status.
    """
    return {"status": "healthy"}
