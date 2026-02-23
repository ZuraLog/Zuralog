/// Widget tests for [PrimaryButton].
///
/// Verifies rendering, label display, loading state, and tap behaviour.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/core/theme/app_theme.dart';
import 'package:zuralog/shared/widgets/buttons/primary_button.dart';

/// Wraps [child] in a minimal themed [MaterialApp] so that theme-dependent
/// widgets (buttons, colors) resolve correctly.
Widget _themed(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('PrimaryButton — rendering', () {
    testWidgets('displays the label text', (tester) async {
      await tester.pumpWidget(
        _themed(const PrimaryButton(label: 'Get Started', onPressed: null)),
      );
      expect(find.text('Get Started'), findsOneWidget);
    });

    testWidgets('renders as an ElevatedButton', (tester) async {
      await tester.pumpWidget(
        _themed(const PrimaryButton(label: 'Test', onPressed: null)),
      );
      expect(find.byType(ElevatedButton), findsOneWidget);
    });
  });

  group('PrimaryButton — tap behaviour', () {
    testWidgets('calls onPressed when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _themed(PrimaryButton(label: 'Tap Me', onPressed: () => tapped = true)),
      );
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('does NOT call onPressed when onPressed is null', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _themed(PrimaryButton(label: 'Disabled', onPressed: null)),
      );
      await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
      await tester.pump();
      expect(tapped, isFalse);
    });
  });

  group('PrimaryButton — loading state', () {
    testWidgets('shows CircularProgressIndicator when isLoading is true',
        (tester) async {
      await tester.pumpWidget(
        _themed(const PrimaryButton(
          label: 'Loading',
          isLoading: true,
          onPressed: null,
        )),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('hides label text when isLoading is true', (tester) async {
      await tester.pumpWidget(
        _themed(const PrimaryButton(
          label: 'Submit',
          isLoading: true,
          onPressed: null,
        )),
      );
      expect(find.text('Submit'), findsNothing);
    });

    testWidgets('does not call onPressed when isLoading is true',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _themed(PrimaryButton(
          label: 'Submit',
          isLoading: true,
          onPressed: () => tapped = true,
        )),
      );
      await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
      await tester.pump();
      expect(tapped, isFalse);
    });

    testWidgets('shows label and no spinner when isLoading is false',
        (tester) async {
      await tester.pumpWidget(
        _themed(const PrimaryButton(
          label: 'Ready',
          isLoading: false,
          onPressed: null,
        )),
      );
      expect(find.text('Ready'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
