# Strava Integration

> **Status:** Reference document for Phase 1.6 implementation  
> **Priority:** P0 (MVP)

---

## Overview

This document provides deep-dive technical details for integrating Strava API v3 into Zuralog.

---

## API Overview

### Authentication

Strava uses OAuth 2.0 for authentication:
1. Redirect user to Strava authorization page
2. User grants permission
3. Strava redirects with authorization code
4. Exchange code for access/refresh tokens

### OAuth Scopes
- `read` - Read all athlete data
- `read_all` - Read all public data
- `profile:read_all` - Read profile info
- `activity:read` - Read activities
- `activity:write` - Create/update activities

---

## API Endpoints

### Athlete
- `GET /athlete` - Get current athlete
- `GET /athletes/{id}/stats` - Get athlete statistics

### Activities
- `GET /athlete/activities` - List activities
- `GET /activities/{id}` - Get activity details
- `POST /activities` - Create manual activity
- `PUT /activities/{id}` - Update activity
- `DELETE /activities/{id}` - Delete activity

### Uploads
- `POST /uploads` - Upload activity file (FIT, GPX, TCX)

---

## Rate Limits

| Endpoint | Limit |
|----------|-------|
| All requests | 100 requests / 15 minutes |
| Uploads | 60 requests / 15 minutes |

---

## OAuth Implementation

### Authorization URL
```
https://www.strava.com/oauth/authorize?
  client_id=CLIENT_ID&
  redirect_uri=REDIRECT_URI&
  response_type=code&
  scope=read,activity:read,activity:write
```

### Token Exchange
```python
POST https://www.strava.com/oauth/token
Content-Type: application/x-www-form-urlencoded

client_id=CLIENT_ID&
client_secret=CLIENT_SECRET&
code=AUTHORIZATION_CODE&
grant_type=authorization_code
```

### Token Response
```json
{
    "access_token": "...",
    "refresh_token": "...",
    "expires_at": 1699900000,
    "athlete": {...}
}
```

---

## Creating Activities

### Request
```python
POST https://www.strava.com/api/v3/activities
Authorization: Bearer ACCESS_TOKEN
Content-Type: application/json

{
    "name": "Morning Run",
    "type": "Run",
    "sport_type": "Run",
    "start_date_local": "2026-02-18T08:00:00",
    "timezone": "America/Los_Angeles",
    "distance": 5000,
    "elapsed_time": 1800,
    "description": "Easy pace run"
}
```

### Response
```json
{
    "id": 1234567890,
    "name": "Morning Run",
    "distance": 5000,
    "moving_time": 1800,
    "elapsed_time": 1800,
    "total_elevation_gain": 50
}
```

---

## Reading Activities

### Request
```python
GET https://www.strava.com/api/v3/athlete/activities
Authorization: Bearer ACCESS_TOKEN
per_page=30
page=1
```

### Response
```json
[
    {
        "id": 1234567890,
        "name": "Morning Run",
        "type": "Run",
        "distance": 5000,
        "moving_time": 1800,
        "start_date_local": "2026-02-18T08:00:00Z",
        "average_speed": 2.78,
        "map": {...}
    }
]
```

---

## Deep Links

### Open Strava App
- Record screen: `strava://record?sport=running`
- Home: `strava://`
- Dashboard: `https://www.strava.com/dashboard`

---

## Webhooks (Future)

Strava supports webhooks for real-time activity updates:
- `POST /webhooks/subscriptions` - Create subscription

---

## Testing Checklist

- [ ] OAuth flow completes successfully
- [ ] Tokens refresh automatically
- [ ] Get recent activities
- [ ] Get athlete stats
- [ ] Create manual activity
- [ ] Handle rate limit errors
- [ ] Deep links open Strava app

---

## References

- [Strava API Documentation](https://developers.strava.com/)
- [Strava API Reference](https://www.strava.com/api/v3)
- [OAuth Flow](https://developers.strava.com/docs/authentication/)

---

## Phase 1.6 Implementation Details

> **Status:** ✅ Implemented (2026-02-21)

### Implemented Auth Flow

```text
User          Edge Agent              Cloud Brain            Strava
 │                │                       │                    │
 │  "Connect"     │                       │                    │
 │───────────────>│                       │                    │
 │                │ GET /api/v1/           │                    │
 │                │   integrations/        │                    │
 │                │   strava/authorize     │                    │
 │                │──────────────────────>│                    │
 │                │  {"auth_url": "..."}  │                    │
 │                │<──────────────────────│                    │
 │                │ launchUrl() → browser │                    │
 │   [User logs in to Strava in browser]  │                    │
 │                │                       │                    │
 │  zuralog://oauth/strava?code=XXX (deep link)             │
 │<───────────────│                       │                    │
 │                │ DeeplinkHandler fires │                    │
 │                │ POST /api/v1/          │                    │
 │                │   integrations/        │                    │
 │                │   strava/exchange      │                    │
 │                │   ?code=XXX           │                    │
 │                │   &user_id=UUID       │                    │
 │                │──────────────────────>│                    │
 │                │                       │ POST /oauth/token  │
 │                │                       │───────────────────>│
 │                │                       │ {access_token,...} │
 │                │                       │<───────────────────│
 │                │                       │ store_token()      │
 │                │   {"success": true}   │ (StravaServer)     │
 │                │<──────────────────────│                    │
 │  "✅ Strava connected!"                │                    │
```

### Environment Variables

| Variable | Description |
| --- | --- |
| `STRAVA_CLIENT_ID` | From [strava.com/settings/api](https://www.strava.com/settings/api) |
| `STRAVA_CLIENT_SECRET` | Keep server-side only — never expose to client |
| `STRAVA_REDIRECT_URI` | `zuralog://oauth/strava` (must match Strava portal) |

**Strava Portal Setup:** Set Authorization Callback Domain to `localhost` for dev or your production domain.

### MCP Tools (StravaServer)

| Tool | Description | Live in MVP? |
| --- | --- | --- |
| `strava_get_activities` | Fetch recent activities | Mock (live call ready to activate) |
| `strava_create_activity` | Create a manual entry | Mock (live call ready to activate) |

### Token Storage

MVP: in-memory `dict[user_id → access_token]` on the `StravaServer` instance.
**Phase 1.7:** Migrate to a `user_integrations` DB table with `expires_at` and auto-refresh.

### Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `400` on exchange | Code expired (~10 min TTL) | Tap "Connect Strava" again |
| `503` unreachable | Network or Strava outage | Check connectivity, retry |
| Deep link doesn't open (iOS) | Missing URL scheme | Check `CFBundleURLSchemes: zuralog` in `Info.plist` |
| Deep link doesn't open (Android) | Missing intent-filter | Check `scheme=zuralog host=oauth` in `AndroidManifest.xml` |
| `no user_id in secure storage` | User not logged in | Log in via AUTH section first |
| Token lost on restart | In-memory storage | Expected in Phase 1.6 — Phase 1.7 adds DB persistence |
