# Phase 1.6.1: Strava API Setup

**Parent Goal:** Phase 1.6 Strava Integration
**Checklist:**
- [ ] 1.6.1 Strava API Setup
- [ ] 1.6.2 Strava OAuth Flow (Cloud Brain)
- [ ] 1.6.3 Strava MCP Server
- [ ] 1.6.4 Edge Agent OAuth Flow
- [ ] 1.6.5 Deep Link Handling
- [ ] 1.6.6 Strava WebView Button
- [ ] 1.6.7 Strava Integration Document

---

## What
Obtain API credentials (Client ID, Client Secret) from Strava and configure them securely in the Cloud Brain backend.

## Why
We need these credentials to identify our application to Strava during the OAuth handshake.

## How
Register on Strava's developer portal, copy the keys to our `.env` file, and load them via `config.py`.

## Features
- **Security:** Secrets are kept out of source code.
- **Environment Parity:** Different keys for Dev/Prod if needed (though Strava usually gives one set per "app").

## Files
- Modify: `cloud-brain/app/config.py`
- Create: `cloud-brain/app/.env.example`

## Steps

1. **Register app in Strava Developers**
   - Go to https://www.strava.com/settings/api
   - Create application "Zuralog"
   - Category: "Data Importer/Exporter" or "Club"
   - **Authorization Callback Domain:** `localhost` (for simulator testing) or your ngrok/production domain. *Note: Strava requires the redirect URI's domain to match this.*

2. **Create .env.example (`cloud-brain/app/.env.example`)**

```
STRAVA_CLIENT_ID=your_client_id
STRAVA_CLIENT_SECRET=your_client_secret
STRAVA_REDIRECT_URI=zuralog://oauth/strava
```

3. **Configure Strava credentials (`cloud-brain/app/config.py`)**

```python
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # ... existing settings ...
    strava_client_id: str = ""
    strava_client_secret: str = ""
    strava_redirect_uri: str = "zuralog://oauth/strava"

    class Config:
        env_file = ".env"

settings = Settings()
```

## Exit Criteria
- Strava API credentials obtained.
- `settings.strava_client_id` is accessible in python shell.
