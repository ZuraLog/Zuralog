import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/features/body/domain/body_state.dart';
import 'package:zuralog/features/body/domain/coach_message.dart';
import 'package:zuralog/features/body/domain/muscle_state.dart';
import 'package:zuralog/features/body/domain/readiness_score.dart';
import 'package:zuralog/features/body/providers/body_now_coach_message_provider.dart';
import 'package:zuralog/features/body/providers/body_now_metrics_provider.dart';
import 'package:zuralog/features/body/providers/body_state_provider.dart';
import 'package:zuralog/features/today/presentation/widgets/body_now/body_now_hero_card.dart';
import 'package:zuralog/features/workout/domain/exercise.dart' show MuscleGroup;

void main() {
  testWidgets('BodyNowHeroCard renders zero-state when no body signal',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        bodyStateProvider.overrideWith((ref) async => BodyState.empty),
        bodyNowMetricsProvider
            .overrideWith((ref) async => BodyNowMetrics.empty),
        bodyNowCoachMessageProvider.overrideWith(
          (ref) async => const CoachMessage(
            text: 'hello',
            ctaLabel: 'Connect',
            ctaRoute: '/settings/integrations',
          ),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(body: BodyNowHeroCard()),
      ),
    ));
    // Use pump instead of pumpAndSettle: the hero card's pattern overlay
    // runs an infinite animation that would cause pumpAndSettle to time out.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('meet your body'), findsOneWidget);
  });

  testWidgets('BodyNowHeroCard renders rail values when signal present',
      (tester) async {
    final state = BodyState(
      muscles: const {
        MuscleGroup.quads: MuscleState.fresh,
        MuscleGroup.shoulders: MuscleState.sore,
      },
      computedAt: DateTime.utc(2026, 4, 23),
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        bodyStateProvider.overrideWith((ref) async => state),
        bodyNowMetricsProvider.overrideWith(
          (ref) async => const BodyNowMetrics(
            readiness: ReadinessScore(value: 86, delta: 4),
            hrvMs: 58,
            hrvDeltaPct: 12,
            rhrBpm: 52,
            rhrDeltaBpm: -3,
            sleepMinutes: 462,
            sleepQuality: 82,
          ),
        ),
        bodyNowCoachMessageProvider.overrideWith(
          (ref) async => const CoachMessage(
            text: 'Legs look primed.',
            ctaLabel: 'View session',
            ctaRoute: '/coach',
          ),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(body: BodyNowHeroCard()),
      ),
    ));
    // Use pump instead of pumpAndSettle: the hero card's pattern overlay
    // runs an infinite animation that would cause pumpAndSettle to time out.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('86'), findsOneWidget);
    expect(find.text('58'), findsOneWidget);
    expect(find.text('52'), findsOneWidget);
    expect(find.text('7:42'), findsOneWidget);
    expect(find.text('View session'), findsOneWidget);
  });
}
