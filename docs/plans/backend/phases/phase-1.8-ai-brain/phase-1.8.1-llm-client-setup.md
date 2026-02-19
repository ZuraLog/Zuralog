# Phase 1.8.1: LLM Client Setup

**Parent Goal:** Phase 1.8 The AI Brain (Reasoning Engine)
**Checklist:**
- [x] 1.8.1 LLM Client Setup
- [ ] 1.8.2 Agent System Prompt
- [ ] 1.8.3 Tool Selection Logic
- [ ] 1.8.4 Cross-App Reasoning Engine
- [ ] 1.8.5 Voice Input
- [ ] 1.8.6 User Profile & Preferences
- [ ] 1.8.7 Test Harness: AI Chat
- [ ] 1.8.8 Kimi Integration Document
- [ ] 1.8.9 Rate Limiter Service
- [ ] 1.8.10 Usage Tracker Service
- [ ] 1.8.11 Rate Limiter Middleware

---

## What
Create a reusable Python client that handles communication with the OpenRouter API to access the Kimi K2.5 model.

## Why
We need a robust wrapper to handle authentication, retries, and the standard OpenAI-compatible chat completion format, allowing the rest of the app to just say "chat(messages, tools)".

## How
Use `httpx` for async HTTP calls. Configurable via `.env` variables for API keys and headers.

## Features
- **Model Agnostic:** Can switch to other OpenRouter models by changing config.
- **Async:** Non-blocking I/O for high performance.
- **Traceability:** Sends required headers (Title, Referer) for OpenRouter rankings.

## Files
- Create: `cloud-brain/app/agent/llm_client.py`

## Steps

1. **Create OpenAI-compatible LLM client (`cloud-brain/app/agent/llm_client.py`)**

```python
import httpx
from cloudbrain.app.config import settings
from tenacity import retry, stop_after_attempt, wait_exponential

class LLMClient:
    """Client for Kimi K2.5 via OpenRouter."""
    
    def __init__(self, model: str = "moonshot/kimi-k2.5"):
        self.model = model
        self.base_url = "https://openrouter.ai/api/v1"
        self.api_key = settings.openrouter_api_key
        self.referer = settings.openrouter_referer
        self.title = settings.openrouter_title
    
    @retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=2, max=10))
    async def chat(self, messages: list[dict], tools: list[dict] | None = None) -> dict:
        """Send chat request to LLM via OpenRouter."""
        payload = {
            "model": self.model,
            "messages": messages,
            "temperature": 0.7,
        }
        
        if tools:
            payload["tools"] = tools
        
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.base_url}/chat/completions",
                headers={
                    "Authorization": f"Bearer {self.api_key}",
                    "Content-Type": "application/json",
                    "HTTP-Referer": self.referer,
                    "X-Title": self.title,
                },
                json=payload,
                timeout=60.0 # Kimi can be slow if context is large
            )
            response.raise_for_status()
        
        return response.json()
    
    async def stream_chat(self, messages: list[dict], tools: list[dict] | None = None):
        """Stream chat response from LLM."""
        # Future implementation for lower latency feel
        pass
```

## Exit Criteria
- Client compiles and can make requests (with valid key).
- Retries on failure.
