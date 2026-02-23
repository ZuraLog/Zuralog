/// Zuralog — Disconnect Sheet Tests.
///
/// Tests the [showDisconnectSheet] function / [_DisconnectSheetContent] widget.
///
/// Coverage:
///   - Sheet shows the integration name.
///   - "Keep Connected" button dismisses the sheet without calling [onConfirm].
///   - "Disconnect" button calls [onConfirm].
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/integrations/domain/integration_model.dart';
import 'package:zuralog/features/integrations/presentation/widgets/disconnect_sheet.dart';

// ── Fixture ───────────────────────────────────────────────────────────────────

const _integration = IntegrationModel(
  id: 'strava',
  name: 'Strava',
  logoAsset: 'assets/integrations/strava.png',
  status: IntegrationStatus.connected,
  description: 'Sync runs and rides.',
);

// ── Harness ───────────────────────────────────────────────────────────────────

/// A simple test screen that has a button to open the disconnect sheet.
///
/// [onConfirm] is called when the user confirms disconnection.
class _TestScreen extends StatelessWidget {
  const _TestScreen({required this.onConfirm});

  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => showDisconnectSheet(context, _integration, onConfirm),
          child: const Text('Open Sheet'),
        ),
      ),
    );
  }
}

/// Opens the disconnect sheet and pumps until it is visible.
Future<void> _openSheet(
  WidgetTester tester, {
  required VoidCallback onConfirm,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: _TestScreen(onConfirm: onConfirm),
    ),
  );
  await tester.tap(find.text('Open Sheet'));
  await tester.pumpAndSettle();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('showDisconnectSheet', () {
    testWidgets('shows integration name in the sheet', (tester) async {
      await _openSheet(tester, onConfirm: () {});

      // The name should appear at least once inside the sheet.
      expect(find.text('Strava'), findsWidgets);
    });

    testWidgets('shows warning text mentioning the integration name',
        (tester) async {
      await _openSheet(tester, onConfirm: () {});

      expect(
        find.textContaining('Strava'),
        findsWidgets,
      );
    });

    testWidgets('"Keep Connected" button closes sheet without calling onConfirm',
        (tester) async {
      var confirmed = false;
      await _openSheet(tester, onConfirm: () => confirmed = true);

      await tester.tap(find.text('Keep Connected'));
      await tester.pumpAndSettle();

      // Sheet is dismissed.
      expect(find.text('Keep Connected'), findsNothing);
      // Confirm callback was NOT called.
      expect(confirmed, isFalse);
    });

    testWidgets('"Disconnect" button calls onConfirm', (tester) async {
      var confirmed = false;
      await _openSheet(tester, onConfirm: () => confirmed = true);

      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();

      expect(confirmed, isTrue);
    });

    testWidgets('"Disconnect" button dismisses the sheet', (tester) async {
      await _openSheet(tester, onConfirm: () {});

      await tester.tap(find.text('Disconnect'));
      await tester.pumpAndSettle();

      expect(find.text('Disconnect'), findsNothing);
    });
  });
}
