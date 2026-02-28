# Integration: Strava

**Status:** ✅ Production  
**Priority:** P0  
**Type:** Direct API (REST)  
**Auth:** OAuth 2.0 (Authorization Code — no PKCE)

---

## API Details

| Property | Value |
|----------|-------|
| Base URL | `https://www.strava.com/api/v3` |
| Auth URL | `https://www.strava.com/oauth/authorize` |
| Token URL | `https://www.strava.com/oauth/token` |
| Rate Limit | 100 requests/15 min, 1,000/day (per app) |
| Webhooks | Yes — real-time activity push |
| Read/Write | Both (read activities + write manual activities) |
| Pricing | Free |

## What We Read

- Activities (runs, rides, swims, all sport types)
- Athlete stats (totals, recent, year-to-date)
- GPS routes and segments (future)

## What We Write

- Manual activity creation (`POST /activities`)
- Activity description updates

## MCP Tools

| Tool | Description |
|------|-------------|
| `strava_get_activities` | Get list of activities for a date range |
| `strava_create_activity` | Create a manual activity (run, ride, etc.) |
| `strava_get_athlete_stats` | Get athlete totals and recent stats |

## Implementation Details

**Files:**
- `cloud-brain/app/services/strava_token_service.py` — OAuth flow, auto-refresh
- `cloud-brain/app/services/strava_rate_limiter.py` — Redis sliding-window app-level limiter
- `cloud-brain/app/mcp_servers/strava_server.py` — MCP tools
- `cloud-brain/app/api/v1/fitbit_routes.py` — OAuth routes (authorize, exchange, status, disconnect)
- `cloud-brain/app/api/v1/strava_webhooks.py` — Webhook event handler

**Rate Limiting Strategy:** App-level sliding window in Redis. Tracks `100 req / 15 min` and `1,000 req / day` globally across all Strava API calls. Fails open if Redis unavailable.

**Token Lifecycle:**
- Access token: ~6 hours
- Refresh token: Long-lived (refresh when access token nears expiry)
- Auto-refresh occurs transparently in `strava_token_service.get_access_token()`

**Webhook Flow:**
1. Strava sends `POST /api/v1/webhooks/strava` on new activity
2. Handler responds 200 immediately
3. Dispatches `sync_strava_activity_task` Celery task
4. Task fetches full activity data and upserts to `UnifiedActivity`

## Deep Link Support

`strava://` URI scheme registered in `DeepLinkServer` for:
- Opening Strava to the recording screen
- Opening activity detail pages
