# Phase 1.14.1: Integration Tests

**Parent Goal:** Phase 1.14 End-to-End Testing & Exit Criteria
**Checklist:**
- [x] 1.14.1 Integration Tests
- [ ] 1.14.2 E2E Flutter Test
- [ ] 1.14.3 Documentation Update
- [ ] 1.14.4 Code Review
- [ ] 1.14.5 Performance Testing
- [ ] 1.14.6 Final Exit Criteria Checklist

---

## What
Create a suite of automated tests that verify the interaction between multiple backend components (API -> DB -> MCP -> AI).

## Why
Unit tests prove individual functions work. Integration tests prove the *system* works.

## How
Use `pytest` with `pytest-asyncio` and a test database.

## Features
- **Key Flow:** Register -> Login -> Sync Data -> Query AI -> Get Response.
- **Mocking:** Mock external APIs (Strava, OpenRouter) to avoid costs and flakiness.

## Files
- Create: `cloud-brain/tests/integration/test_full_flow.py`

## Steps

1. **Write integration test (`cloud-brain/tests/integration/test_full_flow.py`)**

```python
import pytest
from httpx import AsyncClient
from cloudbrain.app.main import app

@pytest.mark.asyncio
async def test_full_user_journey():
    async with AsyncClient(app=app, base_url="http://test") as ac:
        # 1. Register
        payload = {"email": "test@example.com", "password": "password123"}
        r = await ac.post("/auth/register", json=payload)
        assert r.status_code == 200
        token = r.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        
        # 2. Sync Activity (Store Data)
        activity = {"source": "manual", "steps": 5000, "date": "2023-10-27"}
        r = await ac.post("/sync/activity", json=activity, headers=headers)
        assert r.status_code == 200
        
        # 3. Chat with AI (Mocked LLM)
        chat = {"message": "How many steps did I take?"}
        # In a real test, we'd mock the LLM to return "You took 5000 steps."
        # r = await ac.post("/chat", json=chat, headers=headers)
        # assert "5000" in r.json()["message"]
```

## Exit Criteria
- `pytest` runs successfully.
- Tests cover Auth, Sync, and basic Chat flows.
