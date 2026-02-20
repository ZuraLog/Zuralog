"""
Life Logger Cloud Brain — Auth API Schemas.

Pydantic models for request validation and response serialization
on the authentication endpoints.
"""

from pydantic import BaseModel, EmailStr


class LoginRequest(BaseModel):
    """Credentials for user login.

    Attributes:
        email: User's email address.
        password: User's password (min 6 chars enforced by Supabase).
    """

    email: EmailStr
    password: str


class RegisterRequest(BaseModel):
    """Credentials for new user registration.

    Attributes:
        email: User's email address.
        password: User's password (min 6 chars enforced by Supabase).
    """

    email: EmailStr
    password: str


class RefreshRequest(BaseModel):
    """Request body for token refresh.

    Attributes:
        refresh_token: The long-lived refresh token from a prior login.
    """

    refresh_token: str


class AuthResponse(BaseModel):
    """Successful authentication response.

    Returned on register, login, and refresh.

    Attributes:
        user_id: Supabase UID of the authenticated user.
        access_token: Short-lived JWT for API authorization.
        refresh_token: Long-lived token for silent session renewal.
        expires_in: Token lifetime in seconds.
    """

    user_id: str
    access_token: str
    refresh_token: str
    expires_in: int


class MessageResponse(BaseModel):
    """Simple message response.

    Attributes:
        message: Human-readable status message.
    """

    message: str
