# Phase 1.7.1: CalAI Deep Link Strategy

**Parent Goal:** Phase 1.7 CalAI Integration
**Checklist:**
- [ ] 1.7.1 CalAI Deep Link Strategy
- [ ] 1.7.2 Nutrition Data Flow via Health Store
- [ ] 1.7.3 CalAI Integration Document

---

## What
Implement a strategy to seamlessly launch the external "CalAI" application from within Zuralog.

## Why
CalAI is the best-in-class tool for logging food via photos. Instead of rebuilding this complex AI feature, we leverage it. To the user, it should feel like "opening the food camera."

## How
Use `url_launcher` to open `calai://` scheme. If not installed, fallback to their web app or App Store page.

## Features
- **Smart Fallback:** Does not crash if app isn't installed.
- **Context Preservation:** (Future) Pass date/meal context via query params if supported by CalAI.

## Files
- Modify: `zuralog/lib/core/deeplink/deeplink_launcher.dart`

## Steps

1. **Create deep link launcher (`zuralog/lib/core/deeplink/deeplink_launcher.dart`)**

```dart
import 'package:url_launcher/url_launcher.dart';

class DeepLinkLauncher {
  static const _calaiScheme = 'calai';
  static const _calaiWebUrl = 'https://calai.com/app'; // Replace with actual URL

  /// Attempts to open CalAI app. Falls back to web/store if data not found.
  static Future<bool> openFoodLogging() async {
    final uri = Uri.parse('calai://camera'); // Hypothetical deep link path
    
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Ignore errors finding app
    }
    
    // Fallback
    final webUri = Uri.parse(_calaiWebUrl);
    if (await canLaunchUrl(webUri)) {
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
    
    return false;
  }
}
```

## Exit Criteria
- Launcher function compiles.
- Opens CalAI or fallback web.
