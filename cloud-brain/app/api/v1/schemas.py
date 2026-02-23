"""
Zuralog Cloud Brain — Auth API Schemas.

Pydantic models for request validation and response serialization
on the authentication endpoints.
"""

from datetime import date, datetime
from typing import Optional

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


class UserProfileResponse(BaseModel):
    """Response model for a user's profile.

    Returned by GET /me/profile and PATCH /me/profile.

    Attributes:
        id: Supabase UID of the user.
        email: User's email address.
        display_name: Full display name (optional).
        nickname: Name the AI coach uses (optional).
        birthday: Date of birth for age calculation (optional).
        gender: Self-identified gender, free text (optional).
        onboarding_complete: True once the profile questionnaire is done.
        created_at: Timestamp when the account was created (optional).
    """

    id: str
    email: str
    display_name: Optional[str]
    nickname: Optional[str]
    birthday: Optional[date]
    gender: Optional[str]
    onboarding_complete: bool
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class UpdateProfileRequest(BaseModel):
    """Request body for a partial profile update.

    All fields are optional; only non-None fields are applied.

    Attributes:
        display_name: New full display name.
        nickname: New coach-facing nickname.
        birthday: New date of birth.
        gender: New self-identified gender.
        onboarding_complete: Mark onboarding as done or undone.
    """

    display_name: Optional[str] = None
    nickname: Optional[str] = None
    birthday: Optional[date] = None
    gender: Optional[str] = None
    onboarding_complete: Optional[bool] = None
