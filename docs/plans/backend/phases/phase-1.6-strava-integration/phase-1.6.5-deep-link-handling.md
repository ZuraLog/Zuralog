# Phase 1.6.5: Deep Link Handling for OAuth

**Parent Goal:** Phase 1.6 Strava Integration
**Checklist:**
- [x] 1.6.1 Strava API Setup
- [x] 1.6.2 Strava OAuth Flow (Cloud Brain)
- [x] 1.6.3 Strava MCP Server
- [x] 1.6.4 Edge Agent OAuth Flow
- [ ] 1.6.5 Deep Link Handling
- [ ] 1.6.6 Strava WebView Button
- [ ] 1.6.7 Strava Integration Document

---

## What
Configure the Flutter app to wake up when a specific URL scheme (`lifelogger://`) is opened on the device.

## Why
When the user finishes logging in on Strava's website, Strava redirects them to `lifelogger://oauth/strava?code=xyz`. The app must intercept this to grab the code.

## How
Use `app_links` or `uni_links` package (or native config + Flutter's routing). We'll assume native config for stability in the MVP plan documentation, integrated with Flutter's `go_router` or manual handling.

## Features
- **Seamless UX:** User is bounced from Browser back to App automatically.

## Files
- Modify: `life_logger/ios/Runner/Info.plist`
- Modify: `life_logger/android/app/src/main/AndroidManifest.xml`
- Create: `life_logger/lib/core/deeplink/deeplink_handler.dart`

## Steps

1. **Configure iOS scheme (`Info.plist`)**

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.lifelogger</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>lifelogger</string>
        </array>
    </dict>
</array>
```

2. **Configure Android scheme (`AndroidManifest.xml`)**

Inside the `<activity>` tag for MainActivity:
```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <!-- Accepts lifelogger://oauth/strava -->
    <data android:scheme="lifelogger" android:host="oauth" />
</intent-filter>
```

3. **Handle Deep Link in Dart (`life_logger/lib/core/deeplink/deeplink_handler.dart`)**

```dart
// Basic handler logic (pseudo-code, depends on router choice)
void handleDeepLink(Uri uri, WidgetRef ref) {
  if (uri.scheme == 'lifelogger' && uri.host == 'oauth' && uri.path == '/strava') {
    final code = uri.queryParameters['code'];
    if (code != null) {
        // Call repository to exchange code
        ref.read(oauthRepositoryProvider).handleStravaCallback(code).then((success) {
            // Show toast/snackbar result
        });
    }
  }
}
```

## Exit Criteria
- App opens when `lifelogger://oauth/strava?code=123` is typed in Safari/Chrome.
- Code is extracted correctly.
