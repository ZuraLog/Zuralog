# Phase 2.2.4: Integrations Hub Screen

**Parent Goal:** Phase 2.2 Screen Implementation (Wiring)
**Checklist:**
- [x] 2.2.1 Welcome & Auth Screen
- [x] 2.2.2 Coach Chat Screen
- [x] 2.2.3 Dashboard Screen
- [x] 2.2.4 Integrations Hub Screen
- [ ] 2.2.5 Settings Screen

---

## What
A screen where users can connect external apps (Strava, Google Fit) and grant permissions.

## Why
Transparency and control. Users need to know what data we are reading.

## How
List items with toggle switches calling `OAuthRepository.connect()`.

## Features
- **Status Indicators:** "Connected" (Green), "Error" (Red), "Syncing" (Spinner).
- **Webview Flow:** Strava OAuth opens in-app webview or external browser (via `deep_link_handler`).

## Files
- Create: `life_logger/lib/features/integrations/presentation/integrations_hub_screen.dart`
- Create: `life_logger/lib/features/integrations/presentation/widgets/integration_tile.dart`

## Steps

1. **Create Hub Screen (`life_logger/lib/features/integrations/presentation/integrations_hub_screen.dart`)**

```dart
class IntegrationsHubScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final integrations = ref.watch(integrationsProvider);
    
    return Scaffold(
      appBar: AppBar(title: Text("Connections")),
      body: ListView(
        children: [
            IntegrationTile(
                name: "Apple Health",
                icon: Icons.health_and_safety,
                isConnected: integrations.appleHealth,
                onToggle: (val) => ref.read(healthRepo).requestPermissions(),
            ),
            IntegrationTile(
                name: "Strava",
                icon: Icons.directions_run,
                isConnected: integrations.strava,
                onToggle: (val) => ref.read(oauthRepo).connectStrava(),
            ),
        ],
      ),
    );
  }
}
```

## Exit Criteria
- Can toggle Strava connection (launches OAuth).
- Can toggle HealthKit permissions.
