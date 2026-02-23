# Phase 1.7.3: CalAI Integration Document

**Parent Goal:** Phase 1.7 CalAI Integration
**Checklist:**
- [x] 1.7.1 CalAI Deep Link Strategy
- [x] 1.7.2 Nutrition Data Flow via Health Store
- [ ] 1.7.3 CalAI Integration Document

---

## What
Create a reference document explaining the "Side-Channel" integration strategy.

## Why
Developers might look for a "CalAI API Client" and be confused. This doc explains clearly: we use the OS Health Store as the middleman.

## How
Create `calai-integration.md` in migrations folder.

## Features
- **Architecture Diagram:** Visualizing the Zuralog -> Cal AI (Deep Link) -> OS Health Store -> Zuralog flow.

## Files
- Create: `docs/plans/backend/integrations/calai-integration.md`

## Steps

1. **Create integration reference document**

`docs/plans/backend/integrations/calai-integration.md`:

```markdown
# CalAI Integration Reference

## Overview
We integrate with CalAI using a "Zero-Friction" approach that relies on OS-level data sharing rather than direct API-to-API communication.

## Flow
1. **User** clicks "Log Food" in Zuralog.
2. **App** deep links to CalAI (`calai://`).
3. **User** takes photo in CalAI.
4. **CalAI** processes photo and writes Calories/Macros to Apple Health / Health Connect.
5. **Zuralog** background sync (or manual refresh) reads new data from Apple Health / Health Connect.

## Advantages
- No API keys or OAuth needed for CalAI.
- User owns the data in their Health wallet.
- Works even if CalAI changes their API.

## Requirements
- User must grant "Write" permissions to CalAI.
- User must grant "Read" permissions to Zuralog.
```

## Exit Criteria
- Document exists.
