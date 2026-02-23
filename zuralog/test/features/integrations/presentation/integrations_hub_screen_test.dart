/// Zuralog — Integrations Hub Screen Tests.
///
/// Tests [IntegrationsHubScreen] with all Riverpod providers overridden so
/// no real network or platform calls are made.
///
/// Coverage:
///   - Smoke test: screen renders without throwing.
///   - Section headers "Connected", "Available", "Coming Soon" appear when
///     the corresponding integrations are present.
///   - Pull-to-refresh triggers [IntegrationsNotifier.loadIntegrations].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/integrations/domain/integration_model.dart';
import 'package:zuralog/features/integrations/domain/integrations_provider.dart';
import 'package:zuralog/features/integrations/presentation/integrations_hub_screen.dart';

// ── Stub Notifier ─────────────────────────────────────────────────────────────

/// A stub [IntegrationsNotifier] that uses a pre-set [IntegrationsState]
/// and records [loadIntegrations] calls.
class _StubIntegrationsNotifier
    extends StateNotifier<IntegrationsState>
    implements IntegrationsNotifier {
  _StubIntegrationsNotifier(super.initialState, this._loadCalls);

  final List<String> _loadCalls;

  @override
  void loadIntegrations() {
    _loadCalls.add('loadIntegrations');
  }

  @override
  Future<void> connect(String integrationId, BuildContext context) async {}

  @override
  void disconnect(String integrationId) {}

  @override
  Future<bool> requestHealthPermissions() async => false;
}

// ── Fixtures ──────────────────────────────────────────────────────────────────

/// An integration in the "connected" group.
const _connectedIntegration = IntegrationModel(
  id: 'strava',
  name: 'Strava',
  logoAsset: 'assets/integrations/strava.png',
  status: IntegrationStatus.connected,
  description: 'Sync runs and rides.',
);

/// An integration in the "available" group.
const _availableIntegration = IntegrationModel(
  id: 'fitbit',
  name: 'Fitbit',
  logoAsset: 'assets/integrations/fitbit.png',
  status: IntegrationStatus.available,
  description: 'Import activity data.',
);

/// An integration in the "coming soon" group.
const _comingSoonIntegration = IntegrationModel(
  id: 'garmin',
  name: 'Garmin',
  logoAsset: 'assets/integrations/garmin.png',
  status: IntegrationStatus.comingSoon,
  description: 'Connect Garmin devices.',
);

// ── Harness ───────────────────────────────────────────────────────────────────

/// Builds a testable [IntegrationsHubScreen] widget tree.
///
/// [integrations] is the initial list shown on screen.
/// [loadCalls] is populated each time [loadIntegrations] is called.
Widget _buildHarness({
  List<IntegrationModel> integrations = const [],
  List<String>? loadCalls,
}) {
  final calls = loadCalls ?? [];
  final initialState = IntegrationsState(integrations: integrations);

  return ProviderScope(
    overrides: [
      integrationsProvider.overrideWith(
        (ref) => _StubIntegrationsNotifier(initialState, calls),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.dark,
      home: const IntegrationsHubScreen(),
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('IntegrationsHubScreen', () {
    testWidgets('smoke test: renders without crashing', (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows "Connected" section header when connected integrations exist',
        (tester) async {
      await tester.pumpWidget(
        _buildHarness(integrations: [_connectedIntegration]),
      );
      await tester.pump();
      expect(find.text('Connected'), findsOneWidget);
    });

    testWidgets('shows "Available" section header when available integrations exist',
        (tester) async {
      await tester.pumpWidget(
        _buildHarness(integrations: [_availableIntegration]),
      );
      await tester.pump();
      expect(find.text('Available'), findsOneWidget);
    });

    testWidgets('shows "Coming Soon" section header when comingSoon integrations exist',
        (tester) async {
      await tester.pumpWidget(
        _buildHarness(integrations: [_comingSoonIntegration]),
      );
      await tester.pump();
      expect(find.text('Coming Soon'), findsOneWidget);
    });

    testWidgets('shows all three section headers when all groups are populated',
        (tester) async {
      await tester.pumpWidget(
        _buildHarness(
          integrations: [
            _connectedIntegration,
            _availableIntegration,
            _comingSoonIntegration,
          ],
        ),
      );
      await tester.pump();

      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('Available'), findsOneWidget);
      expect(find.text('Coming Soon'), findsOneWidget);
    });

    testWidgets('does not show "Connected" header when no connected integrations',
        (tester) async {
      await tester.pumpWidget(
        _buildHarness(integrations: [_availableIntegration]),
      );
      await tester.pump();
      expect(find.text('Connected'), findsNothing);
    });

    testWidgets('pull-to-refresh triggers loadIntegrations', (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(
        _buildHarness(
          integrations: [_availableIntegration],
          loadCalls: calls,
        ),
      );
      await tester.pump();

      // Clear calls from initState.
      calls.clear();

      // Perform a drag-down to trigger RefreshIndicator.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
      await tester.pumpAndSettle();

      expect(calls, contains('loadIntegrations'));
    });
  });
}
