# Phase 1.12.4: Harness: Deep Link Test

**Parent Goal:** Phase 1.12 Autonomous Actions & Deep Linking
**Checklist:**
- [x] 1.12.1 Deep Link MCP Tools
- [x] 1.12.2 Edge Agent Deep Link Executor
- [x] 1.12.3 Autonomous Action Response Format
- [x] 1.12.4 Harness: Deep Link Test
- [ ] 1.12.5 Integration Document

---

## What
Add controls to the Developer UI Harness to manually test deep link launching logic.

## Why
Deep links often fail due to OS configuration (AndroidManifest schemes, Info.plist queries). We need to verify these before relying on AI to trigger them.

## How
Add buttons for each key app (Strava, CalAI) in the Harness.

## Features
- **Status Feedback:** "Launched" vs "App not found".

## Files
- Modify: `zuralog/lib/features/harness/harness_screen.dart`

## Steps

1. **Add deep link tests (`zuralog/lib/features/harness/harness_screen.dart`)**

```dart
// In build()
ElevatedButton(
  onPressed: () async {
    // Test Strava Record
    await DeepLinkLauncher.executeDeepLink('strava://record');
  },
  child: const Text('Open Strava (Record)'),
),
ElevatedButton(
  onPressed: () async {
    // Test CalAI Camera
    await DeepLinkLauncher.executeDeepLink('calai://camera');
  },
  child: const Text('Open CalAI (Camera)'),
),
```

## Exit Criteria
- Buttons successfully launch installed apps.
