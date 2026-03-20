/// Zuralog — Phase 6 Interaction Widgets Tests.
///
/// Tests for [TileExpandedView] and [SearchOverlay].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_models.dart';
import 'package:zuralog/features/data/presentation/widgets/search_overlay.dart';
import 'package:zuralog/features/data/presentation/widgets/tile_expanded_view.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Wraps [child] in a plain [MaterialApp] for widget tests.
Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData.light(),
    home: Scaffold(body: child),
  );
}

/// Wraps [child] in a [ProviderScope] + [MaterialApp].
Widget _wrapWithProviders(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      theme: ThemeData.light(),
      home: Scaffold(body: child),
    ),
  );
}

/// Builds a list of [TileData] for all TileIds in the noSource state.
List<TileData> _allTiles() {
  return TileId.values
      .map(
        (id) => TileData(
          tileId: id,
          dataState: TileDataState.noSource,
        ),
      )
      .toList();
}

// ══════════════════════════════════════════════════════════════════════════════
// TileExpandedView tests
// ══════════════════════════════════════════════════════════════════════════════

void main() {
  group('TileExpandedView', () {
    testWidgets('renders primary value text', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            child: TileExpandedView(
              tileId: TileId.steps,
              size: TileSize.square,
              visualization: null,
              primaryValue: '8,432',
              onViewDetails: () {},
              onAskCoach: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('8,432'), findsOneWidget);
    });

    testWidgets('renders stats row with 4 stat chips (Avg, Best, Worst, Change)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            child: TileExpandedView(
              tileId: TileId.steps,
              size: TileSize.square,
              visualization: null,
              primaryValue: '8,432',
              avgValue: '7,900',
              bestValue: '12,000',
              worstValue: '4,200',
              changeValue: '↑ 12%',
              onViewDetails: () {},
              onAskCoach: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Avg'), findsOneWidget);
      expect(find.text('Best'), findsOneWidget);
      expect(find.text('Worst'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);

      expect(find.text('7,900'), findsOneWidget);
      expect(find.text('12,000'), findsOneWidget);
      expect(find.text('4,200'), findsOneWidget);
      expect(find.text('↑ 12%'), findsOneWidget);
    });

    testWidgets('stats show "—" when values are null', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            child: TileExpandedView(
              tileId: TileId.steps,
              size: TileSize.square,
              visualization: null,
              primaryValue: '8,432',
              // avgValue, bestValue, worstValue, changeValue all null
              onViewDetails: () {},
              onAskCoach: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // There should be 4 "—" fallback values shown
      expect(find.text('—'), findsNWidgets(4));
    });

    testWidgets('"View Details ›" button calls onViewDetails', (tester) async {
      var called = false;
      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            child: TileExpandedView(
              tileId: TileId.steps,
              size: TileSize.square,
              visualization: null,
              primaryValue: '8,432',
              onViewDetails: () => called = true,
              onAskCoach: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('View Details ›'));
      await tester.pumpAndSettle();

      expect(called, isTrue);
    });

    testWidgets('"Ask Coach" button calls onAskCoach', (tester) async {
      var called = false;
      await tester.pumpWidget(
        _wrap(
          SingleChildScrollView(
            child: TileExpandedView(
              tileId: TileId.steps,
              size: TileSize.square,
              visualization: null,
              primaryValue: '8,432',
              onViewDetails: () {},
              onAskCoach: () => called = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ask Coach'));
      await tester.pumpAndSettle();

      expect(called, isTrue);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // SearchOverlay tests
  // ════════════════════════════════════════════════════════════════════════════

  group('SearchOverlay', () {
    testWidgets('renders search field', (tester) async {
      await tester.pumpWidget(
        _wrapWithProviders(
          SearchOverlay(
            tiles: _allTiles(),
            onClose: () {},
            onTileSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('entering "steps" filters to only Steps tile', (tester) async {
      await tester.pumpWidget(
        _wrapWithProviders(
          SearchOverlay(
            tiles: _allTiles(),
            onClose: () {},
            onTileSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'steps');
      await tester.pumpAndSettle();

      expect(find.text('Steps'), findsOneWidget);
      expect(find.text('Resting Heart Rate'), findsNothing);
    });

    testWidgets('entering "heart" shows Heart category tiles', (tester) async {
      await tester.pumpWidget(
        _wrapWithProviders(
          SearchOverlay(
            tiles: _allTiles(),
            onClose: () {},
            onTileSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'heart');
      await tester.pumpAndSettle();

      expect(find.text('Resting Heart Rate'), findsOneWidget);
      expect(find.text('HRV'), findsOneWidget);
      expect(find.text('VO₂ Max'), findsOneWidget);
    });

    testWidgets('clearing search restores all tiles', (tester) async {
      await tester.pumpWidget(
        _wrapWithProviders(
          SearchOverlay(
            tiles: _allTiles(),
            onClose: () {},
            onTileSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final field = find.byType(TextField);
      await tester.enterText(field, 'steps');
      await tester.pumpAndSettle();
      // Only Steps should be visible
      expect(find.text('Resting Heart Rate'), findsNothing);

      // Clear
      await tester.enterText(field, '');
      await tester.pumpAndSettle();

      // Steps should be visible again (no empty state shown)
      expect(find.text('No metrics found'), findsNothing);
      // Steps tile should be visible (first in list)
      expect(find.text('Steps'), findsOneWidget);
    });

    testWidgets('entering a non-matching string shows "No metrics found"',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithProviders(
          SearchOverlay(
            tiles: _allTiles(),
            onClose: () {},
            onTileSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'xyznonexistent');
      await tester.pumpAndSettle();

      expect(find.text('No metrics found'), findsOneWidget);
    });

    testWidgets('tapping a tile calls onTileSelected with the correct TileId',
        (tester) async {
      TileId? selectedId;
      await tester.pumpWidget(
        _wrapWithProviders(
          SearchOverlay(
            tiles: _allTiles(),
            onClose: () {},
            onTileSelected: (id) => selectedId = id,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Filter to just Steps to make it easy to tap
      await tester.enterText(find.byType(TextField), 'steps');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Steps'));
      await tester.pumpAndSettle();

      expect(selectedId, equals(TileId.steps));
    });

    testWidgets('close button calls onClose', (tester) async {
      var closed = false;
      await tester.pumpWidget(
        _wrapWithProviders(
          SearchOverlay(
            tiles: _allTiles(),
            onClose: () => closed = true,
            onTileSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(closed, isTrue);
    });
  });
}
