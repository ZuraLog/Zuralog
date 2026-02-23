/// Zuralog Settings — Settings Screen Tests.
///
/// Smoke-tests [SettingsScreen] with overridden Riverpod providers so that
/// no real network or authentication requests are made. Verifies key UI
/// elements: rendering, user email display, logout button, and section headers.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/auth/domain/auth_state.dart';
import 'package:zuralog/features/settings/presentation/settings_screen.dart';
import 'package:zuralog/features/subscription/domain/subscription_providers.dart';
import 'package:zuralog/features/subscription/domain/subscription_state.dart';

// ── Fixtures ──────────────────────────────────────────────────────────────────

/// Test email address for provider overrides.
const String _kTestEmail = 'test@example.com';

// ── Harness ───────────────────────────────────────────────────────────────────

/// Builds the test harness with mocked providers.
///
/// [navigatedPaths] collects any path that GoRouter navigates to during
/// the test so assertions can verify post-logout navigation.
Widget _buildHarness({List<String>? navigatedPaths, bool isPremium = false}) {
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(
        path: '/settings',
        builder: (context, _) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, _) => _Stub(name: 'welcome', paths: navigatedPaths),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      // Provide the test email directly via the state provider.
      userEmailProvider.overrideWith((ref) => _kTestEmail),
      // Auth state: authenticated.
      authStateProvider.overrideWith(() => _FakeAuthNotifier()),
      // Subscription: free plan by default.
      subscriptionProvider.overrideWith(
        () => _FakeSubscriptionNotifier(isPremium: isPremium),
      ),
      isPremiumProvider.overrideWith((ref) => isPremium),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
      ),
    ),
  );
}

/// Minimal stub widget that records the route name in [paths].
class _Stub extends StatelessWidget {
  const _Stub({required this.name, this.paths});
  final String name;
  final List<String>? paths;

  @override
  Widget build(BuildContext context) {
    paths?.add(name);
    return Text('stub:$name');
  }
}

/// A fake [AuthStateNotifier] that does not call any real repository.
class _FakeAuthNotifier extends AuthStateNotifier {
  @override
  AuthState build() => AuthState.authenticated;

  @override
  Future<void> logout() async {
    state = AuthState.unauthenticated;
  }
}

/// A fake [SubscriptionNotifier] with a configurable premium flag.
class _FakeSubscriptionNotifier extends SubscriptionNotifier {
  _FakeSubscriptionNotifier({required this.isPremium});

  /// Whether to simulate a premium subscription.
  final bool isPremium;

  @override
  SubscriptionState build() {
    return SubscriptionState(
      tier: isPremium ? SubscriptionTier.pro : SubscriptionTier.free,
    );
  }
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  group('SettingsScreen', () {
    testWidgets('smoke test — renders without throwing', (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows the Settings app bar title', (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump();
      expect(find.text('Settings'), findsAtLeast(1));
    });

    testWidgets('shows user email in the header', (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump();
      // Email now appears twice in the header: once as the name fallback
      // (no profile loaded → aiName falls back to email) and once as the
      // secondary email label below the name.
      expect(find.text(_kTestEmail), findsAtLeast(1));
    });

    testWidgets('shows Appearance section header', (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump();
      expect(find.text('Appearance'), findsOneWidget);
    });

    testWidgets('shows Logout button', (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump();
      // Scroll to the bottom where the logout button lives.
      await tester.scrollUntilVisible(find.text('Log Out'), 100);
      expect(find.text('Log Out'), findsOneWidget);
    });

    testWidgets('shows Subscription section header', (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump();
      expect(find.text('Subscription'), findsOneWidget);
    });

    testWidgets('shows Free Plan text when not premium', (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump();
      expect(find.text('Free Plan'), findsOneWidget);
    });

    testWidgets('shows Coach Persona section header', (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump();
      expect(find.text('Coach Persona'), findsOneWidget);
    });

    testWidgets('shows Data & Privacy section header', (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump();
      expect(find.text('Data & Privacy'), findsOneWidget);
    });
  });
}
