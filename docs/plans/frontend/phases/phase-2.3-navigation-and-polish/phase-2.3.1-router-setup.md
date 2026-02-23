# Phase 2.3.1: Router Setup

**Parent Goal:** Phase 2.3 Navigation & Polish
**Checklist:**
- [x] 2.3.1 Router Setup
- [ ] 2.3.2 Animations & Transitions
- [ ] 2.3.3 Loading States & Haptics

---

## What
Set up `go_router` to handle navigation between screens, including deep link parameters and auth guards.

## Why
Declarative routing is essential for Deep Links (e.g., opening a specific chat message from a notification) and managing the "Auth Gate".

## How
Use `go_router` with a `Riverpod` provider to listen to Auth State changes.

## Features
- **Auth Guard:** Automatically redirects unauthenticated users to `/welcome`.
- **ShellRoute:** Persist the Bottom Navigation Bar across main tabs (Dashboard, Chat, Integrations, Settings).
- **Deep Linking:** Handle URLs like `zuralog://chat?msg_id=123`.

## Files
- Modify: `zuralog/lib/core/router/app_router.dart`

## Steps

1. **Create Router (`zuralog/lib/core/router/app_router.dart`)**

```dart
final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authRepositoryProvider);
  
  return GoRouter(
    initialLocation: '/welcome',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isGoingToLogin = state.subloc == '/welcome';
      
      if (!isLoggedIn && !isGoingToLogin) return '/welcome';
      if (isLoggedIn && isGoingToLogin) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/welcome', builder: (...) => WelcomeScreen()),
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
           GoRoute(path: '/dashboard', builder: (...) => DashboardScreen()),
           GoRoute(path: '/chat', builder: (...) => ChatScreen()),
           // ...
        ]
      )
    ],
  );
});
```

## Exit Criteria
- App starts at Welcome.
- Login redirects to Dashboard.
- Browser URL updates (on Web).
