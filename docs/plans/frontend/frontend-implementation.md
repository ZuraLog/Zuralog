# Frontend Implementation Plan (Phase 2)

> **For Claude:** Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transform the functional "Developer UI" (Phase 1 test harness) into a beautiful, production-ready Flutter app by wiring up the designs from `docs/stitch/` and connecting to the Cloud Brain backend.

**Entry Criteria:** Phase 1 (Backend MVP) is 100% complete and verified.

**Philosophy:** "Design first, then wire." Replace the raw test harness with beautiful, styled widgets while keeping all Phase 1 logic intact.

---

## Phase 2.1: Design System Setup

> **Reference:** Review `view-design.md` for color palette and typography specs.

**Goal:** Establish the design tokens, theme, and reusable component library.

**Depends On:** Phase 1.1 (Flutter project setup)  
**Estimated Duration:** 2-3 days

### 2.1.1 Theme Configuration

**Files:**
- Create: `life_logger/lib/core/theme/app_theme.dart`
- Create: `life_logger/lib/core/theme/app_colors.dart`
- Create: `life_logger/lib/core/theme/app_typography.dart`

**Steps:**

1. **Create `app_colors.dart`**

```dart
import 'package:flutter/material.dart';

class AppColors {
  // Primary - Sage Green
  static const Color primary = Color(0xFFCEE0B8);
  static const Color primaryDark = Color(0xFFB0C498);
  
  // Background
  static const Color backgroundLight = Color(0xFFFFFFFF);
  static const Color backgroundDark = Color(0xFF191D15);
  
  // Text
  static const Color textMain = Color(0xFF151613);
  static const Color textSecondary = Color(0xFF6B7280);
  
  // Surface
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1C1C1E);
  
  // Accent
  static const Color accent = Color(0xFFE07A5F);
}
```

2. **Create `app_theme.dart`**

```dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.textSecondary,
      surface: AppColors.surfaceLight,
    ),
    scaffoldBackgroundColor: AppColors.backgroundLight,
    // ... more theme config
  );
  
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.textSecondary,
      surface: AppColors.surfaceDark,
    ),
    scaffoldBackgroundColor: AppColors.backgroundDark,
  );
}
```

**Exit Criteria:** Theme compiles, light/dark modes work.

---

### 2.1.2 Reusable Components

**Files:**
- Create: `life_logger/lib/shared/widgets/primary_button.dart`
- Create: `life_logger/lib/shared/widgets/glass_card.dart`
- Create: `life_logger/lib/shared/widgets/animated_text_field.dart`

**Steps:**

1. **Create `primary_button.dart`**

```dart
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: MaterialButton(
        onPressed: isLoading ? null : onPressed,
        child: isLoading ? const CircularProgressIndicator() : Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
```

2. **Create `glass_card.dart`**

```dart
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }
}
```

**Exit Criteria:** Components compile and match view-design.md specs.

---

## Phase 2.2: Screen Implementation (Wiring)

> **Reference Views:**
> - `../../stitch/life_logger_welcome_and_authentication/`
> - `../../stitch/life_logger_coach_chat/`
> - `../../stitch/life_logger_dashboard_variant_1/`
> - `../../stitch/life_logger_dashboard_variant_2/`
> - `../../stitch/integrations_hub_active_states/`
> - `../../stitch/integrations_hub_disconnect_modal/`

**Goal:** Replace test harness screens with beautiful Stitch designs and connect to Phase 1 repositories.

**Depends On:** Phase 2.1 (Design System)  
**Estimated Duration:** 5-7 days

### 2.2.1 Welcome & Auth Screen

**Reference:** `../../stitch/life_logger_welcome_and_authentication/`

**Files:**
- Create: `life_logger/lib/features/auth/presentation/welcome_screen.dart`
- Modify: `life_logger/lib/app.dart` (update router)

**Steps:**

1. **Create welcome screen matching Stitch design**

```dart
class WelcomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              // Logo with glow effect
              _buildLogo(),
              const SizedBox(height: 24),
              // Title & Subtitle
              Text('Life Logger', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text('Your journey to better health starts here.', textAlign: TextAlign.center),
              const Spacer(),
              // Auth Buttons
              _buildAppleSignIn(),
              const SizedBox(height: 12),
              _buildGoogleSignIn(),
              const SizedBox(height: 12),
              TextButton(onPressed: () {}, child: const Text('Log in with Email')),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildLogo() {
    return Container(
      width: 96, height: 96,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 24)],
      ),
      child: const Icon(Icons.monitor_heart, size: 48),
    );
  }
}
```

