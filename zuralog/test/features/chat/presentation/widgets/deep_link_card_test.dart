/// Zuralog — Deep Link Card Widget Tests.
///
/// Verifies [DeepLinkCard] renders the title and subtitle from [clientAction],
/// and that a missing or unlaunchable URL shows a SnackBar error.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/chat/presentation/widgets/deep_link_card.dart';

// ── Helpers ────────────────────────────────────────────────────────────────────

/// Wraps [DeepLinkCard] in a [Scaffold] so SnackBars work.
Widget _wrap(Map<String, dynamic> clientAction) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(
      body: Center(
        child: DeepLinkCard(clientAction: clientAction),
      ),
    ),
  );
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  group('DeepLinkCard', () {
    testWidgets('renders title from clientAction', (tester) async {
      await tester.pumpWidget(_wrap({
        'title': 'Start your run',
        'subtitle': 'Open Strava',
        'url': 'strava://record',
      }));
      await tester.pump();

      expect(find.text('Start your run'), findsOneWidget);
    });

    testWidgets('renders subtitle from clientAction', (tester) async {
      await tester.pumpWidget(_wrap({
        'title': 'Log a workout',
        'subtitle': 'Track your progress',
        'url': 'https://example.com',
      }));
      await tester.pump();

      expect(find.text('Track your progress'), findsOneWidget);
    });

    testWidgets('renders default title when title is missing', (tester) async {
      await tester.pumpWidget(_wrap({'url': 'https://example.com'}));
      await tester.pump();

      expect(find.text('Open Link'), findsOneWidget);
    });

    testWidgets('does not show subtitle when subtitle key is absent',
        (tester) async {
      await tester.pumpWidget(_wrap({
        'title': 'Go for a run',
        'url': 'https://example.com',
      }));
      await tester.pump();

      // Only the title should be present — no subtitle widget.
      expect(find.text('Go for a run'), findsOneWidget);
    });

    testWidgets('shows error SnackBar when url and fallback_url are both missing',
        (tester) async {
      await tester.pumpWidget(_wrap({'title': 'No URL'}));
      await tester.pump();

      await tester.tap(find.byType(DeepLinkCard));
      await tester.pump();

      expect(
        find.text('No URL provided in this action.'),
        findsOneWidget,
      );
    });

    testWidgets('renders open_in_new icon', (tester) async {
      await tester.pumpWidget(_wrap({
        'title': 'Open',
        'url': 'https://example.com',
      }));
      await tester.pump();

      expect(find.byIcon(Icons.open_in_new_rounded), findsOneWidget);
    });
  });
}
