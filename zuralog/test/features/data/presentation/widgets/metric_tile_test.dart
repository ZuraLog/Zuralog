/// Zuralog — MetricTile & Empty State Widgets Tests (Phase 4).
///
/// Tests for [GhostTileContent], [SyncingTileContent],
/// [NoDataForRangeTileContent], and [MetricTile].
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/widgets/shimmer.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_models.dart';
import 'package:zuralog/features/data/presentation/widgets/metric_tile.dart';
import 'package:zuralog/features/data/presentation/widgets/tile_empty_states.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Wraps [child] in a plain [MaterialApp] for widget tests (no routing needed).
Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData.light(),
    home: Scaffold(body: child),
  );
}

void main() {
// ── GhostTileContent ──────────────────────────────────────────────────────────

group('GhostTileContent', () {
  testWidgets('renders at 40% opacity', (tester) async {
    await tester.pumpWidget(
      _wrap(
        GhostTileContent(
          categoryColor: AppColors.categoryActivity,
          onConnect: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final opacity = tester.widget<Opacity>(find.byType(Opacity).first);
    expect(opacity.opacity, closeTo(0.40, 0.01));
  });

  testWidgets('renders "Connect" button', (tester) async {
    await tester.pumpWidget(
      _wrap(
        GhostTileContent(
          categoryColor: AppColors.categoryActivity,
          onConnect: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Connect'), findsOneWidget);
  });

  testWidgets('tapping Connect calls onConnect', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(
        GhostTileContent(
          categoryColor: AppColors.categoryActivity,
          onConnect: () => tapped = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Connect'));
    await tester.pump();
    expect(tapped, isTrue);
  });
});

// ── SyncingTileContent ────────────────────────────────────────────────────────

group('SyncingTileContent', () {
  testWidgets('renders without error', (tester) async {
    await tester.pumpWidget(
      _wrap(const SizedBox(
        width: 150, height: 150,
        child: SyncingTileContent(),
      )),
    );
    await tester.pump();
    expect(find.byType(SyncingTileContent), findsOneWidget);
  });

  testWidgets('contains AppShimmer', (tester) async {
    await tester.pumpWidget(
      _wrap(const SizedBox(
        width: 150, height: 150,
        child: SyncingTileContent(),
      )),
    );
    await tester.pump();
    expect(find.byType(AppShimmer), findsOneWidget);
  });

  testWidgets('animation runs — pumping frames does not throw',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const SizedBox(
        width: 150, height: 150,
        child: SyncingTileContent(),
      )),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    // AppShimmer repeats indefinitely — do NOT pumpAndSettle.
    expect(find.byType(SyncingTileContent), findsOneWidget);
  });
});

// ── NoDataForRangeTileContent ─────────────────────────────────────────────────

group('NoDataForRangeTileContent', () {
  testWidgets('renders lastKnownValue text', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const NoDataForRangeTileContent(
          lastKnownValue: '8,432',
          lastUpdated: '2026-03-18T10:00:00Z',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('8,432'), findsOneWidget);
  });

  testWidgets('renders "Last:" prefix with relative time', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const NoDataForRangeTileContent(
          lastKnownValue: '8,432',
          lastUpdated: '2026-03-18T10:00:00Z',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Last:'), findsOneWidget);
  });

  testWidgets('renders "Last:" prefix in label', (tester) async {
    await tester.pumpWidget(
      _wrap(
        NoDataForRangeTileContent(
          lastKnownValue: '7h 22m',
          lastUpdated: DateTime.now()
              .subtract(const Duration(days: 2))
              .toIso8601String(),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('7h 22m'), findsOneWidget);
    expect(find.textContaining('Last:'), findsOneWidget);
    // Don't assert exact "2d ago" — clock-dependent
  });

  testWidgets('shows history icon for staleness signal', (tester) async {
    await tester.pumpWidget(
      _wrap(
        NoDataForRangeTileContent(
          lastKnownValue: '8,432',
          lastUpdated: DateTime.now()
              .subtract(const Duration(days: 2))
              .toIso8601String(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.history_rounded), findsOneWidget);
  });

  testWidgets('"Last:" label uses amber statusConnecting color', (tester) async {
    await tester.pumpWidget(
      _wrap(
        NoDataForRangeTileContent(
          lastKnownValue: '8,432',
          lastUpdated: DateTime.now()
              .subtract(const Duration(days: 2))
              .toIso8601String(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The "Last:" text should be rendered with statusConnecting (amber) color.
    final lastText = tester.widgetList<Text>(
      find.textContaining('Last:'),
    ).first;
    expect(lastText.style?.color, equals(AppColors.statusConnecting));
  });
});

// ── MetricTile — loaded state ─────────────────────────────────────────────────

group('MetricTile — loaded state', () {
  testWidgets('renders category pill in header', (tester) async {
    await tester.pumpWidget(
      _wrap(
        MetricTile(
          tileId: TileId.steps,
          dataState: TileDataState.loaded,
          size: TileSize.square,
          primaryValue: '8,432',
          unit: 'steps',
          visualization: const SizedBox(height: 40),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('● Activity'), findsOneWidget);
  });

  testWidgets('renders primaryValue text', (tester) async {
    await tester.pumpWidget(
      _wrap(
        MetricTile(
          tileId: TileId.steps,
          dataState: TileDataState.loaded,
          size: TileSize.square,
          primaryValue: '8,432',
          unit: 'steps',
          visualization: const SizedBox(height: 40),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('8,432'), findsOneWidget);
  });

  testWidgets('renders unit text', (tester) async {
    await tester.pumpWidget(
      _wrap(
        MetricTile(
          tileId: TileId.steps,
          dataState: TileDataState.loaded,
          size: TileSize.square,
          primaryValue: '8,432',
          unit: 'steps',
          visualization: const SizedBox(height: 40),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('steps'), findsOneWidget);
  });

  testWidgets('stats footer visible for TileSize.tall', (tester) async {
    await tester.pumpWidget(
      _wrap(
        MetricTile(
          tileId: TileId.steps,
          dataState: TileDataState.loaded,
          size: TileSize.tall,
          primaryValue: '8,432',
          unit: 'steps',
          avgLabel: 'Avg 7.9k',
          deltaLabel: '↑ 12%',
          visualization: const SizedBox(height: 60),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('stats_footer')), findsOneWidget);
  });

  testWidgets('stats footer hidden for TileSize.square', (tester) async {
    await tester.pumpWidget(
      _wrap(
        MetricTile(
          tileId: TileId.steps,
          dataState: TileDataState.loaded,
          size: TileSize.square,
          primaryValue: '8,432',
          unit: 'steps',
          avgLabel: 'Avg 7.9k',
          deltaLabel: '↑ 12%',
          visualization: const SizedBox(height: 40),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('stats_footer')), findsNothing);
  });

  testWidgets(
      'stats footer is visible on TileSize.wide with visualization and labels',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        MetricTile(
          tileId: TileId.weight,
          dataState: TileDataState.loaded,
          size: TileSize.wide,
          visualization: const SizedBox(height: 40),
          primaryValue: '72.3',
          unit: 'kg',
          avgLabel: 'Avg 72.1',
          deltaLabel: '↓ 0.3%',
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('stats_footer')), findsOneWidget);
  });

  testWidgets('falls back to em-dash when primaryValue is null', (tester) async {
    await tester.pumpWidget(
      _wrap(
        MetricTile(
          tileId: TileId.steps,
          dataState: TileDataState.loaded,
          size: TileSize.square,
          visualization: const SizedBox(height: 40),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('—'), findsOneWidget);
  });
});

// ── MetricTile — noSource state ───────────────────────────────────────────────

group('MetricTile — noSource state', () {
  testWidgets('renders GhostTileContent', (tester) async {
    await tester.pumpWidget(
      _wrap(
        MetricTile(
          tileId: TileId.steps,
          dataState: TileDataState.noSource,
          size: TileSize.square,
          onConnect: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GhostTileContent), findsOneWidget);
  });

  testWidgets('tile has 40% opacity (Opacity widget present)', (tester) async {
    await tester.pumpWidget(
      _wrap(
        MetricTile(
          tileId: TileId.steps,
          dataState: TileDataState.noSource,
          size: TileSize.square,
          onConnect: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // GhostTileContent wraps itself in an Opacity(opacity: 0.40)
    final opacityWidgets = tester.widgetList<Opacity>(find.byType(Opacity));
    expect(opacityWidgets.any((o) => (o.opacity - 0.40).abs() < 0.01), isTrue);
  });
});

// ── MetricTile — syncing state ────────────────────────────────────────────────

group('MetricTile — syncing state', () {
  testWidgets('renders SyncingTileContent', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const MetricTile(
          tileId: TileId.restingHeartRate,
          dataState: TileDataState.syncing,
          size: TileSize.square,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SyncingTileContent), findsOneWidget);
  });
});

// ── MetricTile — hidden state ─────────────────────────────────────────────────

group('MetricTile — hidden state', () {
  testWidgets('renders SizedBox.shrink (zero size)', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const MetricTile(
          tileId: TileId.steps,
          dataState: TileDataState.hidden,
          size: TileSize.square,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The tile should have zero size when hidden
    final tileWidget = find.byType(MetricTile);
    final size = tester.getSize(tileWidget);
    expect(size.width, equals(0));
    expect(size.height, equals(0));
  });
});

// ── MetricTile — noDataForRange state ────────────────────────────────────────

group('MetricTile — noDataForRange state', () {
  testWidgets('renders NoDataForRangeTileContent', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const MetricTile(
          tileId: TileId.weight,
          dataState: TileDataState.noDataForRange,
          size: TileSize.square,
          primaryValue: '72 kg',
          lastUpdated: '2026-03-18T00:00:00Z',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NoDataForRangeTileContent), findsOneWidget);
  });
});

// ── MetricTile — colorOverride ────────────────────────────────────────────────

group('MetricTile — colorOverride', () {
  testWidgets('category pill uses the override color', (tester) async {
    // Override color: pure red = 0xFFFF0000
    const overrideColor = 0xFFFF0000;

    await tester.pumpWidget(
      _wrap(
        MetricTile(
          tileId: TileId.steps,
          dataState: TileDataState.loaded,
          size: TileSize.square,
          primaryValue: '8,432',
          visualization: const SizedBox(height: 40),
          colorOverride: overrideColor,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The category pill should be present (Option C replaced the dot).
    expect(find.text('● Activity'), findsOneWidget);
    // The pill text should use the override color.
    final pillText = tester.widget<Text>(find.text('● Activity'));
    expect(pillText.style?.color, equals(const Color(overrideColor)));
  });
});
// ── MetricTile — Option C anatomy ────────────────────────────────────────────

Widget _buildTile({
  required TileId tileId,
  TileDataState dataState = TileDataState.loaded,
  TileSize size = TileSize.square,
}) {
  return MaterialApp(
    home: Scaffold(
      body: MetricTile(
        tileId: tileId,
        dataState: dataState,
        size: size,
        primaryValue: '8,432',
        unit: 'steps today',
      ),
    ),
  );
}

group('MetricTile — Option C anatomy', () {
  testWidgets('shows tileId.displayName not category name', (tester) async {
    await tester.pumpWidget(_buildTile(tileId: TileId.steps, dataState: TileDataState.loaded));
    expect(find.text('STEPS'), findsOneWidget);
    expect(find.text('ACTIVITY'), findsNothing);
  });

  testWidgets('shows category pill with category name', (tester) async {
    await tester.pumpWidget(_buildTile(tileId: TileId.steps, dataState: TileDataState.loaded));
    expect(find.text('● Activity'), findsOneWidget);
  });

  testWidgets('does not show _CategoryHeader dot', (tester) async {
    await tester.pumpWidget(_buildTile(tileId: TileId.steps, dataState: TileDataState.loaded));
    expect(find.byKey(const Key('category_color_dot')), findsNothing);
  });
});

// ── OnboardingEmptyState ──────────────────────────────────────────────────────

group('OnboardingEmptyState', () {
  testWidgets('renders welcome title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OnboardingEmptyState(
            onConnectDevice: () {},
            onLogManually: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Start tracking'), findsOneWidget);
  });

  testWidgets('Connect a Device button calls onConnectDevice', (tester) async {
    var connectCalled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OnboardingEmptyState(
            onConnectDevice: () => connectCalled = true,
            onLogManually: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    // The primary CTA ElevatedButton may be below the fold — scroll to it first.
    final connectBtn = find.widgetWithText(ElevatedButton, 'Connect a Device');
    await tester.ensureVisible(connectBtn);
    await tester.tap(connectBtn);
    expect(connectCalled, isTrue);
  });

  testWidgets('Log Manually button calls onLogManually', (tester) async {
    var logCalled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OnboardingEmptyState(
            onConnectDevice: () {},
            onLogManually: () => logCalled = true,
          ),
        ),
      ),
    );
    await tester.pump();
    // The secondary CTA TextButton may be below the fold — scroll to it first.
    final logBtn = find.widgetWithText(TextButton, 'Log Manually');
    await tester.ensureVisible(logBtn);
    await tester.tap(logBtn);
    expect(logCalled, isTrue);
  });
});

} // end main
