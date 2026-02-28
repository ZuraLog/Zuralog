"""
Zuralog Cloud Brain — Application Configuration.

Type-safe settings management using Pydantic v2 BaseSettings.
All values are loaded from environment variables or a .env file.
"""

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables.

    Attributes:
        database_url: Async PostgreSQL connection string.
        redis_url: Redis connection string for task queue.
        supabase_url: Supabase project URL for Auth/RLS.
        supabase_anon_key: Supabase anonymous (public) key.
        supabase_service_key: Supabase service role key.
        pinecone_api_key: Pinecone vector DB key (Phase 1.8).
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
        app_env: Current environment (development, staging, production).
        app_debug: Enable debug mode.
    """

    database_url: str = "postgresql+asyncpg://zuralog:zuralog@localhost:5432/zuralog"
    redis_url: str = "redis://localhost:6379/0"
    supabase_url: str = ""
    supabase_anon_key: str = ""
    supabase_service_key: str = ""
    pinecone_api_key: str = ""
    openai_api_key: str = ""
    openrouter_api_key: str = ""
    openrouter_referer: str = "https://zuralog.app"
    openrouter_title: str = "Zuralog"
    openrouter_model: str = "moonshotai/kimi-k2.5"
    google_web_client_id: str = ""
    google_web_client_secret: str = ""
    strava_client_id: str = ""
    strava_client_secret: str = ""
    strava_redirect_uri: str = "zuralog://oauth/strava"
    fcm_credentials_path: str = ""
    # Firebase credentials as a JSON string (for Railway/production).
    # Takes priority over fcm_credentials_path when set.
    firebase_credentials_json: str = ""
    revenuecat_webhook_secret: str = ""
    revenuecat_api_key: str = ""
    # Comma-separated list of allowed CORS origins.
    # Use "*" for development; lock down for production.
    allowed_origins: str = "*"
    strava_webhook_verify_token: str = ""
    # Fitbit OAuth 2.0
    fitbit_client_id: str = ""
    fitbit_client_secret: str = ""
    fitbit_redirect_uri: str = "zuralog://oauth/fitbit"
    fitbit_webhook_verify_code: str = ""
    fitbit_webhook_subscriber_id: str = ""
    app_env: str = "production"
    app_debug: bool = False
    # Sentry
    sentry_dsn: str = ""
    sentry_traces_sample_rate: float = 1.0
    sentry_profiles_sample_rate: float = 0.25

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )


settings = Settings()