2. **Wire to AuthRepository (Phase 1)**

```dart
ElevatedButton(
  onPressed: () async {
    final authRepo = ref.read(authRepositoryProvider);
    await authRepo.loginWithApple();
  },
  child: const Text('Continue with Apple'),
)
```

**Exit Criteria:** Welcome screen renders matching Stitch design, auth buttons work.

---

### 2.2.2 Coach Chat Screen

**Reference:** `../../stitch/life_logger_coach_chat/`

**Files:**
- Create: `life_logger/lib/features/chat/presentation/chat_screen.dart`
- Create: `life_logger/lib/features/chat/presentation/widgets/message_bubble.dart`
- Create: `life_logger/lib/features/chat/presentation/widgets/chat_input.dart`
- Create: `life_logger/lib/features/chat/presentation/widgets/activity_widget.dart`

**Steps:**

1. **Create chat screen with header**

```dart
class ChatScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Coach'),
            Container(
              width: 10, height: 10,
              decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.more_horiz), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList(ref)),
          const ChatInput(),
        ],
      ),
    );
  }
}
```

2. **Create message bubble (matches Stitch)**

```dart
class MessageBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : Colors.grey[200],
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? const Radius.circular(4) : null,
            bottomLeft: !isUser ? const Radius.circular(4) : null,
          ),
        ),
        child: Text(message),
      ),
    );
  }
}
```

3. **Connect to ChatRepository (Phase 1)**

```dart
void _sendMessage(String text) async {
  final chatRepo = ref.read(chatRepositoryProvider);
  chatRepo.sendMessage(text);
}
```

4. **Create activity widget for rich content**

