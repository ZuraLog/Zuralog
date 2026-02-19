# Phase 1.4.1: HealthKit Entitlements & Permissions (iOS)

**Parent Goal:** Phase 1.4 Apple HealthKit Integration
**Checklist:**
- [ ] 1.4.1 HealthKit Entitlements & Permissions (iOS)
- [ ] 1.4.2 Swift HealthKit Bridge
- [ ] 1.4.3 Flutter Platform Channel
- [ ] 1.4.4 HealthKit MCP Server (Cloud Brain)
- [ ] 1.4.5 Edge Agent Health Repository
- [ ] 1.4.6 Background Observation
- [ ] 1.4.7 Harness Test: HealthKit Integration
- [ ] 1.4.8 Apple Health Integration Document

---

## What
Configure the iOS application to request access to HealthKit data. This involves enabling the "HealthKit" capability in Xcode, adding privacy usage descriptions to `Info.plist`, and enabling background delivery permissions.

## Why
Apple has strict privacy controls for health data. Without these entitlements and descriptions, the app will crash instantly when trying to access HealthKit. Background delivery is essential for the "passive tracking" AI feature.

## How
We will modify the `Runner.entitlements` and `Info.plist` XML files directly (or via Xcode).

## Features
- **Privacy Compliance:** Explicitly tells the user *why* we need their data.
- **Background Access:** Allows the app to wake up and sync data even when closed.

## Files
- Modify: `life_logger/ios/Runner/Runner.entitlements`
- Modify: `life_logger/ios/Runner/Info.plist`

## Steps

1. **Enable HealthKit capability**

In Xcode (manual step usually, but here is the file representation):
- Open `life_logger/ios/Runner.xcworkspace`
- Select Runner target → Signing & Capabilities
- Add HealthKit capability
- Check "Background Modes" → "Background fetch"
- Check "Background Modes" → "Background processing"

2. **Configure entitlements file (`life_logger/ios/Runner/Runner.entitlements`)**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.healthkit</key>
    <true/>
    <key>com.apple.developer.healthkit.access</key>
    <array/>
    <key>com.apple.developer.healthkit.background-delivery</key>
    <true/>
</dict>
</plist>
```

3. **Configure Info.plist permissions (`life_logger/ios/Runner/Info.plist`)**

```xml
<key>NSHealthShareUsageDescription</key>
<string>Life Logger needs access to your health data (steps, workouts, nutrition) to provide personalized AI coaching and track your fitness goals.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>Life Logger needs to write health data (like workouts and nutrition) to Apple Health based on your requests.</string>
```

## Exit Criteria
- HealthKit capability enabled.
- Entitlements configured for background delivery.
- Usage descriptions added to Info.plist.
