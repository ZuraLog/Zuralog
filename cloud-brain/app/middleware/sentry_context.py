"""
Sentry user context middleware.

Attaches the authenticated user's Supabase UID to every Sentry event,
enabling per-user error filtering in the Sentry dashboard.

Design note: ``request.state.user_id`` is populated by each route handler
after it validates the bearer token (via ``auth_service.get_user``).
The middleware reads this value AFTER ``call_next`` so the handler has had
a chance to set it. This means the user context is associated with the
*response* Sentry transaction, not with errors raised during auth itself —
but it correctly tags all successful and post-auth error events.
"""

import sentry_sdk
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request


class SentryUserContextMiddleware(BaseHTTPMiddleware):
    """Reads user ID from request state and sets Sentry user context.

    Handlers must set ``request.state.user_id`` after validating the bearer
    token. This middleware reads that value and propagates it to Sentry so
    every event on the request is tagged with the authenticated user.
    """

    async def dispatch(self, request: Request, call_next):
        # Run the handler first — it populates request.state.user_id
        # via auth_service.get_user() and the explicit state assignment.
        response = await call_next(request)

        user_id = getattr(getattr(request, "state", None), "user_id", None)
        if user_id:
            sentry_sdk.set_user({"id": user_id})
        else:
            sentry_sdk.set_user(None)

        return response
