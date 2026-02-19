# Phase 1.1.2: Database Setup (Supabase)

**Parent Goal:** Phase 1.1 Foundation & Infrastructure
**Checklist:**
- [x] 1.1.1 Cloud Brain Repository Setup
- [ ] 1.1.2 Database Setup
- [ ] 1.1.3 Edge Agent Setup
- [ ] 1.1.4 Network Layer
- [ ] 1.1.5 Local Storage
- [ ] 1.1.6 UI Harness

---

## What
Configure the PostgreSQL database using Supabase, set up the SQLAlchemy ORM (Object Relational Mapper) for asynchronous database interactions, and initialize Alembic for database migration management.

## Why
A robust database schema is essential for storing user data, authentication tokens, and cached health metrics. SQLAlchemy provides a Pythonic way to interact with the DB, while Alembic ensures schema changes are version-controlled and reproducible.

## How
We will use:
- **Supabase (PostgreSQL):** As the primary data store.
- **SQLAlchemy (AsyncIO):** For non-blocking database operations.
- **Alembic:** For schema migrations.
- **Asyncpg:** As the high-performance PostgreSQL driver.

## Features
- **User Management:** Storage for user profiles and preferences.
- **Integration Tracking:** securely store OAuth tokens for third-party services.
- **Async Operations:** Database calls won't block the main application thread.

## Files
- Create: `cloud-brain/app/models/__init__.py`
- Create: `cloud-brain/app/models/user.py`
- Create: `cloud-brain/app/models/integration.py`
- Create: `cloud-brain/alembic.ini`
- Create: `cloud-brain/alembic/env.py`

## Steps

1. **Create SQLAlchemy async engine in `cloud-brain/app/database.py`**

```python
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from sqlalchemy.ext.declarative import declarative_base

DATABASE_URL = f"postgresql+asyncpg://..."

engine = create_async_engine(DATABASE_URL, echo=True)
async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
Base = declarative_base()

async def get_db():
    async with async_session() as session:
        yield session
```

2. **Create User model in `cloud-brain/app/models/user.py`**

```python
from sqlalchemy import Column, String, DateTime, Boolean
from sqlalchemy.sql import func
from cloudbrain.app.database import Base

class User(Base):
    __tablename__ = "users"
    
    id = Column(String, primary_key=True)  # Supabase UID
    email = Column(String, unique=True, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    coach_persona = Column(String, default="tough_love")  # gentle, balanced, tough_love
    is_premium = Column(Boolean, default=False)
```

3. **Create Integration model in `cloud-brain/app/models/integration.py`**

```python
from sqlalchemy import Column, String, DateTime, Boolean, JSON
from cloudbrain.app.database import Base

class Integration(Base):
    __tablename__ = "integrations"
    
    id = Column(String, primary_key=True)
    user_id = Column(String, index=True)  # FK to users.id
    provider = Column(String)  # strava, apple_health, health_connect, fitbit, oura
    access_token = Column(String)
    refresh_token = Column(String)
    token_expires_at = Column(DateTime(timezone=True))
    metadata = Column(JSON)  # Store provider-specific data
    is_active = Column(Boolean, default=True)
    last_synced_at = Column(DateTime(timezone=True))
```

4. **Run migrations**

```bash
cd cloud-brain
poetry run alembic init alembic
poetry run alembic revision --autogenerate -m "initial tables"
poetry run alembic upgrade head
```

## Exit Criteria
- Database tables created.
- Migrations run successfully.
