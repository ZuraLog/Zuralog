# AI Brain Integration (OpenRouter + Kimi K2.5)

> **Status:** Reference document for Phase 1.8 implementation  
> **Priority:** P0 (MVP)

---

## Overview

This document covers the AI Brain implementation using **OpenRouter** as the unified LLM gateway with **Kimi K2.5** as the primary model, integrated via the MCP (Model Context Protocol) architecture.

---

## LLM Selection

### Primary: OpenRouter (Unified Gateway)

**Justification:**
- Unified API for 100+ LLMs with single integration
- Built-in rate limiting and cost tracking
- Automatic fallback capabilities
- Cost-effective at ~$1.50/user/month
- No single-vendor lock-in

### Model: Kimi K2.5 (via OpenRouter)

**Why Kimi K2.5:**
- Superior instruction following for MCP tool calls
- Interleaved reasoning reduces hallucinations
- Available through OpenRouter at competitive pricing
- 200K context window

### Alternative Models (Future)
- **Claude 3.5 Sonnet**: Premium reasoning (~$3/1M input)
- **Llama 3.1 70B**: Cost-effective ($0.80/1M input)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Cloud Brain                              │
│  ┌──────────┐    ┌──────────────┐    ┌────────────────┐  │
│  │  FastAPI  │───>│   Orchestr   │───>│  MCP Client    │  │
│  │   Chat    │    │   (Agent)    │    │                │  │
│  └──────────┘    └──────────────┘    └────────┬───────┘  │
│                                               │            │
│  ┌─────────────────────────────────────────────▼──────────┐  │
│  │              Available MCP Tools                       │  │
│  │  • apple_health_read/write                            │  │
│  │  • health_connect_read/write                           │  │
│  │  • strava_get_activities / create_activity           │  │
│  │  • open_app (deep links)                              │  │
│  └───────────────────────────────────────────────────────┘  │
│                           │                                 │
│                    ┌──────▼──────┐                          │
│                    │ OpenRouter  │                          │
│                    │  (Kimi K2.5) │                          │
│                    └─────────────┘                          │
└─────────────────────────────────────────────────────────────┘
```

---

## System Prompt

```python
SYSTEM_PROMPT = """You are Life Logger, an AI health assistant 
with a "Tough Love Coach" persona.

## Your Capabilities
- Read data from Apple Health, Google Health Connect, Strava
- Write nutrition entries and workouts to Health Stores
- Create manual activities in Strava
- Open external apps via deep links

## Your Personality
- Opinionated and direct
- Context-aware (sleep, nutrition, activity together)
- Proactive with suggestions

## Guidelines
- Be helpful but honest
- Use specific numbers from user data
- Suggest actionable next steps
"""
```

---

## Tool Schema

All tools follow this schema format:

```python
{
    "name": "tool_name",
    "description": "What this tool does",
    "input_schema": {
        "type": "object",
        "properties": {
            "param1": {"type": "string"},
            "param2": {"type": "number"},
        },
        "required": ["param1"]
    }
}
```

---

## Reasoning Patterns

### Cross-App Correlation
```python
# Example: Why am I not losing weight?
1. Read nutrition (30 days) → avg 2180 cal/day
2. Read Strava activities → maintenance ~1950 cal
3. Calculate surplus: 2180 - 1950 = 230 cal
4. Compare activity: this month 3 runs vs last month 8 runs
5. Generate insight
```

### Pattern Detection
- Pearson correlation between sleep and activity
- Week-over-week trend analysis
- Goal progress tracking

---

## Voice Input (Whisper STT)

### Flow
1. User taps microphone in Flutter
2. Audio recorded and uploaded to Cloud Brain
3. Whisper transcribes audio to text
4. Text sent to OpenRouter (Kimi K2.5) as regular message

### Endpoint
```python
@router.post("/transcribe")
async def transcribe_audio(file: UploadFile):
    # Use OpenAI Whisper API
    transcript = openai.Audio.transcribe("whisper-1", audio_file)
    return {"text": transcript["text"]}
```

---

## Streaming Responses

### WebSocket Implementation
```python
@router.websocket("/ws/chat")
async def websocket_chat(websocket: WebSocket):
    await websocket.accept()
    
    while True:
        data = await websocket.receive_json()
        # Process message
        # Stream response tokens back
        await websocket.send_json({
            "type": "message",
            "content": "token"
        })
