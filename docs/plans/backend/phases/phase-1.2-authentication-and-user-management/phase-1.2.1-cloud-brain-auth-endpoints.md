# Phase 1.2.1: Cloud Brain Auth Endpoints

**Parent Goal:** Phase 1.2 Authentication & User Management
**Checklist:**
- [ ] 1.2.1 Cloud Brain Auth Endpoints
- [ ] 1.2.2 User Sync to Local Database
- [ ] 1.2.3 Edge Agent Auth Repository
- [ ] 1.2.4 Edge Agent Auth UI Harness
- [ ] 1.2.5 Token Refresh Logic

---

## What
Create a set of RESTful API endpoints in the Cloud Brain to handle user authentication (Registration, Login, Logout) by proxying requests to Supabase Auth.

## Why
While Supabase provides a client-side SDK, routing auth through our "Cloud Brain" proxy allows us to centrally manage user sessions, inject custom logic (like syncing to our local User table), and maintain a consistent API surface area for the Edge Agent, decoupling it from the underlying auth provider if we switch later.

## How
We will use:
- **FastAPI APIRouter:** To define the endpoints.
- **Supabase Python Client:** To interact with Supabase Auth services.
- **Pydantic Models:** To validate request bodies (email/password).

## Features
- **Registration:** Create new users.
- **Login:** Authenticate existing users and return JWTs.
- **Logout:** Invalidate sessions.
- **Security:** Bearer token validation for protected routes.

## Files
- Create: `cloud-brain/app/api/v1/auth.py`
- Modify: `cloud-brain/app/main.py`

## Steps

1. **Create auth router in `cloud-brain/app/api/v1/auth.py`**

```python
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
from supabase import create_client, Client
from cloudbrain.app.config import settings

router = APIRouter(prefix="/auth", tags=["auth"])
security = HTTPBearer()

# Initialize Supabase client
supabase: Client = create_client(settings.supabase_url, settings.supabase_service_key)

class LoginRequest(BaseModel):
    email: str
    password: str

class RegisterRequest(BaseModel):
    email: str
    password: str

@router.post("/register")
async def register(request: RegisterRequest):
    """User registration via Supabase Auth."""
    try:
        auth_response = supabase.auth.sign_up({"email": request.email, "password": request.password})
        return {"user_id": auth_response.user.id, "session": auth_response.session}
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))

@router.post("/login")
async def login(request: LoginRequest):
    """User login via Supabase Auth."""
    try:
        auth_response = supabase.auth.sign_in_with_password({"email": request.email, "password": request.password})
        return {"user_id": auth_response.user.id, "session": auth_response.session}
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")

@router.post("/logout")
async def logout(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """User logout."""
    try:
        supabase.auth.sign_out()
        return {"message": "Logged out successfully"}
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
```

2. **Wire up router in main.py**

```python
from cloudbrain.app.api.v1 import auth

app.include_router(auth.router)
```

3. **Test with curl**

```bash
# Test registration
curl -X POST http://localhost:8000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"testpass123"}'

# Test login
curl -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"testpass123"}'
```

## Exit Criteria
- Registration and login endpoints return valid session tokens.
