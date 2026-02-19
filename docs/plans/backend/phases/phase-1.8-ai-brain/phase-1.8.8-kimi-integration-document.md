# Phase 1.8.8: Kimi Integration Document

**Parent Goal:** Phase 1.8 The AI Brain (Reasoning Engine)
**Checklist:**
- [x] 1.8.1 LLM Client Setup
- [x] 1.8.2 Agent System Prompt
- [x] 1.8.3 Tool Selection Logic
- [x] 1.8.4 Cross-App Reasoning Engine
- [x] 1.8.5 Voice Input
- [x] 1.8.6 User Profile & Preferences
- [x] 1.8.7 Test Harness: AI Chat
- [ ] 1.8.8 Kimi Integration Document
- [ ] 1.8.9 Rate Limiter Service
- [ ] 1.8.10 Usage Tracker Service
- [ ] 1.8.11 Rate Limiter Middleware

---

## What
Create a reference document for the AI Brain's configuration and capabilities.

## Why
Prompt Engineering is an ongoing process. We need a place to document *why* the system prompt is written the way it is, and what models we support.

## How
Create `ai-brain-integration.md` in integrations folder.

## Features
- **Model Specs:** Context window size, pricing.
- **Prompt Strategy:** Explanation of "Tough Love" implementation.

## Files
- Create: `docs/plans/backend/integrations/ai-brain-integration.md`

## Steps

1. **Create documentation**

`docs/plans/backend/integrations/ai-brain-integration.md`:

```markdown
# AI Brain Integration Reference

## Model Strategy
- **Primary:** `moonshot/kimi-k2.5` via OpenRouter.
- **Backup:** `google/gemini-flash-1.5` (if Kimi is down).
- **Reasoning:** We use Kimi for its large context window (128k) and good instruction following.

## Agent Architecture
- **Orchestrator:** Loops through Tool Calls (Max 5).
- **Memory:** Short-term (Conversation History) + Long-term (Vector DB - future).

## Prompt Engineering
- **Persona:** "Tough Love Coach".
- **Safety:** Medical disclaimers are hard-coded in System Prompt.
- **Tools:** The Agent *must* use tools to get data; it cannot hallucinate step counts.

## Costs (Estimates)
- Input: $X / 1M tokens
- Output: $Y / 1M tokens
```

## Exit Criteria
- Document exists.