```dart
class ActivityWidget extends StatelessWidget {
  final String activityName;
  final double distanceKm;
  final Duration duration;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 40)],
      ),
      child: Column(
        children: [
          // Map placeholder
          Container(height: 160, color: Colors.grey[300]),
          // Stats row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStat('Distance', '${distanceKm.toStringAsFixed(2)} km'),
                _buildStat('Time', _formatDuration(duration)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

**Exit Criteria:** Chat screen renders matching Stitch design, messages send/receive via WebSocket.

---

### 2.2.3 Dashboard Screen

**Reference:** 
- `../../stitch/life_logger_dashboard_variant_1/`
- `../../stitch/life_logger_dashboard_variant_2/`

**Files:**
- Create: `life_logger/lib/features/dashboard/presentation/dashboard_screen.dart`
- Create: `life_logger/lib/features/dashboard/presentation/widgets/insight_card.dart`
- Create: `life_logger/lib/features/dashboard/presentation/widgets/health_rings.dart`
- Create: `life_logger/lib/features/dashboard/presentation/widgets/integrations_rail.dart`
- Create: `life_logger/lib/features/dashboard/presentation/widgets/metrics_grid.dart`

**Steps:**

1. **Create dashboard with insight card**

```dart
class DashboardScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildInsightCard(ref)),
            SliverToBoxAdapter(child: _buildHealthRings()),
            SliverToBoxAdapter(child: _buildIntegrationsRail()),
            SliverToBoxAdapter(child: _buildMetricsGrid()),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInsightCard(WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.3), Colors.white]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        "You're 200 calories over your target, but your run balanced it out.",
        style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textMain),
      ),
    );
  }
}
```

2. **Connect to AnalyticsRepository (Phase 1)**

```dart
final summary = await ref.read(analyticsRepositoryProvider).getDailySummary(DateTime.now());
```

**Exit Criteria:** Dashboard shows insight card, health rings, integrations rail, metrics grid.

---

### 2.2.4 Integrations Hub Screen

**Reference:** 
- `../../stitch/integrations_hub_active_states/`
- `../../stitch/integrations_hub_disconnect_modal/`

**Files:**
- Create: `life_logger/lib/features/integrations/presentation/integrations_screen.dart`
- Create: `life_logger/lib/features/integrations/presentation/widgets/integration_tile.dart`
- Create: `life_logger/lib/features/integrations/presentation/widgets/disconnect_modal.dart`

**Steps:**

1. **Create integrations list**

```dart
class IntegrationsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Integrations')),
      body: ListView(
        children: [
          _buildSection('Connected', [
            _buildIntegrationTile('Strava', 'Synced 5m ago', true),
            _buildIntegrationTile('Apple Health', 'Synced 2m ago', true),
          ]),
          _buildSection('Available', [
            _buildIntegrationTile('Fitbit', 'Not connected', false),
            _buildIntegrationTile('Oura Ring', 'Not connected', false),
          ]),
        ],
      ),
    );
  }
  
  Widget _buildIntegrationTile(String name, String status, bool isConnected) {
    return ListTile(
      leading: Icon(_getIconForApp(name)),
      title: Text(name),
      subtitle: Text(status),
      trailing: Switch(
        value: isConnected,
        onChanged: (value) => value ? _connect(name) : _showDisconnectModal(name),
      ),
    );
  }
}
```

2. **Connect to OAuthRepository (Phase 1)**

```dart
void _connect(String provider) async {
  final oauthRepo = ref.read(oauthRepositoryProvider);
  await oauthRepo.connect(provider);
}
```

**Exit Criteria:** Integrations list shows connected/available apps, toggle switches work.

---

### 2.2.5 Settings Screen

**Files:**
- Create: `life_logger/lib/features/settings/presentation/settings_screen.dart`

**Steps:**

1. **Create settings with subscription check**

```dart
class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(leading: const Icon(Icons.person), title: const Text('Profile'), onTap: () {}),
          ListTile(leading: const Icon(Icons.palette), title: const Text('Appearance'), onTap: () {}),
          ListTile(leading: const Icon(Icons.favorite), title: const Text('Coach Persona'), onTap: () {}),
          ListTile(leading: const Icon(Icons.lock), title: const Text('Privacy'), onTap: () {}),
          ListTile(leading: const Icon(Icons.star), title: const Text('Subscription'), onTap: () {}),
        ],
      ),
    );
  }
}
```

**Exit Criteria:** Settings screen with all sections.

---

## Phase 2.3: Navigation & Polish

**Goal:** Wire up routing and add micro-interactions.

**Depends On:** Phase 2.2 (Screens)  
**Estimated Duration:** 2-3 days

### 2.3.1 Router Setup

**Files:**
- Modify: `life_logger/lib/app.dart`

**Steps:**

1. **Configure go_router**

```dart
final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, __) => const WelcomeScreen()),
    GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
    GoRoute(path: '/chat', builder: (_, __) => const ChatScreen()),
    GoRoute(path: '/integrations', builder: (_, __) => const IntegrationsScreen()),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
  ],
);
```

**Exit Criteria:** Navigation works between all screens.

---

### 2.3.2 Animations & Transitions

**Files:**
- Create: `life_logger/lib/core/theme/page_transitions.dart`

**Steps:**

1. **Add slide transitions**

```dart
class SlideTransition extends CustomTransitionPage {
  SlideTransition({required super.child})
      : super(
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(animation),
            child: child,
          );
        },
      );
}
```

**Exit Criteria:** Smooth page transitions.

---

### 2.3.3 Loading States & Haptics

**Steps:**

1. **Add shimmer effects**

```dart
class ShimmerLoading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.grey[300]!, Colors.grey[100]!]),
      ),
    );
  }
}
```

2. **Add haptic feedback**

```dart
import 'package:flutter/services.dart';

void _onSuccess() {
  HapticFeedback.mediumImpact();
}
```

**Exit Criteria:** Loading states show shimmer, actions trigger haptics.

---

## Phase 2.4: End-to-End Verification

**Goal:** Verify all screens work together and connect to Phase 1 backend.

**Depends On:** Phase 2.3 (Navigation)  
**Estimated Duration:** 1-2 days

### 2.4.1 E2E Flow Tests

**Steps:**

1. **Test auth flow:** Welcome → Login → Dashboard
2. **Test integration flow:** Dashboard → Connect Strava → OAuth → Return
3. **Test chat flow:** Dashboard → Chat → Send message → Receive response
4. **Test deep link flow:** Chat → "Start a run" → Opens Strava

**Exit Criteria:** All E2E flows work.

---

### 2.4.2 Final Exit Criteria

- [ ] Welcome screen matches `../../stitch/life_logger_welcome_and_authentication/`
- [ ] Chat screen matches `../../stitch/life_logger_coach_chat/`
- [ ] Dashboard matches `../../stitch/life_logger_dashboard_variant_1/` or `variant_2/`
- [ ] Integrations hub matches `../../stitch/integrations_hub_active_states/`
- [ ] All Phase 1 repositories connected and working
- [ ] Navigation flows work (go_router)
- [ ] Animations and haptics working
- [ ] Ready for beta testing

---

## Post-Frontend Tasks

Once Phase 2 is complete:
1. Run `flutter build ios --release`
2. Run `flutter build apk --release`
3. Test on physical devices
4. Submit to TestFlight / Google Play internal testing

---

**End of Frontend Implementation Plan**
