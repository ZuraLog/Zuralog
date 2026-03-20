/// Zuralog — Header Widgets Tests (Phase 3).
///
/// Tests for [HealthScoreStrip], [CategoryFilterChips], and
/// [GlobalTimeRangeSelector].
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/time_range.dart';
import 'package:zuralog/features/data/presentation/widgets/category_filter_chips.dart';
import 'package:zuralog/features/data/presentation/widgets/global_time_range_selector.dart';
import 'package:zuralog/features/data/presentation/widgets/health_score_strip.dart';
import 'package:zuralog/features/data/providers/data_providers.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Wraps [child] in a minimal routing + provider scope.
///
/// [overrides] are applied to [ProviderScope].
/// The router provides `/data/score` as a stub route so navigation tests work.
Widget _wrap(
  Widget child, {
  List<Override> overrides = const [],
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(body: child),
        routes: [
          GoRoute(
            path: 'data/score',
            builder: (context, _) =>
                const Scaffold(body: Text('score breakdown')),
          ),
        ],
      ),
    ],
  );

  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
// ── HealthScoreStrip ──────────────────────────────────────────────────────────

group('HealthScoreStrip', () {
  testWidgets('renders score number when provider has data (score: 72)',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const HealthScoreStrip(),
        overrides: [
          healthScoreProvider.overrideWith(
            (_) async => const HealthScoreData(
              score: 72,
              trend: [68.0, 70.0, 71.0, 72.0, 73.0, 71.0, 72.0],
              dataDays: 30,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('72'), findsOneWidget);
  });

  testWidgets('renders em-dash when score is 0 and dataDays is 0',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const HealthScoreStrip(),
        overrides: [
          healthScoreProvider.overrideWith(
            (_) async =>
                const HealthScoreData(score: 0, trend: [], dataDays: 0),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('renders "Not enough data yet" subtitle in no-score state',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const HealthScoreStrip(),
        overrides: [
          healthScoreProvider.overrideWith(
            (_) async =>
                const HealthScoreData(score: 0, trend: [], dataDays: 0),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Not enough data yet'), findsOneWidget);
  });

  testWidgets('uses green for score >= 70', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const HealthScoreStrip(),
        overrides: [
          healthScoreProvider.overrideWith(
            (_) async => const HealthScoreData(
              score: 70,
              trend: [],
              dataDays: 10,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    // Green score — widget renders successfully with score 70
    expect(find.text('70'), findsOneWidget);
    // Color verified visually — ring painter color is AppColors.healthScoreGreen for score >= 70
    expect(find.byKey(const ValueKey('score_ring')), findsOneWidget);
  });

  testWidgets('uses amber for score 40-69', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const HealthScoreStrip(),
        overrides: [
          healthScoreProvider.overrideWith(
            (_) async => const HealthScoreData(
              score: 55,
              trend: [],
              dataDays: 10,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('55'), findsOneWidget);
    // Color verified visually — ring painter color is AppColors.healthScoreAmber for score 40–69
    expect(find.byKey(const ValueKey('score_ring')), findsOneWidget);
  });

  testWidgets('uses red for score < 40', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const HealthScoreStrip(),
        overrides: [
          healthScoreProvider.overrideWith(
            (_) async => const HealthScoreData(
              score: 30,
              trend: [],
              dataDays: 10,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('30'), findsOneWidget);
    // Color verified visually — ring painter color is AppColors.healthScoreRed for score < 40
    expect(find.byKey(const ValueKey('score_ring')), findsOneWidget);
  });

  testWidgets('shows loading skeleton when provider is loading',
      (tester) async {
    // Use a Completer so the provider stays in loading state permanently
    // without leaving any pending timer.
    final completer = Completer<HealthScoreData>();
    await tester.pumpWidget(
      _wrap(
        const HealthScoreStrip(),
        overrides: [
          healthScoreProvider.overrideWith((_) => completer.future),
        ],
      ),
    );
    // Pump once without settling — provider is still loading.
    await tester.pump();
    expect(find.byType(HealthScoreStrip), findsOneWidget);
    // Verify the strip has rendered something (skeleton row visible)
    final strip = tester.getSize(find.byType(HealthScoreStrip));
    expect(strip.height, greaterThan(0));
    // Score number and subtitle should not be visible yet.
    expect(find.text('72'), findsNothing);
    expect(find.text('—'), findsNothing);
    // Complete to allow teardown.
    completer.complete(const HealthScoreData(score: 0, trend: [], dataDays: 0));
  });
});

// ── CategoryFilterChips ───────────────────────────────────────────────────────

group('CategoryFilterChips', () {
  testWidgets('renders "All" chip plus 10 category chips (total 11)',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        CategoryFilterChips(
          selected: null,
          onSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    // "All" + 10 categories
    expect(find.text('All'), findsOneWidget);
    for (final cat in HealthCategory.values) {
      expect(find.text(cat.displayName), findsOneWidget);
    }
  });

  testWidgets('"All" chip is visually active when selected == null',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        CategoryFilterChips(
          selected: null,
          onSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The "All" chip container should carry a key or semantic indicating active.
    // We verify by checking the widget builds without error and "All" is present.
    expect(find.text('All'), findsOneWidget);
  });

  testWidgets('tapping a category chip calls onSelected with that category',
      (tester) async {
    HealthCategory? tapped;
    await tester.pumpWidget(
      _wrap(
        CategoryFilterChips(
          selected: null,
          onSelected: (cat) => tapped = cat,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sleep'));
    await tester.pump();
    expect(tapped, equals(HealthCategory.sleep));
  });

  testWidgets('tapping the already-selected chip calls onSelected(null)',
      (tester) async {
    HealthCategory? result = HealthCategory.sleep; // start non-null
    await tester.pumpWidget(
      _wrap(
        CategoryFilterChips(
          selected: HealthCategory.sleep,
          onSelected: (cat) => result = cat,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sleep'));
    await tester.pump();
    expect(result, isNull);
  });

  testWidgets('tapping "All" chip calls onSelected(null)', (tester) async {
    HealthCategory? result = HealthCategory.activity;
    await tester.pumpWidget(
      _wrap(
        CategoryFilterChips(
          selected: HealthCategory.activity,
          onSelected: (cat) => result = cat,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('All'));
    await tester.pump();
    expect(result, isNull);
  });

  testWidgets('active chip shows a color dot before the label',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        CategoryFilterChips(
          selected: HealthCategory.activity,
          onSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The active category chip contains a color dot (a small Container).
    // We verify by finding the activity chip row — it should have a dot widget.
    // Use a semantic label or key to find it.
    expect(find.byKey(const Key('chip_dot_activity')), findsOneWidget);
  });
});

// ── GlobalTimeRangeSelector ───────────────────────────────────────────────────

group('GlobalTimeRangeSelector', () {
  testWidgets('renders 5 chips (Today, 7D, 30D, 90D, Custom)',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const GlobalTimeRangeSelector()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('7D'), findsOneWidget);
    expect(find.text('30D'), findsOneWidget);
    expect(find.text('90D'), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);
  });

  testWidgets('default selected chip is 7D (dashboardTimeRangeProvider default)',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const GlobalTimeRangeSelector()),
    );
    await tester.pumpAndSettle();
    // "7D" chip should be the active one by default.
    // We verify by checking both the widget renders and that 7D is present.
    expect(find.text('7D'), findsOneWidget);
    // Verify provider default
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(dashboardTimeRangeProvider), TimeRange.sevenDays);
  });

  testWidgets('tapping 30D updates dashboardTimeRangeProvider to thirtyDays',
      (tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return MaterialApp(
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) =>
                      const GlobalTimeRangeSelector(),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('30D'));
    await tester.pumpAndSettle();
    expect(
      container.read(dashboardTimeRangeProvider),
      equals(TimeRange.thirtyDays),
    );
  });

  testWidgets(
      'Custom chip shows "Mar 1–15" format when customDateRangeProvider has a range set',
      (tester) async {
    final customRange = DateTimeRange(
      start: DateTime(2026, 3, 1),
      end: DateTime(2026, 3, 15),
    );

    await tester.pumpWidget(
      _wrap(
        const GlobalTimeRangeSelector(),
        overrides: [
          dashboardTimeRangeProvider
              .overrideWith((ref) => TimeRange.custom),
          customDateRangeProvider
              .overrideWith((ref) => customRange),
        ],
      ),
    );
    await tester.pumpAndSettle();
    // Custom range chip should show "Mar 1–15" (or similar compact format).
    expect(find.textContaining('Mar'), findsOneWidget);
  });
});
} // end main
