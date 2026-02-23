# Phase 1.12.2: Edge Agent Deep Link Executor

**Parent Goal:** Phase 1.12 Autonomous Actions & Deep Linking
**Checklist:**
- [x] 1.12.1 Deep Link MCP Tools
- [x] 1.12.2 Edge Agent Deep Link Executor
- [ ] 1.12.3 Autonomous Action Response Format
- [ ] 1.12.4 Harness: Deep Link Test
- [ ] 1.12.5 Integration Document

---

## What
Client-side logic to parse the `client_action` metadata from the AI response and launch the URL.

## Why
When the backend says "Open Strava," the Flutter app needs to actually invoke the OS intent.

## How
Use `url_launcher` package.

## Features
- **Fallback:** If app is not installed (can check on Android, harder on iOS), open App Store or Web fallback.

## Files
- Modify: `zuralog/lib/core/deeplink/deep_link_handler.dart`

## Steps

1. **Create Deep Link handler (`zuralog/lib/core/deeplink/deep_link_handler.dart`)**

```dart
import 'package:url_launcher/url_launcher.dart';

class DeepLinkHandler {
  
  static Future<void> handleClientAction(Map<String, dynamic> action) async {
    final type = action['type'];
    
    if (type == 'open_url') {
       final url = action['url'];
       await _launch(url);
    }
  }

  static Future<bool> _launch(String urlString) async {
    final uri = Uri.parse(urlString);
    
    try {
        if (await canLaunchUrl(uri)) {
            return await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
            print("Cannot launch $urlString");
            // Fallback: Open App Store?
            return false;
        }
    } catch (e) {
        print("Error launching url: $e");
        return false;
    }
  }
}
```

## Exit Criteria
- Handler compiles.
- `canLaunchUrl` check implemented.
