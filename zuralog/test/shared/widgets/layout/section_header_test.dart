import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

    testWidgets('renders left accent bar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SectionHeader(title: 'Hello'),
          ),
        ),
      );
      expect(find.byType(SectionHeader), findsOneWidget);
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
