/// Zuralog — TileEditOverlay Tests (Phase 7).
///
/// Tests for [TileEditOverlay]: size badge, visibility toggle,
/// color pick, semantics, and animation lifecycle.
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_models.dart';
import 'package:zuralog/features/data/presentation/widgets/tile_edit_overlay.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData.light(),
    home: Scaffold(body: SizedBox(width: 200, height: 200, child: child)),
  );
}

TileEditOverlay _makeOverlay({
  TileId tileId = TileId.steps,
  TileSize currentSize = TileSize.square,
  bool isVisible = true,
  int? currentColorOverride,
  ValueChanged<TileSize>? onSizeChanged,
  VoidCallback? onVisibilityToggled,
  VoidCallback? onColorPick,
  Widget? child,
}) {
  return TileEditOverlay(
    tileId: tileId,
    currentSize: currentSize,
    isVisible: isVisible,
    currentColorOverride: currentColorOverride,
    onSizeChanged: onSizeChanged ?? (_) {},
    onVisibilityToggled: onVisibilityToggled ?? () {},
    onColorPick: onColorPick ?? () {},
    child: child ?? const SizedBox(key: Key('child'), width: 100, height: 100),
  );
}

void main() {
  // ── Size Badge ──────────────────────────────────────────────────────────────

  group('Size badge', () {
    testWidgets('shows "1×1" when currentSize is TileSize.square',
        (tester) async {
      await tester.pumpWidget(_wrap(_makeOverlay(currentSize: TileSize.square)));
      await tester.pump();

      expect(find.text('1×1'), findsOneWidget);
    });

    testWidgets('shows "1×2" when currentSize is TileSize.tall',
        (tester) async {
      await tester.pumpWidget(_wrap(_makeOverlay(currentSize: TileSize.tall)));
      await tester.pump();

      expect(find.text('1×2'), findsOneWidget);
    });

    testWidgets('shows "2×1" when currentSize is TileSize.wide',
        (tester) async {
      await tester
          .pumpWidget(_wrap(_makeOverlay(currentSize: TileSize.wide)));
      await tester.pump();

      expect(find.text('2×1'), findsOneWidget);
    });

    testWidgets(
        'tapping the badge calls onSizeChanged with tileId.nextSize(currentSize)',
        (tester) async {
      TileSize? received;
      const id = TileId.steps; // allowedSizes: [square, tall]
      const currentSize = TileSize.square;
      final expectedNext = id.nextSize(currentSize); // → tall

      await tester.pumpWidget(
        _wrap(
          _makeOverlay(
            tileId: id,
            currentSize: currentSize,
            onSizeChanged: (s) => received = s,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('1×1'));
      await tester.pump();

      expect(received, equals(expectedNext));
    });
  });

  // ── Visibility ──────────────────────────────────────────────────────────────

  group('Visibility', () {
    testWidgets('shows visibility_rounded icon when isVisible=true',
        (tester) async {
      await tester.pumpWidget(_wrap(_makeOverlay(isVisible: true)));
      await tester.pump();

      expect(find.byIcon(Icons.visibility_rounded), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_rounded), findsNothing);
    });

    testWidgets('shows visibility_off_rounded icon when isVisible=false',
        (tester) async {
      await tester.pumpWidget(_wrap(_makeOverlay(isVisible: false)));
      await tester.pump();

      expect(find.byIcon(Icons.visibility_off_rounded), findsOneWidget);
      expect(find.byIcon(Icons.visibility_rounded), findsNothing);
    });

    testWidgets('tapping the eye icon calls onVisibilityToggled',
        (tester) async {
      var called = false;
      await tester.pumpWidget(
        _wrap(
          _makeOverlay(
            isVisible: true,
            onVisibilityToggled: () => called = true,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.visibility_rounded));
      await tester.pump();

      expect(called, isTrue);
    });

    testWidgets('hidden tile (isVisible=false) has Opacity widget with opacity == AppDimens.disabledOpacity',
        (tester) async {
      await tester.pumpWidget(_wrap(_makeOverlay(isVisible: false)));
      await tester.pump();

      final opacityWidgets = tester.widgetList<Opacity>(find.byType(Opacity));
      expect(
        opacityWidgets.any((o) => o.opacity == AppDimens.disabledOpacity),
        isTrue,
        reason: 'Hidden tile must use AppDimens.disabledOpacity (${AppDimens.disabledOpacity})',
      );
    });

    testWidgets('hidden tile shows strikethrough CustomPaint', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TileEditOverlay(
              tileId: TileId.steps,
              currentSize: TileSize.square,
              isVisible: false,
              currentColorOverride: null,
              onSizeChanged: (_) {},
              onVisibilityToggled: () {},
              onColorPick: () {},
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );
      await tester.pump();
      // Strikethrough is a CustomPaint sibling to the Opacity widget
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  // ── Color ───────────────────────────────────────────────────────────────────

  group('Color', () {
    testWidgets('tapping palette icon calls onColorPick', (tester) async {
      var called = false;
      await tester.pumpWidget(
        _wrap(
          _makeOverlay(onColorPick: () => called = true),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.palette_rounded));
      await tester.pump();

      expect(called, isTrue);
    });
  });

  // ── Semantics ───────────────────────────────────────────────────────────────

  group('Semantics', () {
    testWidgets('has semantic actions for "Change Size" and "Toggle Visibility"',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(_makeOverlay()));
      await tester.pump();

      final semanticsNode = tester.getSemantics(find.byType(TileEditOverlay));
      final data = semanticsNode.getSemanticsData();
      final actionIds = data.customSemanticsActionIds ?? [];

      // CustomSemanticsAction.getAction resolves id → action with a label
      final labels = actionIds
          .map((id) => CustomSemanticsAction.getAction(id)?.label ?? '')
          .toList();

      expect(labels, contains('Change Size'));
      expect(labels, contains('Toggle Visibility'));

      handle.dispose();
    });
  });

  // ── Wiggle Animation ────────────────────────────────────────────────────────

  group('Wiggle animation', () {
    testWidgets('AnimationController is created and disposed correctly',
        (tester) async {
      await tester.pumpWidget(_wrap(_makeOverlay()));
      // Let the animation tick
      await tester.pump(const Duration(milliseconds: 200));

      // The Transform.rotate widget should be present (wiggle is active)
      expect(find.byType(Transform), findsWidgets);

      // Dispose by removing the widget
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      // If controller was not disposed, Flutter test framework would report
      // a leaked AnimationController — the test will fail if that happens.
    });

    testWidgets('child widget is rendered inside the overlay', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _makeOverlay(
            child: const SizedBox(key: Key('inner_child'), width: 50, height: 50),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('inner_child')), findsOneWidget);
    });
  });

  // ── disabledOpacity constant ────────────────────────────────────────────────

  group('AppDimens.disabledOpacity', () {
    test('is 0.45', () {
      expect(AppDimens.disabledOpacity, closeTo(0.45, 0.001));
    });
  });
}
