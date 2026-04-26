import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/features/body/domain/body_state.dart';
import 'package:zuralog/features/body/domain/coach_message.dart';
import 'package:zuralog/features/body/domain/muscle_state.dart';
import 'package:zuralog/features/body/providers/body_now_coach_message_provider.dart';
import 'package:zuralog/features/body/providers/body_state_provider.dart';
import 'package:zuralog/features/body/providers/pillar_metrics_providers.dart';
import 'package:zuralog/features/today/presentation/widgets/body_now/body_now_hero_card.dart';
import 'package:zuralog/features/workout/domain/exercise.dart' show MuscleGroup;

void main() {
  testWidgets('BodyNowHeroCard renders with empty state and Zura connect prompt',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        bodyStateProvider.overrideWith((ref) async => BodyState.empty),
        pillarMetricsProvider
            .overrideWith((ref) async => PillarMetrics.empty),
        bodyNowCoachMessageProvider.overrideWith(
          (ref) async => const CoachMessage(
            text: 'Hey! Connect Apple Health or your watch.',
            ctaLabel: 'Go to Settings',
            ctaRoute: '/settings/integrations',
          ),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(body: BodyNowHeroCard()),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Connect'), findsAtLeast(1));
  });

  testWidgets('BodyNowHeroCard renders Nutrition / Fitness / Sleep / Heart chips',
      (tester) async {
    final state = BodyState(
      muscles: const {
        MuscleGroup.quads: MuscleState.fresh,
        MuscleGroup.shoulders: MuscleState.sore,
      },
      computedAt: DateTime.utc(2026, 4, 24),
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        bodyStateProvider.overrideWith((ref) async => state),
        pillarMetricsProvider.overrideWith(
          (ref) async => const PillarMetrics(
            caloriesKcal: 1240,
            stepsToday: 6432,
            sleepHours: 7.7,
            avgHrBpm: 78,
          ),
        ),
        bodyNowCoachMessageProvider.overrideWith(
          (ref) async => const CoachMessage(
            text: "Legs look primed.",
            ctaLabel: 'View session',
            ctaRoute: '/coach',
          ),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(body: BodyNowHeroCard()),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Nutrition'), findsOneWidget);
    expect(find.text('Fitness'), findsOneWidget);
    expect(find.text('Sleep'), findsOneWidget);
    expect(find.text('Heart'), findsOneWidget);
    expect(find.text('View session'), findsOneWidget);
  });

  testWidgets('BodyNowHeroCard renders check-in button when isCheckIn=true',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        bodyStateProvider.overrideWith((ref) async => BodyState.empty),
        pillarMetricsProvider
            .overrideWith((ref) async => PillarMetrics.empty),
        bodyNowCoachMessageProvider.overrideWith(
          (ref) async => const CoachMessage(
            text: 'Your shoulders were sore yesterday.',
            ctaLabel: 'How do you feel now?',
            ctaRoute: '/today',
            isCheckIn: true,
          ),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(body: BodyNowHeroCard()),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('How do you feel now?'), findsOneWidget);
  });
}
