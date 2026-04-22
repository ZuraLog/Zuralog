/// Tests for [TrailerScreen] — renders logo, slide 1 headline, 3 page dots, and Get Started.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/onboarding/presentation/trailer/trailer_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders logo wordmark, first headline, and Get started button',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(path: '/onboarding', builder: (_, __) => const TrailerScreen()),
        GoRoute(path: '/welcome', builder: (_, __) => const _StubWelcome()),
      ],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        hasSeenOnboardingProvider.overrideWith((ref) async => false),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    // Let initial animations register + drain the slide's 200ms
    // Future.delayed headline-fade timer. Don't pumpAndSettle — the 20s
    // contour-accent animation never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('ZuraLog'), findsOneWidget);
    expect(find.text("Know why you're tired."), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);

    // Replace the tree so TrailerScreen.dispose() runs and cancels the
    // 5s auto-advance Timer before the framework's pending-timer check.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tapping Get started navigates to /welcome', (tester) async {
    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(path: '/onboarding', builder: (_, __) => const TrailerScreen()),
        GoRoute(path: '/welcome', builder: (_, __) => const _StubWelcome()),
      ],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        hasSeenOnboardingProvider.overrideWith((ref) async => false),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pump();

    await tester.tap(find.text('Get started'));
    // Pump a few times so the async SharedPreferences write + navigation
    // complete. Avoid pumpAndSettle because of the long-running animations.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('STUB_WELCOME'), findsOneWidget);
  });
}

class _StubWelcome extends StatelessWidget {
  const _StubWelcome();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('STUB_WELCOME')));
}
