import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/today/domain/log_summary_models.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/health/z_log_ring_widget.dart';

void main() {
  group('ZLogRingWidget', () {
    testWidgets('renders without error in loading state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Override to avoid real network calls (flutter_secure_storage)
            // leaving pending timers that outlive the test.
            todayLogSummaryProvider.overrideWith(
              (ref) async => TodayLogSummary.empty,
            ),
            userLoggedTypesProvider.overrideWith(
              (ref) async => const <String>{},
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ZLogRingWidget(onTap: () {}),
            ),
          ),
        ),
      );
      expect(find.byType(ZLogRingWidget), findsOneWidget);
    });

    testWidgets('shows Start logging text when 0 types ever logged', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            logRingProvider.overrideWith(
              (ref) async => const LogRingState(loggedCount: 0, totalCount: 0),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ZLogRingWidget(onTap: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Start'), findsOneWidget);
    });

    testWidgets('shows logged/total text when types exist', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            logRingProvider.overrideWith(
              (ref) async => const LogRingState(loggedCount: 3, totalCount: 9),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ZLogRingWidget(onTap: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('3 / 9'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            logRingProvider.overrideWith(
              (ref) async => const LogRingState(loggedCount: 0, totalCount: 0),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ZLogRingWidget(onTap: () => tapped = true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ZLogRingWidget));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });
}
