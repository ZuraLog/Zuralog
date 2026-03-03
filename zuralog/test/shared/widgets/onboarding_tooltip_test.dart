import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zuralog/shared/widgets/onboarding_tooltip.dart';
import 'package:zuralog/shared/widgets/onboarding_tooltip_provider.dart';

void main() {
  setUp(() {
    // Ensure a clean SharedPreferences state for every test.
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpTooltip(
    WidgetTester tester, {
    Map<String, Object> prefs = const {},
    bool tooltipsEnabled = true,
    bool alreadySeen = false,
  }) async {
    SharedPreferences.setMockInitialValues({
      'tooltips_enabled': tooltipsEnabled,
      if (alreadySeen) 'tooltip_seen.today_feed.health_score': true,
      ...prefs,
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: OnboardingTooltip(
              screenKey: 'today_feed',
              tooltipKey: 'health_score',
              message: 'This is your health score.',
              child: const Text('Child Widget'),
            ),
          ),
        ),
      ),
    );
    // Allow async providers to resolve.
    await tester.pumpAndSettle();
  }

  group('OnboardingTooltip — first visit', () {
    testWidgets('shows tooltip bubble on first visit', (tester) async {
      await pumpTooltip(tester);

      expect(find.text('This is your health score.'), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);
      expect(find.text('Child Widget'), findsOneWidget);
    });

    testWidgets('dismissing tooltip hides it', (tester) async {
      await pumpTooltip(tester);

      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();

      expect(find.text('This is your health score.'), findsNothing);
      expect(find.text('Got it'), findsNothing);
      expect(find.text('Child Widget'), findsOneWidget);
    });
  });

  group('OnboardingTooltip — already seen', () {
    testWidgets('does not show when already seen', (tester) async {
      await pumpTooltip(tester, alreadySeen: true);

      expect(find.text('This is your health score.'), findsNothing);
      expect(find.text('Got it'), findsNothing);
      expect(find.text('Child Widget'), findsOneWidget);
    });
  });

  group('OnboardingTooltip — global toggle disabled', () {
    testWidgets('does not show when tooltips are disabled', (tester) async {
      await pumpTooltip(tester, tooltipsEnabled: false);

      expect(find.text('This is your health score.'), findsNothing);
      expect(find.text('Child Widget'), findsOneWidget);
    });
  });

  group('TooltipSeenNotifier — reset', () {
    testWidgets('reset re-enables dismissed tooltips', (tester) async {
      SharedPreferences.setMockInitialValues({
        'tooltip_seen.today_feed.health_score': true,
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  final notifier = ref.read(tooltipSeenProvider.notifier);
                  return TextButton(
                    onPressed: () => notifier.reset(),
                    child: const Text('Reset'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(Consumer)),
      );
      final seenMap = container.read(tooltipSeenProvider).valueOrNull ?? {};
      expect(seenMap.values.every((v) => !v), isTrue);
    });
  });
}
