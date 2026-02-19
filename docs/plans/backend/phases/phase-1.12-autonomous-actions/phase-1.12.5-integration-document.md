# Phase 1.12.5: Integration Document

**Parent Goal:** Phase 1.12 Autonomous Actions & Deep Linking
**Checklist:**
- [x] 1.12.1 Deep Link MCP Tools
- [x] 1.12.2 Edge Agent Deep Link Executor
- [x] 1.12.3 Autonomous Action Response Format
- [x] 1.12.4 Harness: Deep Link Test
- [x] 1.12.5 Integration Document

---

## What
Create a reference document listing all supported Deep Link schemes and their required parameters.

## Why
Developers and the AI need a "Phone Book" of apps.

## How
Create `docs/plans/backend/integrations/deep-links-integration.md`.

## Features
- **Schemes:** `strava://`, `calai://`, `myfitnesspal://`.
- **Fallbacks:** Web URLs to use if app missing.

## Files
- Create: `docs/plans/backend/integrations/deep-links-integration.md`

## Steps

1. **Create document**

`docs/plans/backend/integrations/deep-links-integration.md`:

```markdown
# Deep Link Registry

## Strava
- **Record:** `strava://record`
- **Home:** `strava://home`
- **Fallback:** `https://strava.com`

## CalAI
- **Camera:** `calai://camera`
- **Search:** `calai://search?q={query}`
- **Fallback:** `https://calai.app` (or App Store link)

## OS Configuration
- **iOS:** Add `LSApplicationQueriesSchemes` key to `Info.plist`.
  - Item 0: `strava`
  - Item 1: `calai`
- **Android:** `<queries>` tag in `AndroidManifest.xml`.
```

## Exit Criteria
- Document created.
