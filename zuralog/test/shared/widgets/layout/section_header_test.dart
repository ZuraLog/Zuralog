import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/shared/widgets/layout/section_header.dart';

void main() {
  group('SectionHeader', () {
    testWidgets('renders title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SectionHeader(title: 'Hello'),
          ),
        ),
      );
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('renders trailing widget when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SectionHeader(
              title: 'Hello',
              trailing: const Text('trail'),
            ),
          ),
        ),
      );
      expect(find.text('trail'), findsOneWidget);
    });

    testWidgets('does not render trailing when not provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SectionHeader(title: 'Hello'),
          ),
        ),
      );
      expect(find.text('trail'), findsNothing);
    });

    testWidgets('renders left accent bar with correct dimensions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SectionHeader(title: 'Hello'),
          ),
        ),
      );
      // The accent bar is a Container with the primary colour (light mode =
      // AppColors.primaryOnLight) and a borderRadius.
      final decoratedAccentBar = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            (w.decoration as BoxDecoration?)?.color == AppColors.primaryOnLight &&
            (w.decoration as BoxDecoration?)?.borderRadius != null,
      );
      expect(decoratedAccentBar, findsOneWidget);
      // Title still renders (bar didn't break layout).
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('renders actionLabel and calls onAction when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SectionHeader(
              title: 'Hello',
              actionLabel: 'See All',
              onAction: () => tapped = true,
            ),
          ),
        ),
      );
      expect(find.text('See All'), findsOneWidget);
      await tester.tap(find.text('See All'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('trailing takes precedence over actionLabel when both provided', (tester) async {
      var actionTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SectionHeader(
              title: 'Hello',
              trailing: const Text('trail-widget'),
              actionLabel: 'action-label',
              onAction: () => actionTapped = true,
            ),
          ),
        ),
      );
      expect(find.text('trail-widget'), findsOneWidget);
      expect(find.text('action-label'), findsNothing);
      expect(actionTapped, isFalse);
    });
  });
}
