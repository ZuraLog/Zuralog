"""
Zuralog Cloud Brain — Database Engine and Session Management.

Provides the async SQLAlchemy engine, session factory, and declarative
base for all ORM models. Uses the modern SQLAlchemy 2.0 API.
"""

from collections.abc import AsyncGenerator

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase
from sqlalchemy.pool import NullPool

from app.config import settings

# Async engine connected to PostgreSQL via asyncpg driver.
# FastAPI uses a small pool — 2 connections + 3 overflow is sufficient for the
# async request model. Each request holds a connection only while awaiting a
# query; idle time is minimal so a small pool services many concurrent requests.
engine = create_async_engine(
    settings.database_url,
    echo=settings.app_debug,
    pool_pre_ping=True,
    pool_size=2,
    max_overflow=3,
    pool_recycle=1800,
)

# Session factory for creating async database sessions.
async_session = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)

# Worker engine: NullPool because Celery tasks use asyncio.run() which destroys
# the event loop after each task. asyncpg connections are loop-scoped — pooling
# across asyncio.run() calls is semantically broken. NullPool is correct here.
# Scale path: switch to --pool=gevent with shared event loop, then use real pooling.
_worker_engine = create_async_engine(
    settings.database_url,
    echo=settings.app_debug,
    pool_pre_ping=True,
    poolclass=NullPool,
)
worker_async_session = async_sessionmaker(
    _worker_engine,
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
