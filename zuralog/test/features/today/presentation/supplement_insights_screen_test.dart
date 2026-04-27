import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/today/data/mock_today_repository.dart';
import 'package:zuralog/features/today/data/today_repository.dart';
import 'package:zuralog/features/today/domain/supplement_insight.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/features/today/presentation/log_screens/supplement_insights_screen.dart';

Widget _buildScreen() {
  return ProviderScope(
    overrides: [
      todayRepositoryProvider.overrideWithValue(const MockTodayRepository()),
    ],
    child: const MaterialApp(home: SupplementInsightsScreen()),
  );
}

void main() {
  testWidgets('shows insight cards when data is available', (tester) async {
    await tester.pumpWidget(_buildScreen());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // MockTodayRepository returns 'Sleep' as first metric label
    expect(find.text('Sleep'), findsOneWidget);
    expect(
      find.text('Your sleep is 12% better when you take your stack.'),
      findsOneWidget,
    );
  });

  testWidgets('shows not-enough-data state when hasEnoughData is false', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          todayRepositoryProvider.overrideWithValue(const MockTodayRepository()),
          insightsProvider.overrideWith((_) async => SupplementInsightsResult.empty),
        ],
        child: const MaterialApp(home: SupplementInsightsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Not enough data yet'), findsOneWidget);
  });

  testWidgets('shows loading indicator initially', (tester) async {
    await tester.pumpWidget(_buildScreen());
    // Before the future resolves, a loading indicator must be visible
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // Drain remaining timers so the test doesn't leak a pending Timer.
    await tester.pump(const Duration(milliseconds: 500));
  });
}
