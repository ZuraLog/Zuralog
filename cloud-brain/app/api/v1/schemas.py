"""
Zuralog Cloud Brain — Auth API Schemas.

Pydantic models for request validation and response serialization
on the authentication endpoints.
"""

from datetime import date, datetime
from typing import Literal, Optional

from pydantic import BaseModel, EmailStr, Field, field_validator


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
        password: User's password (min 8 chars).
    """

    email: EmailStr
    password: str = Field(min_length=8)


class RefreshRequest(BaseModel):
    """Request body for token refresh.

    Attributes:
        refresh_token: The long-lived refresh token from a prior login.
    """

    refresh_token: str


class SocialAuthRequest(BaseModel):
    """Request body for native OAuth social sign-in.

    Used by both Apple and Google native SDK flows. The Flutter Edge Agent
    obtains the ID token (and optionally access token / nonce) from the
    respective provider SDK and sends them here for backend validation.

    Attributes:
        provider: The OAuth provider — either "apple" or "google".
        id_token: The identity token issued by the provider. For Google
            this is the JWT from GoogleSignIn; for Apple it is the
            identityToken from Sign in with Apple.
        access_token: The provider's access token. Required for Google;
            not used for Apple.
        nonce: The raw (un-hashed) nonce generated on the client before
            calling Apple's Sign In SDK. Apple embeds the SHA-256 hash
            of this nonce in the identity token for server-side replay
            prevention. Required for Apple; omitted for Google.
    """

    provider: Literal["apple", "google"]
    id_token: str
    access_token: Optional[str] = None
    nonce: Optional[str] = None


class PasswordResetRequest(BaseModel):
    """Request body for requesting a password reset email."""
    email: EmailStr


class ResendVerificationRequest(BaseModel):
    """Request body for resending the email verification link."""
    email: EmailStr


class SetPasswordRequest(BaseModel):
    """Request body for setting a new password via recovery token."""
    new_password: str = Field(min_length=8)


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
        height_cm: User's height in centimetres (optional).
        avatar_url: URL of the user's profile picture (optional).
        onboarding_complete: True once the profile questionnaire is done.
        created_at: Timestamp when the account was created (optional).
    """

    id: str
    email: str
    display_name: Optional[str]
    nickname: Optional[str]
    birthday: Optional[date]
    gender: Optional[str]
    height_cm: Optional[float] = None
    weight_kg: Optional[float] = None
    avatar_url: Optional[str] = None
    onboarding_complete: bool
    created_at: Optional[datetime] = None

    @field_validator("avatar_url")
    @classmethod
    def avatar_url_must_be_https(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and not v.startswith("https://"):
            raise ValueError("avatar_url must be a valid HTTPS URL")
        return v

    class Config:
        from_attributes = True


class ChangeEmailRequest(BaseModel):
    """Request body for changing the user's email address.

    Attributes:
        new_email: The new email address. Supabase will send a
            confirmation link here — the change is not applied until clicked.
    """

    new_email: EmailStr


class ChangePasswordRequest(BaseModel):
    """Request body for changing the user's password.

    Attributes:
        current_password: The user's current password for verification.
        new_password: The new password (minimum 8 characters).
    """

    current_password: str = Field(min_length=1)
    new_password: str = Field(min_length=8)


class UpdateProfileRequest(BaseModel):
    """Request body for a partial profile update.

    All fields are optional. Fields not sent are left unchanged; sending null
    explicitly will clear the field in the database.

    Basic fields live on ``users``; the onboarding profile fields
    (focus_area, tone, diet, etc.) live on ``user_preferences`` and are
    routed there by the handler.
    """

    # Basic profile fields (users table)
    display_name: Optional[str] = None
    nickname: Optional[str] = None
    birthday: Optional[date] = None
    gender: Optional[str] = None
    height_cm: Optional[float] = Field(default=None, ge=30, le=300)
    weight_kg: Optional[float] = Field(default=None, ge=1, le=500)
    onboarding_complete: Optional[bool] = None

    # Onboarding profile fields (user_preferences table)
    focus_area: Optional[Literal["sleep", "activity", "nutrition", "overall"]] = None
    primary_goal: Optional[str] = Field(default=None, max_length=200)
    tone: Optional[Literal["direct", "warm", "minimal", "thorough"]] = None
    dietary_restrictions: Optional[list[str]] = Field(default=None, max_length=10)
    injuries: Optional[list[str]] = Field(default=None, max_length=10)
    sleep_pattern: Optional[
        Literal["great", "hard_to_fall_asleep", "wake_up_a_lot", "short_hours"]
    ] = None
    health_frustration: Optional[str] = Field(default=None, max_length=120)
    fitness_level: Optional[Literal["beginner", "active", "athletic"]] = None
    profile_catchup_status: Optional[
        Literal["not_shown", "in_progress", "completed", "dismissed"]
    ] = None

    @field_validator("primary_goal", "health_frustration")
    @classmethod
    def _strip_text(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return None
        v = v.strip()
        return v or None  # empty/whitespace-only becomes null

    @field_validator("dietary_restrictions")
    @classmethod
    def _check_diet_items(cls, v: Optional[list[str]]) -> Optional[list[str]]:
        if v is None:
            return None
        cleaned: list[str] = []
        for item in v:
            stripped = item.strip()
            if not 1 <= len(stripped) <= 40:
                raise ValueError("dietary_restrictions items must be 1–40 chars each")
            cleaned.append(stripped)
        return cleaned

    @field_validator("injuries")
    @classmethod
    def _check_injury_items(cls, v: Optional[list[str]]) -> Optional[list[str]]:
        if v is None:
            return None
        cleaned: list[str] = []
        for item in v:
            stripped = item.strip()
            if not 1 <= len(stripped) <= 60:
                raise ValueError("injuries items must be 1–60 chars each")
            cleaned.append(stripped)
        return cleaned


class AvatarUploadResponse(BaseModel):
    """Response after a successful avatar upload.

    Attributes:
        avatar_url: Public URL of the newly uploaded profile picture.
    """

    avatar_url: str
