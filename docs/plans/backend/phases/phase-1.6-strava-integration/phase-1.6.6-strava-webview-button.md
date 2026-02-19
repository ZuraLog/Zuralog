# Phase 1.6.6: Strava WebView Button in Harness

**Parent Goal:** Phase 1.6 Strava Integration
**Checklist:**
- [x] 1.6.1 Strava API Setup
- [x] 1.6.2 Strava OAuth Flow (Cloud Brain)
- [x] 1.6.3 Strava MCP Server
- [x] 1.6.4 Edge Agent OAuth Flow
- [x] 1.6.5 Deep Link Handling
- [ ] 1.6.6 Strava WebView Button
- [ ] 1.6.7 Strava Integration Document

---

## What
Add the visual control to the Developer Harness to trigger the flow we just built.

## Why
To manually verify the end-to-end integration loop.

## How
Add a button that calls `OAuthRepository.getStravaAuthUrl()` and then `launchUrl(uri)`.

## Features
- **Launch Mode:** Uses `externalApplication` (System Browser) to ensure cookies/login state persists and deep linking works reliably.

## Files
- Modify: `life_logger/lib/features/harness/harness_screen.dart`

## Steps

1. **Add Strava buttons to harness (`life_logger/lib/features/harness/harness_screen.dart`)**

```dart
// Import url_launcher
import 'package:url_launcher/url_launcher.dart';

// Inside _HarnessScreenState build method
ElevatedButton(
  onPressed: () async {
    final oauthRepo = ref.read(oauthRepositoryProvider);
    final authUrl = await oauthRepo.getStravaAuthUrl();
    
    if (authUrl != null) {
      final uri = Uri.parse(authUrl);
      if (await canLaunchUrl(uri)) {
          // Launch in external browser to support deep link return
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          setState(() {
              _outputController.text = 'Launched Strava: $authUrl';
          });
      }
    } else {
       setState(() {
          _outputController.text = 'Failed to get Strava URL';
       });
    }
  },
  child: const Text('Connect Strava'),
),

ElevatedButton(
  onPressed: () async {
    // This mocks checking the connection status or fetching recent activities
    // In MVP, maybe just hit a test endpoint or the MCP tool directly via a debug endpoint
    setState(() {
        _outputController.text = 'Check logs for Strava status.';
    });
  },
  child: const Text('Check Strava Status'),
),
```

## Exit Criteria
- Button launches Safari/Chrome.
- Upon allowing access, user is redirected back to the app.
