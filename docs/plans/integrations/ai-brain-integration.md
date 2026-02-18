# AI Brain Integration (Kimi K2.5)

> **Status:** Reference document for Phase 1.8 implementation  
> **Priority:** P0 (MVP)

---

## Overview

This document covers the AI Brain implementation using Kimi K2.5 as the primary LLM, integrated via the MCP (Model Context Protocol) architecture.

---

## LLM Selection

### Primary: Kimi K2.5 (Moonshot AI)

**Justification:**
- Superior instruction following for MCP tool calls
- Interleaved reasoning reduces hallucinations
- Cost-effective at ~$2.16/user/month
- 78% gross margin on $9.99 subscription

### Alternative: MiniMax M2.5 (Future)
- Lower cost ($0.90/user/month)
- Risk: "Lazy Coder" tendency could cause data corruption

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
│  ┌───────────────────────────────────────────▼──────────┐  │
│  │              Available MCP Tools                       │  │
│  │  • apple_health_read/write                            │  │
│  │  • health_connect_read/write                           │  │
│  │  • strava_get_activities / create_activity           │  │
│  │  • open_app (deep links)                              │  │
│  └───────────────────────────────────────────────────────┘  │
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
4. Text sent to Kimi as regular message

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

## Testing Checklist

- [ ] LLM responds to health queries
- [ ] Tool calls execute correctly
- [ ] Cross-app reasoning generates insights
- [ ] Voice transcription works
- [ ] Streaming responses are smooth
- [ ] Context persists between sessions

---

## Cost Estimation

| Metric | Value |
|--------|-------|
| Daily messages/user | 30 |
| Tokens/message (in) | 1500 |
| Tokens/message (out) | 500 |
| Monthly tokens/user | 1.35M in / 450K out |
| Kimi cost | $0.60/1M input / $1.80/1M output |
| **Cost/user/month** | **~$2.16** |

---

## References

- [Kimi API Documentation](https://platform.moonshot.cn/)
- [OpenAI Function Calling](https://platform.openai.com/docs/guides/function-calling)
- [Pinecone Vector Database](https://www.pinecone.io/)
