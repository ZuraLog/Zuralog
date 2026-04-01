"""
Zuralog Cloud Brain — Application Configuration.

Type-safe settings management using Pydantic v2 BaseSettings.
All values are loaded from environment variables or a .env file.
"""

import logging

from pydantic import Field, SecretStr, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

logger = logging.getLogger(__name__)


class Settings(BaseSettings):
    """Application settings loaded from environment variables.

    Attributes:
        database_url: Async PostgreSQL connection string.
        redis_url: Redis connection string for task queue.
        supabase_url: Supabase project URL for Auth/RLS.
        supabase_anon_key: Supabase anonymous (public) key.
        supabase_service_key: Supabase service role key.
        openai_api_key: OpenAI API key for embeddings/LLM (Phase 1.8).
        google_web_client_id: Google OAuth 2.0 Web Application client ID.
        google_web_client_secret: Google OAuth 2.0 Web Application client secret.
        strava_client_id: Strava application Client ID (Phase 1.6).
        strava_client_secret: Strava application Client Secret (Phase 1.6).
        strava_redirect_uri: OAuth callback URI registered with Strava (Phase 1.6).
        fcm_credentials_path: Path to Firebase service account JSON (Phase 1.9).
        revenuecat_webhook_secret: RevenueCat webhook auth secret (Phase 1.13).
        revenuecat_api_key: RevenueCat V1 Secret API key for server-side lookups (Phase 1.13).
        strava_webhook_verify_token: Random token used to validate Strava webhook subscriptions (Phase 1.7).
        fitbit_client_id: Fitbit application Client ID (Phase 5.1).
        fitbit_client_secret: Fitbit application Client Secret (Phase 5.1).
        fitbit_redirect_uri: OAuth callback URI registered with Fitbit (Phase 5.1).
        fitbit_webhook_verify_code: Verification code used to validate Fitbit webhook subscriptions (Phase 5.1).
        fitbit_webhook_subscriber_id: Subscriber ID for Fitbit webhook subscriptions (Phase 5.1).
        oura_client_id: Oura Ring application Client ID (Phase 5.2).
        oura_client_secret: Oura Ring application Client Secret (Phase 5.2).
        oura_redirect_uri: OAuth callback URI registered with Oura (Phase 5.2).
        oura_webhook_verification_token: Token used to verify Oura webhook subscriptions (Phase 5.2).
        oura_use_sandbox: Use Oura sandbox endpoints for development/testing (Phase 5.2).
        app_env: Current environment (development, staging, production).
        app_debug: Enable debug mode.
    """

    database_url: str = "postgresql+asyncpg://zuralog:zuralog@localhost:5432/zuralog"
    redis_url: str = ""
    supabase_url: str = ""
    supabase_anon_key: SecretStr = SecretStr("")
    supabase_service_key: SecretStr = SecretStr("")
    openai_api_key: SecretStr = SecretStr("")
    openrouter_api_key: SecretStr = SecretStr("")
    openrouter_referer: str = "https://zuralog.app"
    openrouter_title: str = "Zuralog"
    openrouter_model: str = "moonshotai/kimi-k2.5"
    openrouter_insight_model: str = "google/gemini-3.1-flash-lite-preview"
    # OPENROUTER_INSIGHT_MODEL — cheap fast model for daily insight generation.
    # Separate from openrouter_model (Kimi K2.5) which is the Coach tab model.
    openrouter_title_model: str = "openai/gpt-4.1-nano"
    openrouter_fallback_model: str = "openai/gpt-4o-mini"
    google_web_client_id: str = ""
    google_web_client_secret: SecretStr = SecretStr("")
    strava_client_id: str = ""
    strava_client_secret: SecretStr = SecretStr("")
    strava_redirect_uri: str = "zuralog://oauth/strava"
    fcm_credentials_path: str = ""
    # Firebase credentials as a JSON string (for Railway/production).
    # Takes priority over fcm_credentials_path when set.
    firebase_credentials_json: str = ""
    revenuecat_webhook_secret: SecretStr = SecretStr("")
    revenuecat_api_key: SecretStr = SecretStr("")
    # Comma-separated list of allowed CORS origins.
    # Use "*" for development; lock down for production.
    allowed_origins: str = ""
    strava_webhook_verify_token: str = ""
    strava_webhook_subscription_id: int = 0  # STRAVA_WEBHOOK_SUBSCRIPTION_ID — set after first webhook registration
    # Fitbit OAuth 2.0
    fitbit_client_id: str = ""
    fitbit_client_secret: SecretStr = SecretStr("")
    fitbit_redirect_uri: str = "zuralog://oauth/fitbit"
    fitbit_webhook_verify_code: str = ""
    fitbit_webhook_subscriber_id: str = ""
    # Oura Ring OAuth 2.0
    oura_client_id: str = ""  # OURA_CLIENT_ID
    oura_client_secret: SecretStr = SecretStr("")  # OURA_CLIENT_SECRET
    oura_redirect_uri: str = "zuralog://oauth/oura"  # OURA_REDIRECT_URI
    oura_webhook_verification_token: str = ""  # OURA_WEBHOOK_VERIFICATION_TOKEN
    oura_use_sandbox: bool = False  # OURA_USE_SANDBOX
    # Withings OAuth 2.0
    withings_client_id: str = ""  # WITHINGS_CLIENT_ID
    withings_client_secret: SecretStr = SecretStr("")  # WITHINGS_CLIENT_SECRET
    withings_redirect_uri: str = ""  # WITHINGS_REDIRECT_URI
    # Base URL of the Cloud Brain API (used to construct webhook callback URLs).
    # Must be explicitly set when WITHINGS_CLIENT_ID is configured — no default.
    withings_api_base_url: str = ""  # WITHINGS_API_BASE_URL — must be set when WITHINGS_CLIENT_ID is configured
    # Shared secret appended as ?token=... to the Withings webhook callback URL.
    # Withings does not sign webhook payloads with HMAC; this query-param secret
    # is the standard defence against unauthenticated webhook spoofing.
    withings_webhook_secret: str = ""  # WITHINGS_WEBHOOK_SECRET
    # Polar AccessLink
    polar_client_id: str = ""  # POLAR_CLIENT_ID
    polar_client_secret: SecretStr = SecretStr("")  # POLAR_CLIENT_SECRET
    polar_redirect_uri: str = "zuralog://oauth/polar"  # POLAR_REDIRECT_URI
    polar_webhook_signature_key: SecretStr = SecretStr("")  # POLAR_WEBHOOK_SIGNATURE_KEY
    # Base URL of the Cloud Brain API used to construct the Polar webhook callback URL.
    # Must be explicitly set when POLAR_CLIENT_ID is configured — no default.
    polar_api_base_url: str = ""  # POLAR_API_BASE_URL — must be set when POLAR_CLIENT_ID is configured
    app_env: str = "development"
    app_debug: bool = False
    # Sentry
    sentry_dsn: str = ""
    sentry_traces_sample_rate: float = 0.1  # SENTRY_TRACES_SAMPLE_RATE — default 10% for production
    sentry_profiles_sample_rate: float = 0.25
    # Cache TTL defaults (seconds)
    cache_ttl_short: int = 300  # 5 minutes — analytics, preferences
    cache_ttl_medium: int = 900  # 15 minutes — correlations, profiles
    cache_ttl_long: int = 86400  # 24 hours — immutable historical data
    # PostHog
    posthog_api_key: str = ""
    posthog_host: str = "https://us.i.posthog.com"
    # Supabase Storage — bucket names
    avatar_bucket: str = Field(default="avatars", description="Supabase Storage bucket for avatar images. Must be set to public in Supabase dashboard.")  # AVATAR_BUCKET
    # Rate limits (Fix 1.5 / M-7)
    rate_limit_free_daily: int = 50
    rate_limit_premium_daily: int = 500
    rate_limit_burst_per_minute: int = 10
    # Conversation count limits per user
    max_conversations_free: int = 200
    max_conversations_premium: int = 2000

    @model_validator(mode="after")
    def _validate_config(self) -> "Settings":
        """Fail fast on invalid configuration combinations."""
        # H-11: Validate required secrets are set in production
        if self.app_env == "production":
            if not self.database_url:
                raise ValueError("DATABASE_URL must be set in production")
            if not self.supabase_url:
                raise ValueError("SUPABASE_URL must be set in production")
            if not self.supabase_anon_key.get_secret_value():
                raise ValueError("SUPABASE_ANON_KEY must be set in production")
            if self.openrouter_api_key.get_secret_value() == "":
                logger.error("OPENROUTER_API_KEY must be set in production")
                raise ValueError("OPENROUTER_API_KEY must be set in production")
            if self.supabase_service_key.get_secret_value() == "":
                logger.error("SUPABASE_SERVICE_KEY must be set in production")
                raise ValueError("SUPABASE_SERVICE_KEY must be set in production")

        # Fail fast if any integration credential is set but a required companion value is missing.
        if self.withings_client_id and not self.withings_redirect_uri.strip():
            raise ValueError(
                "WITHINGS_REDIRECT_URI must be set when WITHINGS_CLIENT_ID is provided. "
                "Set it to https://<your-api-domain>/api/v1/integrations/withings/callback"
            )
        if self.withings_client_id and not self.withings_api_base_url.strip():
            raise ValueError(
                "WITHINGS_API_BASE_URL must be set when WITHINGS_CLIENT_ID is configured. "
                "Without this, webhook registrations will point at the wrong host."
            )
        if self.polar_client_id and not self.polar_api_base_url.strip():
            raise ValueError(
                "POLAR_API_BASE_URL must be set when POLAR_CLIENT_ID is configured. "
                "Without this, webhook registrations will point at the wrong host."
            )
        return self

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )


settings = Settings()
