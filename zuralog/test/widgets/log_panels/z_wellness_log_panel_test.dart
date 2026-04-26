import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/today/data/mock_today_repository.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/log_panels/z_wellness_log_panel.dart';

void main() {
  Widget buildPanel() => ProviderScope(
        overrides: [
          todayRepositoryProvider.overrideWithValue(MockTodayRepository()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ZWellnessLogPanel(
              onSave: (_) async {},
              onBack: () {},
            ),
          ),
        ),
      );

  testWidgets('shows Speak and Write options on open', (tester) async {
    await tester.pumpWidget(buildPanel());
    await tester.pump();
    expect(find.text('Speak'), findsOneWidget);
    expect(find.text('Write'), findsOneWidget);
    expect(find.text('Quick check-in'), findsOneWidget);
  });

  testWidgets('tapping Quick check-in shows face selectors', (tester) async {
    await tester.pumpWidget(buildPanel());
    await tester.pump();
    await tester.tap(find.text('Quick check-in'));
    await tester.pump();
    expect(find.text('Mood'), findsOneWidget);
    expect(find.text('Energy'), findsOneWidget);
    expect(find.text('Stress'), findsOneWidget);
  });
}
