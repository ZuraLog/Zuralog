"""
Zuralog Cloud Brain — Database Engine and Session Management.

Provides the async SQLAlchemy engine, session factory, and declarative
base for all ORM models. Uses the modern SQLAlchemy 2.0 API.
"""

from collections.abc import AsyncGenerator

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

from app.config import settings

# Async engine connected to PostgreSQL via asyncpg driver.
engine = create_async_engine(
    settings.database_url,
    echo=settings.app_debug,
    pool_pre_ping=True,
    pool_size=10,
    max_overflow=20,
    pool_recycle=1800,
)

# Session factory for creating async database sessions.
async_session = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


class Base(DeclarativeBase):
    """Base class for all SQLAlchemy ORM models.

    All models should inherit from this class to be registered
    with the shared metadata and participate in Alembic migrations.
    """

    pass


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """FastAPI dependency that yields an async database session.

    The session is automatically closed after the request completes.

    Yields:
        AsyncSession: A scoped async database session.
    """
    async with async_session() as session:
        yield session
