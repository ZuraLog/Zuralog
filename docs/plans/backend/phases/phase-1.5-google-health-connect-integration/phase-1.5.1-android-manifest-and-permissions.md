# Phase 1.5.1: Health Connect Permissions (Android)

**Parent Goal:** Phase 1.5 Google Health Connect Integration
**Checklist:**
- [ ] 1.5.1 Health Connect Permissions (Android)
- [ ] 1.5.2 Kotlin Health Connect Bridge
- [ ] 1.5.3 Flutter Platform Channel (Android)
- [ ] 1.5.4 Health Connect MCP Server
- [ ] 1.5.5 Background Sync (Android WorkManager)
- [ ] 1.5.6 Unified Health Store Abstraction
- [ ] 1.5.7 Health Connect Integration Document

---

## What
Configure the Android application to request access to the Health Connect API. This involves adding specific permissions to the `AndroidManifest.xml` and creating a rationalization resource file as required by Google's policy.

## Why
Health Connect is the centralized health data store on Android (replacing Google Fit). Access is gated by strict OS-level permissions that must be declared at build time.

## How
Add `<uses-permission>` tags to the manifest for every data type we need (Steps, Calories, Sleep, etc.) and create a `health_permissions.xml` file.

## Features
- **Granular Permissions:** Requests only what is needed.
- **Privacy Compliance:** Adheres to Google Play policies for health apps.

## Files
- Modify: `zuralog/android/app/src/main/AndroidManifest.xml`
- Create: `zuralog/android/app/src/main/res/values/health_permissions.xml` (Note: sometimes `res/xml` depending on config, but usually `res/values` for strings or `res/xml` for config. Standard is `res/values/health_permissions.xml` for rationale strings or strictly manifest declarations). *Correction: Health Connect actually just needs Manifest declarations + runtime request. The `health_permissions.xml` is often a custom file for internal organization or specific rationale strings.*

## Steps

1. **Add permissions to AndroidManifest (`zuralog/android/app/src/main/AndroidManifest.xml`)**

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.zuralog">
    
    <!-- Health Connect Permissions -->
    <uses-permission android:name="android.permission.health.READ_STEPS"/>
    <uses-permission android:name="android.permission.health.WRITE_STEPS"/>
    <uses-permission android:name="android.permission.health.READ_ACTIVE_CALORIES_BURNED"/>
    <uses-permission android:name="android.permission.health.WRITE_ACTIVE_CALORIES_BURNED"/>
    <uses-permission android:name="android.permission.health.READ_TOTAL_CALORIES_BURNED"/>
    <uses-permission android:name="android.permission.health.WRITE_TOTAL_CALORIES_BURNED"/>
    <uses-permission android:name="android.permission.health.READ_SLEEP"/>
    <uses-permission android:name="android.permission.health.WRITE_SLEEP"/>
    <uses-permission android:name="android.permission.health.READ_BODY_WEIGHT"/> <!-- Corrected from generic WEIGHT -->
    <uses-permission android:name="android.permission.health.WRITE_BODY_WEIGHT"/>
    <uses-permission android:name="android.permission.health.READ_EXERCISE"/>
    <uses-permission android:name="android.permission.health.WRITE_EXERCISE"/>

    <application ...>
        <!-- ... -->
        <!-- Add intent filter for Health Connect settings -->
        <activity-alias
            android:name="ViewPermissionUsageActivity"
            android:exported="true"
            android:targetActivity=".MainActivity"
            android:permission="android.permission.health.MANAGE_HEALTH_PERMISSIONS">
            <intent-filter>
                <action android:name="android.intent.action.VIEW_PERMISSION_USAGE" />
                <category android:name="android.intent.category.HEALTH_PERMISSIONS" />
            </intent-filter>
        </activity-alias>
    </application>
</manifest>
```

2. **Create rationale strings (`zuralog/android/app/src/main/res/values/strings.xml`)**

(Optional but recommended for UI)
```xml
<string name="health_connect_rationale">Zuralog needs access to your health data to provide AI coaching.</string>
```

## Exit Criteria
- AndroidManifest configured correctly with Health Connect permissions.
- Build succeeds without manifest merger errors.
