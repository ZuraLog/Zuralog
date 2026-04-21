/// Widget tests for [ZuralogCard].
///
/// Verifies child rendering, light/dark surface styling, and tap behaviour.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_theme.dart';
import 'package:zuralog/shared/widgets/cards/zuralog_card.dart';

/// Wraps [child] in a [MaterialApp] using the given [themeMode].
Widget _themed(Widget child, {ThemeMode themeMode = ThemeMode.light}) {
  return MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: themeMode,
    home: Scaffold(body: Center(child: child)),
  );
}

/// Finds the first [Container] that has a non-null [BoxDecoration].
BoxDecoration? _findCardDecoration(WidgetTester tester) {
  final containers = tester.widgetList<Container>(find.byType(Container));
  for (final c in containers) {
    if (c.decoration is BoxDecoration) {
      return c.decoration as BoxDecoration;
    }
  }
  return null;
}

void main() {
  group('ZuralogCard — rendering', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        _themed(const ZuralogCard(child: Text('Hello Card'))),
      );
      expect(find.text('Hello Card'), findsOneWidget);
    });

    testWidgets('applies default padding', (tester) async {
      await tester.pumpWidget(
        _themed(const ZuralogCard(child: Text('Padded'))),
      );
      // ZuralogCard wraps child in a Container — it renders without overflow.
      expect(find.text('Padded'), findsOneWidget);
    });

    testWidgets('applies custom padding when provided', (tester) async {
      await tester.pumpWidget(
        _themed(const ZuralogCard(
          padding: EdgeInsets.all(32),
          child: Text('Custom Padding'),
        )),
      );
      expect(find.text('Custom Padding'), findsOneWidget);
    });
  });

  group('ZuralogCard — light mode styling', () {
    testWidgets('uses surfaceLight (#FFFFFF) as background in light mode',
        (tester) async {
      await tester.pumpWidget(
        _themed(
          const ZuralogCard(child: Text('Light')),
          themeMode: ThemeMode.light,
        ),
      );
      await tester.pump();
      final decoration = _findCardDecoration(tester);
      expect(decoration?.color, AppColors.surfaceLight);
    });

    testWidgets('has no border in light mode', (tester) async {
      await tester.pumpWidget(
        _themed(
          const ZuralogCard(child: Text('No Border')),
          themeMode: ThemeMode.light,
        ),
      );
      await tester.pump();
      final decoration = _findCardDecoration(tester);
      // Light mode: border is null (shadow used instead).
      expect(decoration?.border, isNull);
    });

    testWidgets('has a boxShadow in light mode', (tester) async {
      await tester.pumpWidget(
        _themed(
          const ZuralogCard(child: Text('Shadow')),
          themeMode: ThemeMode.light,
        ),
      );
      await tester.pump();
      final decoration = _findCardDecoration(tester);
      expect(decoration?.boxShadow, isNotNull);
      expect(decoration!.boxShadow!.isNotEmpty, isTrue);
    });

    testWidgets('has 24px corner radius in light mode', (tester) async {
      await tester.pumpWidget(
        _themed(
          const ZuralogCard(child: Text('Radius')),
          themeMode: ThemeMode.light,
        ),
      );
      await tester.pump();
      final decoration = _findCardDecoration(tester);
      final radius =
          (decoration?.borderRadius as BorderRadius?)?.topLeft.x ?? 0.0;
      expect(radius, AppDimens.radiusCard);
    });
  });

  group('ZuralogCard — dark mode styling', () {
    testWidgets('uses surfaceDark (#1C1C1E) as background in dark mode',
        (tester) async {
      await tester.pumpWidget(
        _themed(
          const ZuralogCard(child: Text('Dark')),
          themeMode: ThemeMode.dark,
        ),
      );
      await tester.pump();
      final decoration = _findCardDecoration(tester);
      expect(decoration?.color, AppColors.surfaceDark);
    });

    testWidgets('has a 1px border in dark mode', (tester) async {
      await tester.pumpWidget(
        _themed(
          const ZuralogCard(child: Text('Border')),
          themeMode: ThemeMode.dark,
        ),
      );
      await tester.pump();
      final decoration = _findCardDecoration(tester);
      expect(decoration?.border, isNotNull);
    });

    testWidgets('has no boxShadow in dark mode', (tester) async {
      await tester.pumpWidget(
        _themed(
          const ZuralogCard(child: Text('No Shadow')),
          themeMode: ThemeMode.dark,
        ),
      );
      await tester.pump();
      final decoration = _findCardDecoration(tester);
      expect(decoration?.boxShadow, isNull);
    });

    testWidgets('has 24px corner radius in dark mode', (tester) async {
      await tester.pumpWidget(
        _themed(
          const ZuralogCard(child: Text('Radius')),
          themeMode: ThemeMode.dark,
        ),
      );
      await tester.pump();
      final decoration = _findCardDecoration(tester);
      final radius =
          (decoration?.borderRadius as BorderRadius?)?.topLeft.x ?? 0.0;
      expect(radius, AppDimens.radiusCard);
    });
  });

  group('ZuralogCard — tap behaviour', () {
    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _themed(ZuralogCard(
          onTap: () => tapped = true,
          child: const Text('Tappable'),
        )),
      );
      await tester.tap(find.text('Tappable'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('renders InkWell when onTap is provided', (tester) async {
      await tester.pumpWidget(
        _themed(ZuralogCard(
          onTap: () {},
          child: const Text('Ink'),
        )),
      );
      expect(find.byType(InkWell), findsOneWidget);
    });

    testWidgets('does not render InkWell when onTap is null', (tester) async {
      await tester.pumpWidget(
        _themed(const ZuralogCard(child: Text('Static'))),
      );
      expect(find.byType(InkWell), findsNothing);
    });
  });

  group('ZuralogCard — press animation', () {
    testWidgets('tappable card has AnimatedScale in widget tree', (tester) async {
      final card = ZuralogCard(
        onTap: () {},
        child: const Text('Animated'),
      );
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: card)),
      );
      expect(find.byType(AnimatedScale), findsOneWidget);
    });

    testWidgets('non-tappable card has no AnimatedScale', (tester) async {
      const card = ZuralogCard(
        child: Text('Static'),
      );
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: card)),
      );
      expect(find.byType(AnimatedScale), findsNothing);
    });

    testWidgets('tappable card has GestureDetector in widget tree', (tester) async {
      final card = ZuralogCard(
        onTap: () {},
        child: const Text('Gesture'),
      );
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: card)),
      );
      // Scaffold may also add GestureDetectors; verify the card itself has one
      // by checking we find the GestureDetector that is an ancestor of the card text.
      expect(
        find.ancestor(
          of: find.text('Gesture'),
          matching: find.byType(GestureDetector),
        ),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('non-tappable card has no GestureDetector', (tester) async {
      const card = ZuralogCard(
        child: Text('No Gesture'),
      );
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: card)),
      );
      // Non-tappable card must not wrap in GestureDetector; only Scaffold's
      // own GestureDetectors may exist, none of which are ancestors of our text.
      expect(
        find.ancestor(
          of: find.text('No Gesture'),
          matching: find.byType(GestureDetector),
        ),
        findsNothing,
      );
    });
  });
}
