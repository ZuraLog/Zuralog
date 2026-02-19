# Phase 1.8.6: User Profile & Preferences

**Parent Goal:** Phase 1.8 The AI Brain (Reasoning Engine)
**Checklist:**
- [x] 1.8.1 LLM Client Setup
- [x] 1.8.2 Agent System Prompt
- [x] 1.8.3 Tool Selection Logic
- [x] 1.8.4 Cross-App Reasoning Engine
- [x] 1.8.5 Voice Input
- [ ] 1.8.6 User Profile & Preferences
- [ ] 1.8.7 Test Harness: AI Chat
- [ ] 1.8.8 Kimi Integration Document
- [ ] 1.8.9 Rate Limiter Service
- [ ] 1.8.10 Usage Tracker Service
- [ ] 1.8.11 Rate Limiter Middleware

---

## What
Create a persistent store for user-specific AI settings, such as "Coach Persona" (Tough/Gentle), "Goals" (Weight Loss/Muscle Gain), and "Privacy Level".

## Why
The AI needs to know *who* it is talking to in order to be effective. A "Tough Love" coach fits some, but not others.

## How
Extend the `UserProfile` schema (from Phase 1.3/2) and add API endpoints to update it.

## Features
- **Persona Slider:** Adjusts the system prompt dynamically.
- **Goal Context:** Injects "User wants to lose 5kg" into the context window.

## Files
- Modify: `cloud-brain/app/agent/context_manager/user_profile_manager.py`
- Modify: `cloud-brain/app/api/v1/users.py`

## Steps

1. **Update UserProfileManager (`cloud-brain/app/agent/context_manager/user_profile_manager.py`)**

```python
class UserProfileManager:
    """Manages effective system prompts based on user prefs."""
    
    async def get_system_prompt_suffix(self, user_id: str) -> str:
        """
        Returns text to append to the base System Prompt.
        e.g., "The user prefers a gentle, supportive tone."
        """
        # prof = await self.db.get_profile(user_id)
        # if prof.persona == 'gentle': return ...
        return "\nUser Goal: Weight Loss. Tone: Tough Love."
```

## Exit Criteria
- Manager class can retrive prefs.
- API endpoint allows updating 'persona' field.
