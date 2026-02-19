# Phase 1.6.7: Strava Integration Document

**Parent Goal:** Phase 1.6 Strava Integration
**Checklist:**
- [x] 1.6.1 Strava API Setup
- [x] 1.6.2 Strava OAuth Flow (Cloud Brain)
- [x] 1.6.3 Strava MCP Server
- [x] 1.6.4 Edge Agent OAuth Flow
- [x] 1.6.5 Deep Link Handling
- [x] 1.6.6 Strava WebView Button
- [ ] 1.6.7 Strava Integration Document

---

## What
Create a reference document detailing how the Strava integration is architected.

## Why
OAuth flows are tricky. Documenting the specific redirect URIs, scopes, and token exchange mechanism is crucial for debugging auth failures later.

## How
Create `strava-integration.md` in the integrations folder.

## Features
- **Flow Diagram:** Text-based sequence diagram of the auth flow.
- **Config Reference:** List of all ENV vars needed.
- **Scope Explanation:** Why we need `activity:write`.

## Files
- Create: `docs/plans/backend/integrations/strava-integration.md`

## Steps

1. **Create integration reference document**

`docs/plans/backend/integrations/strava-integration.md`:

```markdown
# Strava Integration Reference

## Overview
Connects Life Logger to Strava to read activities and write manual entries.

## Auth Flow (OAuth 2.0)
1. **User** clicks "Connect Strava" in App.
2. **App** requests Auth URL from Backend (`/integrations/strava/authorize`).
3. **App** opens URL in System Browser.
4. **User** logs in to Strava and approves.
5. **Strava** redirects to `lifelogger://oauth/strava?code=XXX`.
6. **App** intercepts Deep Link.
7. **App** sends `code` to Backend (`/integrations/strava/exchange`).
8. **Backend** swaps `code` for `access_token` and `refresh_token`.
9. **Backend** stores tokens associated with User.
10. **App** receives success.

## Scopes
- `read`: Public profile.
- `activity:read`: Read runs/rides.
- `activity:write`: Create new activities.

## Configuration
- `STRAVA_CLIENT_ID`: From Strava Settings.
- `STRAVA_CLIENT_SECRET`: From Strava Settings.
- `STRAVA_REDIRECT_URI`: Must match `lifelogger://oauth/strava`.

## Troubleshooting
- **400 Error on Exchange:** Code is invalid or expired (codes expire fast!).
- **Redirect fails:** Scheme `lifelogger` not registered in Info.plist/Manifest.
```

## Exit Criteria
- Document exists.
