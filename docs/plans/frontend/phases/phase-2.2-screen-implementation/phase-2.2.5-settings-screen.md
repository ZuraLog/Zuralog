# Phase 2.2.5: Settings Screen

**Parent Goal:** Phase 2.2 Screen Implementation (Wiring)
**Checklist:**
- [x] 2.2.1 Welcome & Auth Screen
- [x] 2.2.2 Coach Chat Screen
- [x] 2.2.3 Dashboard Screen
- [x] 2.2.4 Integrations Hub Screen
- [x] 2.2.5 Settings Screen

---

## What
Screen for managing user profile, subscription, theme, and logging out.

## Why
Standard app requirement. Also the place to upsell "Pro".

## How
Standard List View.

## Features
- **Profile Edit:** Name, Goal setting.
- **Subscription:** Shows current tier and "Manage Subscription" button (RevenueCat).
- **Theme Toggle:** Dark/Light/System.
- **Logout:** Clears tokens and redirects to Welcome.

## Files
- Create: `zuralog/lib/features/settings/presentation/settings_screen.dart`

## Steps

1. **Create Settings Screen (`zuralog/lib/features/settings/presentation/settings_screen.dart`)**

```dart
class SettingsScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    
    return Scaffold(
      appBar: AppBar(title: Text("Settings")),
      body: ListView(
        children: [
           UserHeader(user: user),
           ListTile(
               title: Text("Subscription"),
               subtitle: Text(user.isPremium ? "Pro" : "Free"),
               onTap: () => _openPaywall(context),
           ),
           SwitchListTile(
               title: Text("Dark Mode"),
               value: ref.watch(themeProvider).isDark,
               onChanged: (val) => ref.read(themeProvider.notifier).toggle(),
           ),
           ListTile(
               title: Text("Log Out"),
               textColor: Colors.red,
               onTap: () => ref.read(authRepo).logout(),
           ),
        ],
      ),
    );
  }
}
```

## Exit Criteria
- Logout works.
- Theme toggle works.
