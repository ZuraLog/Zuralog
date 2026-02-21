"""
Life Logger Cloud Brain — Application Configuration.

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
        strava_client_id: Strava application Client ID (Phase 1.6).
        strava_client_secret: Strava application Client Secret (Phase 1.6).
        strava_redirect_uri: OAuth callback URI registered with Strava (Phase 1.6).
        app_env: Current environment (development, staging, production).
        app_debug: Enable debug mode.
    """

    database_url: str = "postgresql+asyncpg://lifelogger:lifelogger@localhost:5432/lifelogger"
    redis_url: str = "redis://localhost:6379/0"
    supabase_url: str = ""
    supabase_anon_key: str = ""
    supabase_service_key: str = ""
    pinecone_api_key: str = ""
    openai_api_key: str = ""
    strava_client_id: str = ""
    strava_client_secret: str = ""
    strava_redirect_uri: str = "lifelogger://oauth/strava"
    app_env: str = "development"
    app_debug: bool = True

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )


settings = Settings()
