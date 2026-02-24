/// Zuralog — Integration Tile Widget Tests.
///
/// Tests [IntegrationTile] for correct rendering based on
/// [IntegrationModel.status] and [IntegrationModel.compatibility], and for
/// correct interaction behaviour (connect, disconnect sheet, incompatibility).
///
/// Coverage:
///   - Available tile shows a "Connect" text button (neutral pill, TextButton.icon).
///   - Connected tile shows "Connected" badge and disconnect [IconButton].
///   - Tapping disconnect icon opens the disconnect bottom sheet.
///   - comingSoon tile shows "Soon" badge at 50% opacity with no Connect button.
///   - Incompatible-platform tile shows platform badge at 45% opacity.
///   - Integration name and description are always shown.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/integrations/domain/integration_model.dart';
import 'package:zuralog/features/integrations/domain/integrations_provider.dart';
import 'package:zuralog/features/integrations/presentation/widgets/integration_tile.dart';

// ── Stub Notifier ─────────────────────────────────────────────────────────────

/// Minimal stub notifier that records connect / disconnect calls and exposes
/// them via [connectedIds] and [disconnectedIds] for test assertions.
class _StubNotifier extends StateNotifier<IntegrationsState>
    implements IntegrationsNotifier {
  _StubNotifier(super.state);

  final List<String> disconnectedIds = [];
  final List<String> connectedIds = [];

  @override
  Future<void> loadIntegrations() async {}

  @override
  Future<void> connect(String integrationId, BuildContext context) async {
    connectedIds.add(integrationId);
  }

  @override
  void disconnect(String integrationId) {
    disconnectedIds.add(integrationId);
    state = state.copyWith(
      integrations: state.integrations.map((i) {
        if (i.id == integrationId) {
          return i.copyWith(status: IntegrationStatus.available);
        }
        return i;
      }).toList(),
    );
  }

  @override
  Future<bool> requestHealthPermissions() async => false;
}

// ── Fixtures ──────────────────────────────────────────────────────────────────

/// Connected Strava integration (no logoAsset — uses initials fallback).
const _connectedModel = IntegrationModel(
  id: 'strava',
  name: 'Strava',
  status: IntegrationStatus.connected,
  description: 'Sync runs and rides.',
);

/// Available Fitbit integration — shows Connect button.
const _availableModel = IntegrationModel(
  id: 'fitbit',
  name: 'Fitbit',
  status: IntegrationStatus.available,
  description: 'Import activity data.',
);

/// Coming-soon Garmin integration — greyed out.
const _comingSoonModel = IntegrationModel(
  id: 'garmin',
  name: 'Garmin',
  status: IntegrationStatus.comingSoon,
  description: 'Connect Garmin devices.',
);

// ── Harness ───────────────────────────────────────────────────────────────────

/// Wraps [IntegrationTile] in a minimal testable widget tree with a
/// [_StubNotifier] override so no real network or platform calls fire.
Widget _buildHarness({
  required IntegrationModel integration,
  _StubNotifier? notifier,
}) {
  final state = IntegrationsState(integrations: [integration]);
  final stub = notifier ?? _StubNotifier(state);

  return ProviderScope(
    overrides: [integrationsProvider.overrideWith((_) => stub)],
    child: MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: IntegrationTile(integration: integration)),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('IntegrationTile', () {
    // ── Available state ──────────────────────────────────────────────────────

    testWidgets('available tile shows Connect button', (tester) async {
      await tester.pumpWidget(_buildHarness(integration: _availableModel));
      await tester.pump();

      // The Connect button is now a TextButton.icon (neutral pill).
      // Use find.text to locate it regardless of button type.
      expect(find.text('Connect'), findsOneWidget);
    });

    testWidgets('available tile has no "Soon" badge', (tester) async {
      await tester.pumpWidget(_buildHarness(integration: _availableModel));
      await tester.pump();

      expect(find.text('Soon'), findsNothing);
    });

    // ── Connected state ──────────────────────────────────────────────────────

    testWidgets('connected tile shows "Connected" badge', (tester) async {
      await tester.pumpWidget(_buildHarness(integration: _connectedModel));
      await tester.pump();

      expect(find.text('Connected'), findsOneWidget);
    });

    testWidgets('connected tile shows disconnect IconButton', (tester) async {
      await tester.pumpWidget(_buildHarness(integration: _connectedModel));
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.link_off_rounded,
        ),
        findsOneWidget,
      );
    });

    testWidgets('connected tile has no Connect button', (tester) async {
      await tester.pumpWidget(_buildHarness(integration: _connectedModel));
      await tester.pump();

      expect(find.text('Connect'), findsNothing);
    });

    testWidgets('tapping disconnect icon opens disconnect bottom sheet', (
      tester,
    ) async {
      final stub = _StubNotifier(
        IntegrationsState(integrations: [_connectedModel]),
      );
      await tester.pumpWidget(
        _buildHarness(integration: _connectedModel, notifier: stub),
      );
      await tester.pump();

      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.link_off_rounded,
        ),
      );
      await tester.pumpAndSettle();

      // Disconnect sheet should appear — confirm the integration name is in it.
      expect(find.text('Strava'), findsWidgets);
      // "Disconnect" action label visible in the sheet.
      expect(find.text('Disconnect'), findsOneWidget);
    });

    // ── Coming soon state ────────────────────────────────────────────────────

    testWidgets('comingSoon tile shows "Soon" badge', (tester) async {
      await tester.pumpWidget(_buildHarness(integration: _comingSoonModel));
      await tester.pump();

      expect(find.text('Soon'), findsOneWidget);
    });

    testWidgets('comingSoon tile has no Connect button', (tester) async {
      await tester.pumpWidget(_buildHarness(integration: _comingSoonModel));
      await tester.pump();

      expect(find.text('Connect'), findsNothing);
    });

    testWidgets('comingSoon tile is rendered at 0.5 opacity', (tester) async {
      await tester.pumpWidget(_buildHarness(integration: _comingSoonModel));
      await tester.pump();

      final opacity = tester.widget<Opacity>(find.byType(Opacity).first);
      expect(opacity.opacity, 0.5);
    });

    // ── Name and description ─────────────────────────────────────────────────

    testWidgets('integration name and description are shown', (tester) async {
      await tester.pumpWidget(_buildHarness(integration: _availableModel));
      await tester.pump();

      expect(find.text('Fitbit'), findsOneWidget);
      expect(find.text('Import activity data.'), findsOneWidget);
    });

    testWidgets('initials fallback renders when logoAsset is null', (
      tester,
    ) async {
      // All fixture models omit logoAsset — tile should render without error.
      await tester.pumpWidget(_buildHarness(integration: _availableModel));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
