/// Zuralog — Phase 6 Interaction Widgets Tests.
///
/// Tests for [SearchOverlay].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/features/data/domain/tile_models.dart';
import 'package:zuralog/features/data/presentation/widgets/search_overlay.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

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

void main() {
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
