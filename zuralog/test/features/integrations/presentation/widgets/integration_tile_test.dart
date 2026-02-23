/// Zuralog — Integration Tile Widget Tests.
///
/// Tests [IntegrationTile] for correct rendering based on
/// [IntegrationModel.status] and correct interaction behaviour.
///
/// Coverage:
///   - Connected tile shows [CupertinoSwitch] in the on state.
///   - comingSoon tile shows "Soon" badge and is non-interactive (opacity 0.5).
///   - Tapping the switch on a connected tile opens the disconnect sheet.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/integrations/domain/integration_model.dart';
import 'package:zuralog/features/integrations/domain/integrations_provider.dart';
import 'package:zuralog/features/integrations/presentation/widgets/integration_tile.dart';

// ── Stub Notifier ─────────────────────────────────────────────────────────────

/// Minimal stub notifier that tracks disconnect calls.
class _StubNotifier extends StateNotifier<IntegrationsState>
    implements IntegrationsNotifier {
  _StubNotifier(super.state);

  final List<String> disconnectedIds = [];
  final List<String> connectedIds = [];

  @override
  void loadIntegrations() {}

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

const _connectedModel = IntegrationModel(
  id: 'strava',
  name: 'Strava',
  logoAsset: 'assets/integrations/strava.png',
  status: IntegrationStatus.connected,
  description: 'Sync runs and rides.',
);

const _availableModel = IntegrationModel(
  id: 'fitbit',
  name: 'Fitbit',
  logoAsset: 'assets/integrations/fitbit.png',
  status: IntegrationStatus.available,
  description: 'Import activity data.',
);

const _comingSoonModel = IntegrationModel(
  id: 'garmin',
  name: 'Garmin',
  logoAsset: 'assets/integrations/garmin.png',
  status: IntegrationStatus.comingSoon,
  description: 'Connect Garmin devices.',
);

// ── Harness ───────────────────────────────────────────────────────────────────

/// Wraps [IntegrationTile] in a testable widget tree.
Widget _buildHarness({
  required IntegrationModel integration,
  _StubNotifier? notifier,
}) {
  final state = IntegrationsState(integrations: [integration]);
  final stub = notifier ?? _StubNotifier(state);

  return ProviderScope(
    overrides: [
      integrationsProvider.overrideWith((_) => stub),
    ],
    child: MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: IntegrationTile(integration: integration),
      ),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('IntegrationTile', () {
    testWidgets('connected tile shows CupertinoSwitch in on state',
        (tester) async {
      await tester.pumpWidget(_buildHarness(integration: _connectedModel));
      await tester.pump();

      final switchWidget = tester.widget<CupertinoSwitch>(
        find.byType(CupertinoSwitch),
      );
      expect(switchWidget.value, isTrue);
    });

    testWidgets('available tile shows CupertinoSwitch in off state',
        (tester) async {
      await tester.pumpWidget(_buildHarness(integration: _availableModel));
      await tester.pump();

      final switchWidget = tester.widget<CupertinoSwitch>(
        find.byType(CupertinoSwitch),
      );
      expect(switchWidget.value, isFalse);
    });

    testWidgets('comingSoon tile shows "Soon" badge', (tester) async {
      await tester.pumpWidget(_buildHarness(integration: _comingSoonModel));
      await tester.pump();

      expect(find.text('Soon'), findsOneWidget);
    });

    testWidgets('comingSoon tile has no CupertinoSwitch', (tester) async {
      await tester.pumpWidget(_buildHarness(integration: _comingSoonModel));
      await tester.pump();

      expect(find.byType(CupertinoSwitch), findsNothing);
    });

    testWidgets('comingSoon tile is rendered at 0.5 opacity', (tester) async {
      await tester.pumpWidget(_buildHarness(integration: _comingSoonModel));
      await tester.pump();

      final opacity = tester.widget<Opacity>(find.byType(Opacity).first);
      expect(opacity.opacity, 0.5);
    });

    testWidgets(
        'tapping connected switch opens disconnect bottom sheet',
        (tester) async {
      final stub = _StubNotifier(
        IntegrationsState(integrations: [_connectedModel]),
      );
      await tester.pumpWidget(
        _buildHarness(integration: _connectedModel, notifier: stub),
      );
      await tester.pump();

      // Tap the switch to toggle it off (connected → will disconnect).
      await tester.tap(find.byType(CupertinoSwitch));
      await tester.pumpAndSettle();

      // Disconnect sheet should have appeared with the integration name.
      expect(find.text('Strava'), findsWidgets);
      // "Disconnect" text button in the sheet.
      expect(find.text('Disconnect'), findsOneWidget);
    });

    testWidgets('integration name and description are shown', (tester) async {
      await tester.pumpWidget(_buildHarness(integration: _availableModel));
      await tester.pump();

      expect(find.text('Fitbit'), findsOneWidget);
      expect(find.text('Import activity data.'), findsOneWidget);
    });
  });
}
