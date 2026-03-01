"""
PostHog ASGI analytics middleware.

Automatically captures an 'api_request' event for every HTTP request
with method, path, status code, duration, and user_id (if authenticated).

This provides a complete picture of API usage in PostHog without
needing to instrument every individual route handler.
"""

import logging
import time

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

logger = logging.getLogger(__name__)


class PostHogAnalyticsMiddleware(BaseHTTPMiddleware):
    """Captures API request events to PostHog for every HTTP request.

    Extracts:
    - HTTP method and path
    - Response status code
    - Request duration (ms)
    - User ID (from auth middleware, if present)
    - User agent string

    Skips:
    - Health check endpoint (/health)
    - Docs endpoints (/docs, /openapi.json, /redoc)
    - OPTIONS preflight requests
    """

    # Paths to exclude from analytics tracking
    EXCLUDED_PATHS = frozenset({"/health", "/docs", "/openapi.json", "/redoc", "/favicon.ico"})

    async def dispatch(self, request: Request, call_next) -> Response:
        # Skip excluded paths and OPTIONS
        if request.url.path in self.EXCLUDED_PATHS or request.method == "OPTIONS":
            return await call_next(request)

        start_time = time.perf_counter()
        response: Response = await call_next(request)
        duration_ms = round((time.perf_counter() - start_time) * 1000, 2)

        # Extract user_id from request state (set by auth middleware)
        user_id = getattr(getattr(request, "state", None), "user_id", None)
        if request.client:
            distinct_id = user_id or f"anon_{request.client.host}"
        else:
            distinct_id = user_id or "anon_unknown"

        # Get analytics service from app state
        analytics = getattr(request.app.state, "analytics_service", None)
        if analytics:
            properties = {
                "method": request.method,
                "path": request.url.path,
                "status_code": response.status_code,
                "duration_ms": duration_ms,
                "user_agent": request.headers.get("user-agent", ""),
                "$current_url": str(request.url.replace(query="")),
            }

            # Add route pattern if available (e.g., /api/v1/analytics/{metric})
            route = request.scope.get("route")
            if route and hasattr(route, "path"):
                properties["route_pattern"] = route.path

            analytics.capture(
                distinct_id=distinct_id,
                event="api_request",
                properties=properties,
            )

        return response
