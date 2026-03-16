import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/today/domain/log_summary_models.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/log_panels/z_steps_log_panel.dart';

final _todayIso = DateTime.now().toUtc().toIso8601String();

Widget _wrap(
  Widget child, {
  Map<String, dynamic> latestSteps = const {},
  List<DailyGoal> goals = const [],
}) {
  return ProviderScope(
    overrides: [
      stepsLogModeProvider.overrideWith(() => _StubModeNotifier()),
      todayLogSummaryProvider.overrideWith(
        (ref) async => TodayLogSummary.empty,
      ),
      latestLogValuesProvider(latestLogValuesKey(const {'steps'})).overrideWith(
        (ref) async => latestSteps.isEmpty
            ? const <String, dynamic>{}
            : {'steps': latestSteps},
      ),
      dailyGoalsProvider.overrideWith((ref) async => goals),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

class _StubModeNotifier extends StepsLogModeNotifier {
  @override
  Future<StepsLogMode> build() async => StepsLogMode.add;
}

void main() {
  group('ZStepsLogPanel sync banner', () {
    testWidgets('Shows no banner and no placeholder when no synced data', (tester) async {
      await tester.pumpWidget(_wrap(ZStepsLogPanel(
        onSave: (_, __) async {},
        onBack: () {},
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('Synced'), findsNothing);
      expect(find.textContaining('will appear here'), findsNothing);
    });

    testWidgets('Shows sync banner when today data from health app is available', (tester) async {
      await tester.pumpWidget(_wrap(
        ZStepsLogPanel(onSave: (_, __) async {}, onBack: () {}),
        latestSteps: {
          'steps': 9420,
          'logged_at': _todayIso,
          'source': 'apple_health',
        },
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Apple Health'), findsOneWidget);
      expect(find.textContaining('9420'), findsWidgets);
    });

    testWidgets('Shows Confirm Steps when value matches synced', (tester) async {
      await tester.pumpWidget(_wrap(
        ZStepsLogPanel(onSave: (_, __) async {}, onBack: () {}),
        latestSteps: {
          'steps': 9420,
          'logged_at': _todayIso,
          'source': 'health_connect',
        },
      ));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Steps'), findsOneWidget);
    });

    testWidgets('Reverts to Save Steps when value is changed', (tester) async {
      await tester.pumpWidget(_wrap(
        ZStepsLogPanel(onSave: (_, __) async {}, onBack: () {}),
        latestSteps: {
          'steps': 9420,
          'logged_at': _todayIso,
          'source': 'apple_health',
        },
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '8000');
      await tester.pump();

      expect(find.text('Save Steps'), findsOneWidget);
    });

    testWidgets('No banner shown for manual source', (tester) async {
      await tester.pumpWidget(_wrap(
        ZStepsLogPanel(onSave: (_, __) async {}, onBack: () {}),
        latestSteps: {
          'steps': 5000,
          'logged_at': _todayIso,
          'source': 'manual',
        },
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Synced'), findsNothing);
    });
  });

  group('ZStepsLogPanel goal display', () {
    testWidgets('Shows Goal dash when no step goal configured', (tester) async {
      await tester.pumpWidget(_wrap(ZStepsLogPanel(
        onSave: (_, __) async {},
        onBack: () {},
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('Goal: —'), findsOneWidget);
    });

    testWidgets('Shows goal progress when step goal exists', (tester) async {
      await tester.pumpWidget(_wrap(
        ZStepsLogPanel(onSave: (_, __) async {}, onBack: () {}),
        goals: [
          DailyGoal(
            id: 'goal-1',
            label: 'Steps',
            target: 10000,
            current: 6200,
            unit: 'steps',
          ),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('10,000'), findsOneWidget);
      expect(find.textContaining('62%'), findsOneWidget);
    });
  });
}
