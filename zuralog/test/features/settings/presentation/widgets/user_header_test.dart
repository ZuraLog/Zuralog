/// Zuralog Settings — UserHeader Widget Tests.
///
/// Verifies that [UserHeader] renders the display name, email, and avatar
/// correctly, and that tapping the avatar shows the coming-soon SnackBar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/settings/presentation/widgets/user_header.dart';

// ── Fixtures ──────────────────────────────────────────────────────────────────

/// Test email used in widget tests.
const String _kTestEmail = 'alice@zuralog.com';

// ── Harness ───────────────────────────────────────────────────────────────────

/// Renders [UserHeader] inside a minimal [ProviderScope] + [MaterialApp].
///
/// The [userEmailProvider] is overridden with [email].
Widget _buildHarness({String email = _kTestEmail}) {
  return ProviderScope(
    overrides: [
      userEmailProvider.overrideWith((ref) => email),
    ],
    child: MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
      ),
      home: const Scaffold(body: UserHeader()),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('UserHeader', () {
    testWidgets('renders without throwing', (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows the email address as text', (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump();
      // Email appears twice: once as the name (email-prefix fallback when
      // no profile is loaded) and once as the secondary email label.
      expect(find.text(_kTestEmail), findsAtLeast(1));
    });

    testWidgets('shows the first-letter initial in the avatar', (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump();

      // The initial should be the uppercase first character of the email.
      final initial = _kTestEmail[0].toUpperCase();
      expect(find.text(initial), findsOneWidget);
    });

    testWidgets('shows "Member since" text', (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump();
      expect(
        find.textContaining('Member since'),
        findsOneWidget,
      );
    });

    testWidgets('shows dash when email is empty', (tester) async {
      await tester.pumpWidget(_buildHarness(email: ''));
      await tester.pump();
      // When email is empty and no profile is loaded, the name column shows
      // '—' and no secondary email label is shown. At least one '—' appears.
      expect(find.text('—'), findsAtLeast(1));
    });

    testWidgets('tapping avatar shows coming-soon SnackBar', (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump();

      // Tap the avatar (the CircleAvatar containing the initial).
      await tester.tap(find.text(_kTestEmail[0].toUpperCase()));
      await tester.pump();

      expect(
        find.text('Profile photo — coming soon'),
        findsOneWidget,
      );
    });
  });
}
