# Phase 1.6.2: Strava OAuth Flow (Cloud Brain)

**Parent Goal:** Phase 1.6 Strava Integration
**Checklist:**
- [x] 1.6.1 Strava API Setup
- [ ] 1.6.2 Strava OAuth Flow (Cloud Brain)
- [ ] 1.6.3 Strava MCP Server
- [ ] 1.6.4 Edge Agent OAuth Flow
- [ ] 1.6.5 Deep Link Handling
- [ ] 1.6.6 Strava WebView Button
- [ ] 1.6.7 Strava Integration Document

---

## What
Implement the backend endpoints that facilitate the OAuth 2.0 Authorization Code flow. This includes generating the authorization URL and exchanging the returned authorization code for an Access Token and Refresh Token.

## Why
We need to perform the token exchange on the backend (Cloud Brain) to keep our Client Secret hidden. The mobile app should rarely handle the secret directly if possible, though for "PKCE" it's different. Strava supports standard Web Code flow well.

## How
Create `/integrations/strava/authorize` to give the app a URL to open.
Create `/integrations/strava/callback` which the app calls *after* getting a code from Strava, passing that code to the backend to finalize the swap.

## Features
- **Secure Token Exchange:** Secret never leaves the server.
- **Refresh Token Handling:** (Future) Logic to refresh expired tokens automatically.

## Files
- Create: `cloud-brain/app/api/v1/integrations.py`
- Modify: `cloud-brain/app/main.py` (to include router)

## Steps

1. **Create OAuth endpoints (`cloud-brain/app/api/v1/integrations.py`)**

```python
from fastapi import APIRouter, Query, HTTPException
from cloudbrain.app.config import settings
import httpx
import urllib.parse

router = APIRouter(prefix="/integrations", tags=["integrations"])

@router.get("/strava/authorize")
async def strava_authorize():
    """Get Strava OAuth URL for the mobile app to open."""
    params = {
        'client_id': settings.strava_client_id,
        'redirect_uri': settings.strava_redirect_uri, # e.g., zuralog://oauth/strava
        'response_type': 'code',
        'approval_prompt': 'auto',
        'scope': 'read,activity:read,activity:write',
    }
    # Strava auth URL
    auth_url = f"https://www.strava.com/oauth/authorize?{urllib.parse.urlencode(params)}"
    return {"auth_url": auth_url}

@router.post("/strava/exchange")
async def strava_exchange(code: str):
    """
    Exchange authorization code for tokens. 
    Called by mobile app after it intercepts the redirect uri.
    """
    async with httpx.AsyncClient() as client:
        response = await client.post(
            "https://www.strava.com/oauth/token",
            data={
                'client_id': settings.strava_client_id,
                'client_secret': settings.strava_client_secret,
                'code': code,
                'grant_type': 'authorization_code',
            }
        )
        
    if response.status_code != 200:
        raise HTTPException(status_code=400, detail="Failed to exchange token with Strava")
        
    token_data = response.json()
    
    # In a real app: Save access_token, refresh_token, expires_at linked to user_id
    # await save_integration_tokens(user_id, "strava", token_data)
    
    return {
        "success": True, 
        "message": "Strava connected!", 
        # For MVP harness, we assume the app might store strictly locally or we persist in DB
        "access_token": token_data.get("access_token") 
    }
```

## Exit Criteria
- Endpoints respond correctly.
- Can successfully exchange a manual code for a token (using Postman or curl).
