# Phase 1.1.1: Cloud Brain Repository Setup

**Parent Goal:** Phase 1.1 Foundation & Infrastructure
**Checklist:**
- [ ] 1.1.1 Cloud Brain Repository Setup
- [ ] 1.1.2 Database Setup
- [ ] 1.1.3 Edge Agent Setup
- [ ] 1.1.4 Network Layer
- [ ] 1.1.5 Local Storage
- [ ] 1.1.6 UI Harness

---

## What
Initialize the backend "Cloud Brain" as a modular Python application using FastAPI. This involves setting up the directory structure, dependency management with Poetry, Docker containerization, and the core application entry point.

## Why
A solid foundation is critical for scalability. FastAPI provides high performance and automatic documentation. Poetry ensures reproducible builds. Docker enables consistent deployment across environments (dev vs prod).

## How
We will use:
- **FastAPI:** For the web framework.
- **Poetry:** For dependency management.
- **Uvicorn:** As the ASGI server.
- **Docker:** For containerization.
- **Pydantic:** For settings management and data validation.

## Features
- **Health Check Endpoint:** Verifies the service is running.
- **Configuration Management:** Type-safe settings via `.env` files.
- **Dependency Isolation:** Virtual environments managed by Poetry.
- **Containerization:** Ready for deployment.

## Files
- Create: `cloud-brain/pyproject.toml`
- Create: `cloud-brain/Dockerfile`
- Create: `cloud-brain/docker-compose.yml`
- Create: `cloud-brain/app/main.py`
- Create: `cloud-brain/app/config.py`

## Steps

1. **Create Cloud Brain project structure**

```bash
mkdir -p cloud-brain
cd cloud-brain
poetry init --name life-logger-cloud-brain
poetry add fastapi uvicorn sqlalchemy asyncpg pydantic pydantic-settings python-dotenv openai pinecone celery redis httpx
poetry add --group dev pytest pytest-asyncio black ruff
```

2. **Create `cloud-brain/app/config.py`**

```python
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    supabase_url: str
    supabase_anon_key: str
    supabase_service_key: str
    openrouter_api_key: str
    openrouter_referer: str = "https://lifelogger.app"
    openrouter_title: str = "Life Logger"
    pinecone_api_key: str
    redis_url: str
    strava_client_id: str
    strava_client_secret: str
    
    class Config:
        env_file = ".env"

settings = Settings()
```

3. **Create `cloud-brain/app/main.py`**

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="Life Logger Cloud Brain")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
async def health_check():
    return {"status": "healthy"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
```

4. **Test the setup**

```bash
cd cloud-brain
poetry run uvicorn app.main:app --reload
# Verify: http://localhost:8000/health returns {"status": "healthy"}
```

## Exit Criteria
- Cloud Brain starts without errors.
- `/health` endpoint returns `{"status": "healthy"}`.
