/// Unit tests for goal_metrics helpers.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/features/progress/domain/goal_metrics.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';

Goal _g({
  required double current,
  required double target,
  GoalType type = GoalType.custom,
  String startDate = '2026-04-01',
  String? deadline,
  List<double> history = const [],
}) =>
    Goal(
      id: 'g',
      userId: 'u',
      type: type,
      period: GoalPeriod.weekly,
      title: 'Test goal',
      targetValue: target,
      currentValue: current,
      unit: 'units',
      startDate: startDate,
      progressHistory: history,
      deadline: deadline,
    );

void main() {
  group('velocityPerDay', () {
    test('returns 0 when history is empty', () {
      expect(velocityPerDay(_g(current: 0, target: 100)), 0.0);
    });

    test('returns net delta over days for ascending history', () {
      // 8 entries: 0 → 70 over 7 day-deltas, so 10 units/day
      final hist = <double>[0, 10, 20, 30, 40, 50, 60, 70];
      expect(velocityPerDay(_g(current: 70, target: 100, history: hist)), 10.0);
    });

    test('returns negative velocity for descending history', () {
      // 8 entries: 80 → 70 over 7 day-deltas, so -10/7 per day
      final hist = <double>[80, 78, 77, 76, 74, 72, 71, 70];
      final v = velocityPerDay(_g(current: 70, target: 60, history: hist));
      expect(v, lessThan(0));
      expect(v, closeTo(-10.0 / 7, 0.01));
    });
  });

  group('daysRemaining', () {
    test('returns null when deadline is null', () {
      expect(daysRemaining(_g(current: 0, target: 100), today: DateTime(2026, 4, 21)), isNull);
    });

    test('returns positive integer when deadline is in the future', () {
      final g = _g(current: 0, target: 100, deadline: '2026-04-30');
      expect(daysRemaining(g, today: DateTime(2026, 4, 21)), 9);
    });

    test('returns 0 when deadline is today', () {
      final g = _g(current: 0, target: 100, deadline: '2026-04-21');
      expect(daysRemaining(g, today: DateTime(2026, 4, 21)), 0);
    });

    test('returns negative when deadline is past', () {
      final g = _g(current: 0, target: 100, deadline: '2026-04-15');
      expect(daysRemaining(g, today: DateTime(2026, 4, 21)), -6);
    });
  });

  group('projectedEndDate', () {
    test('returns null when velocity is zero', () {
      expect(
        projectedEndDate(_g(current: 50, target: 100), today: DateTime(2026, 4, 21)),
        isNull,
      );
    });

    test('returns today when goal already complete', () {
      final today = DateTime(2026, 4, 21);
      final g = _g(current: 100, target: 100, history: [50.0, 60, 70, 80, 90, 100]);
      expect(projectedEndDate(g, today: today), today);
    });

    test('returns today + (remaining / |velocity|) days for ascending goal', () {
      // velocity = 10/day, remaining = 30 → 3 days
      final today = DateTime(2026, 4, 21);
      final g = _g(current: 70, target: 100, history: [0.0, 10, 20, 30, 40, 50, 60, 70]);
      final expected = today.add(const Duration(days: 3));
      expect(projectedEndDate(g, today: today), expected);
    });
  });

  group('logStreak', () {
    test('returns 0 for empty history', () {
      expect(logStreak(_g(current: 0, target: 10, history: const [])), 0);
    });

    test('counts trailing positive entries', () {
      expect(
        logStreak(_g(current: 0, target: 10, history: [0.0, 1, 0, 0, 1, 1, 1, 1])),
        4,
      );
    });

    test('returns 0 when most recent entry is zero', () {
      expect(
        logStreak(_g(current: 0, target: 10, history: [1.0, 1, 1, 1, 0])),
        0,
      );
    });
  });

  group('milestonesReached', () {
    test('returns 0 for empty history', () {
      expect(milestonesReached(_g(current: 0, target: 100)), 0);
    });

    test('counts thresholds (25, 50, 75, 100) crossed by max history value', () {
      // max = 60 → crosses 25 and 50, not 75 or 100
      expect(
        milestonesReached(_g(current: 60, target: 100, history: [10.0, 30, 60])),
        2,
      );
    });

    test('caps at 4 even when over 100%', () {
      expect(
        milestonesReached(_g(current: 150, target: 100, history: [10.0, 50, 100, 150])),
        4,
      );
    });
  });
}
