# Zuralog Integrations

This directory contains per-integration documentation for all direct API integrations in Zuralog.

## Current Integrations

| File | Integration | Status |
|------|-------------|--------|
| [strava.md](./strava.md) | Strava | ✅ Production |
| [fitbit.md](./fitbit.md) | Fitbit | ✅ Production |
| [apple-health.md](./apple-health.md) | Apple Health (HealthKit) | ✅ Production |
| [google-health-connect.md](./google-health-connect.md) | Google Health Connect | ✅ Production |

## Planned Integrations

| File | Integration | Priority |
|------|-------------|----------|
| [planned-integrations.md](./planned-integrations.md) | Oura, WHOOP, Withings, Polar, MapMyFitness, Garmin, Lose It!, Suunto | P1–P3 |

## Indirect Coverage

| File | Topic |
|------|-------|
| [indirect-integrations.md](./indirect-integrations.md) | Apps covered via Apple Health / Health Connect (CalAI, MyFitnessPal, etc.) |

## Adding a New Integration

All integrations follow the same pattern:

1. Register app on developer portal, configure OAuth 2.0 credentials
2. Create `{provider}_token_service.py` (OAuth flow, reuse Strava/Fitbit pattern)
3. Create `{provider}_server.py` (subclass `HealthDataServerBase`, ~70 lines)
4. Create `{provider}_routes.py` (OAuth callback + webhook endpoint)
5. Add Celery periodic sync task in `sync_scheduler.py`
6. Register MCP server with `MCPServerRegistry` in `main.py`
7. Add to Flutter integrations provider (update `_defaultIntegrations` list)
8. Update [roadmap.md](../roadmap.md) status
