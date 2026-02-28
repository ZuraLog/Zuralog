"""
Shared FastAPI dependencies for cache-aware route handlers.
"""

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.services.auth_service import AuthService

security = HTTPBearer()


def _get_auth_service(request: Request) -> AuthService:
    """Retrieve the shared AuthService from app state."""
    return request.app.state.auth_service


async def get_authenticated_user_id(
    request: Request,
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> str:
    """Extract and verify user_id from the JWT token.

    Returns the user_id as a string, making it available as a
    keyword argument for the @cached decorator's key_params.
    """
    auth_service: AuthService = request.app.state.auth_service
    user = await auth_service.get_user(credentials.credentials)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        )
    return user.get("id", "")
