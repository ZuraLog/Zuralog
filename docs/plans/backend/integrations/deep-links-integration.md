# Deep Link Registry -- Integration Reference

> Phase 1.12: Autonomous Actions & Deep Linking

This document is the "Phone Book" for external app deep links. It lists all
supported schemes, their required parameters, and platform configuration.

---

## Supported Apps

### Strava

| Action   | Deep Link         | Description                |
| -------- | ----------------- | -------------------------- |
| `record` | `strava://record` | Open Strava recording mode |
| `home`   | `strava://home`   | Open Strava main screen    |

**Fallback URL:** `https://www.strava.com`

### CalAI

| Action   | Deep Link                  | Description                |
| -------- | -------------------------- | -------------------------- |
| `camera` | `calai://camera`           | Open CalAI food camera     |
| `search` | `calai://search?q={query}` | Search CalAI food database |

**Fallback URL:** `https://www.calai.app`

---

## Platform Configuration

### iOS (Info.plist)

Add `LSApplicationQueriesSchemes` to allow `canLaunchUrl()` to detect installed apps:

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>strava</string>
    <string>calai</string>
</array>
```

**Location:** `zuralog/ios/Runner/Info.plist`

### Android (AndroidManifest.xml)

Add `<queries>` to allow package visibility on Android 11+:

```xml
<queries>
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="strava" />
    </intent>
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="calai" />
    </intent>
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="https" />
    </intent>
</queries>
```

**Location:** `zuralog/android/app/src/main/AndroidManifest.xml`

---

## Adding a New App

1. Add entry to `cloud-brain/app/mcp_servers/deep_link_registry.py` (`_REGISTRY` and `_FALLBACKS`)
2. Add scheme to iOS `Info.plist` (`LSApplicationQueriesSchemes`)
3. Add `<intent>` to Android `AndroidManifest.xml` (`<queries>`)
4. Update this document

---

## Architecture Flow

```
User: "Start a run"
  -> LLM selects open_external_app(app="strava", action="record")
  -> DeepLinkServer resolves via DeepLinkRegistry -> strava://record
  -> ToolResult(data={client_action: "open_url", url: "strava://record", ...})
  -> Orchestrator extracts client_action into AgentResponse
  -> WebSocket sends {type: "message", content: "...", client_action: {...}}
  -> Flutter ChatMessage.clientAction parsed
  -> DeepLinkLauncher.executeDeepLink("strava://record", fallback: "https://...")
  -> url_launcher opens Strava app (or fallback web URL)
```