```

---

## Context Management

### Pinecone Integration
- Store user context as vectors
- Retrieve relevant memories for each query
- Keep conversation history organized

### User Profile
```python
{
    "coach_persona": "tough_love",  # gentle, balanced, tough_love
    "goals": {
        "target_weight": 165,
        "weekly_run_target": 3,
    },
    "connected_apps": ["strava", "apple_health"]
}
```

---

## Security Features

### API Rate Limiting

Rate limits enforced per subscription tier via Redis sliding window algorithm:

| Tier | Requests/minute | Requests/day | Tokens/day |
|------|-----------------|--------------|------------|
| Free | 10 | 100 | 10,000 |
| Premium | 60 | 1,000 | 100,000 |
| Enterprise | 120 | 10,000 | 1,000,000 |

**Implementation:**
- Redis-based sliding window counter
- Per-user tracking with user_id
- Graceful 429 response with retry-after header
- Configurable via admin dashboard

### Usage Tracking

**Tracked Metrics:**
- Daily/weekly/monthly request counts
- Token usage per model (input/output)
- Cost accumulation per user
- Peak usage times

**Storage:**
- Redis: Real-time counters (hourly reset, 30-day retention)
- PostgreSQL: Historical analytics

### Tiered Access Control

```python
TIER_LIMITS = {
    "free": {
        "max_requests_per_day": 100,
        "max_tokens_per_day": 10000,
        "allowed_models": ["moonshot/kimi-k2.5"],
        "features": ["basic_chat", "health_read"]
    },
    "premium": {
        "max_requests_per_day": 1000,
        "max_tokens_per_day": 100000,
        "allowed_models": ["moonshot/kimi-k2.5", "anthropic/claude-3.5-sonnet"],
        "features": ["basic_chat", "health_read", "health_write", "analytics"]
    }
}
```

### Cost Budget Alerts

- **Warning**: Triggered at 80% of monthly budget
- **Hard limit**: Block requests at 100%
- **Notifications**: Admin via email, users in-app

### Request Validation

```python
async def validate_request(user_id: str, model: str, estimated_tokens: int) -> bool:
    user = await get_user(user_id)
    tier = user.subscription_tier
    
    limits = TIER_LIMITS[tier]
    
    # Check model access
    if model not in limits["allowed_models"]:
        return False
    
    # Check daily token limit
    daily_usage = await get_daily_usage(user_id)
    if daily_usage + estimated_tokens > limits["max_tokens_per_day"]:
        return False
    
    return True
```

### OpenRouter Integration

**Configuration:**
```python
# cloud-brain/app/config.py
class Settings(BaseSettings):
    openrouter_api_key: str
    openrouter_referer: str = "https://lifelogger.app"
    openrouter_title: str = "Life Logger"
```

**Client Initialization:**
```python
from openai import AsyncOpenAI

class LLMService:
    def __init__(self):
        self.client = AsyncOpenAI(
            api_key=settings.openrouter_api_key,
            base_url="https://openrouter.ai/api/v1",
            default_headers={
                "HTTP-Referer": settings.openrouter_referer,
                "X-Title": settings.openrouter_title,
            }
        )
    
    async def chat(self, model: str, messages: list, user_id: str):
        # Validate request against rate limits
        await rate_limiter.check_limit(user_id)
        
        # Track usage
        await usage_tracker.record_request(user_id, model)
        
        # Call OpenRouter
        response = await self.client.chat.completions.create(
            model=model,
            messages=messages,
            temperature=0.7,
        )
        
        return response
```

**Model Selection:**
```python
def select_model(tier: str, preferred: str = None) -> str:
    """Select best model based on tier and availability."""
    if preferred and preferred in TIER_LIMITS[tier]["allowed_models"]:
        return preferred
    
    defaults = {
        "free": "moonshot/kimi-k2.5",
        "premium": "moonshot/kimi-k2.5",
        "enterprise": "moonshot/kimi-k2.5"
    }
    return defaults[tier]
```

---

## Testing Checklist

- [ ] LLM responds to health queries
- [ ] Tool calls execute correctly
- [ ] Cross-app reasoning generates insights
- [ ] Voice transcription works
- [ ] Streaming responses are smooth
- [ ] Context persists between sessions

### Security Testing

- [ ] Rate limiting blocks excess requests (429 response)
- [ ] Free tier cannot access premium models
- [ ] Usage tracking records accurate counts
- [ ] Budget alerts trigger at 80%
- [ ] Cost tracking matches actual API costs

---

## Cost Estimation

### OpenRouter Pricing (Kimi K2.5)

| Metric | Free Tier | Premium Tier |
|--------|-----------|--------------|
| Daily messages/user | 10 | 50 |
| Model | moonshot/kimi-k2.5 | moonshot/kimi-k2.5 |
| Tokens/message (in) | 1000 | 1500 |
| Tokens/message (out) | 500 | 500 |
| Monthly tokens/user | 300K in / 150K out | 2.25M in / 750K out |
| OpenRouter cost | ~$0.15/1M input | ~$0.15/1M input |
| **Cost/user/month** | **~$0.07** | **~$0.45** |

---

## References

- [OpenRouter Documentation](https://openrouter.ai/docs)
- [Kimi K2.5 Model](https://openrouter.ai/models/kimi-k2.5)
- [OpenAI Function Calling](https://platform.openai.com/docs/guides/function-calling)
- [Pinecone Vector Database](https://www.pinecone.io/)
