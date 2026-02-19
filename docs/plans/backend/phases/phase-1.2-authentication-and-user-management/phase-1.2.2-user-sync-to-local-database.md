# Phase 1.2.2: User Sync to Local Database

**Parent Goal:** Phase 1.2 Authentication & User Management
**Checklist:**
- [x] 1.2.1 Cloud Brain Auth Endpoints
- [ ] 1.2.2 User Sync to Local Database
- [ ] 1.2.3 Edge Agent Auth Repository
- [ ] 1.2.4 Edge Agent Auth UI Harness
- [ ] 1.2.5 Token Refresh Logic

---

## What
Implement a synchronization mechanism that ensures every user created/authenticated via Supabase Auth also exists in our local PostgreSQL `users` table.

## Why
Supabase Auth maintains its own `auth.users` table which is internal to Supabase. To establish foreign key relationships (e.g., linking activities, journals, or chat history to a user) in our own application schema, we need a corresponding record in our public `users` table.

## How
We will use a "Check and Create" pattern within the Auth endpoints:
1. When a user registers or logs in successfully via Supabase.
2. We immediately check if their UUID exists in our `users` table.
3. If not, we insert it.

## Features
- **Data Integrity:** Ensures no "orphan" data; all application data keys to a valid user record.
- **Profile Extensibility:** Allows us to store application-specific profile data (like "Coach Persona") separate from auth credentials.

## Files
- Modify: `cloud-brain/app/api/v1/auth.py`
- Create: `cloud-brain/app/services/user_service.py`

## Steps

1. **Create user sync service**

```python
# cloud-brain/app/services/user_service.py
from sqlalchemy.ext.asyncio import AsyncSession
from cloudbrain.app.models.user import User

async def sync_user_to_db(db: AsyncSession, supabase_user_id: str, email: str):
    """Ensure user exists in our users table after auth."""
    from sqlalchemy import select
    
    result = await db.execute(
        select(User).where(User.id == supabase_user_id)
    )
    existing_user = result.scalar_one_or_none()
    
    if not existing_user:
        new_user = User(id=supabase_user_id, email=email)
        db.add(new_user)
        await db.commit()
        return new_user
    
    return existing_user
```

2. **Call sync in register/login endpoints**

```python
from cloudbrain.app.database import get_db
from cloudbrain.app.services.user_service import sync_user_to_db

@router.post("/register")
async def register(request: RegisterRequest, db: AsyncSession = Depends(get_db)):
    auth_response = supabase.auth.sign_up({"email": request.email, "password": request.password})
    await sync_user_to_db(db, auth_response.user.id, request.email)
    return {"user_id": auth_response.user.id, "session": auth_response.session}
    
@router.post("/login")
async def login(request: LoginRequest, db: AsyncSession = Depends(get_db)):
    auth_response = supabase.auth.sign_in_with_password({"email": request.email, "password": request.password})
    await sync_user_to_db(db, auth_response.user.id, request.email)
    return {"user_id": auth_response.user.id, "session": auth_response.session}
```

## Exit Criteria
- New users are created in local `users` table after registration/login.
