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
///   - Search bar is present and functional.
///   - [CompatibleAppsSection] is always rendered.
///   - No-results empty state when search matches nothing.
///   - Filtering direct integrations by name hides non-matching items.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/integrations/domain/integration_model.dart';
import 'package:zuralog/features/integrations/domain/integrations_provider.dart';
import 'package:zuralog/features/integrations/presentation/integrations_hub_screen.dart';
import 'package:zuralog/features/integrations/presentation/widgets/compatible_apps_section.dart';
import 'package:zuralog/features/integrations/presentation/widgets/integrations_search_bar.dart';

// ── Stub Notifier ─────────────────────────────────────────────────────────────

/// A stub [IntegrationsNotifier] that uses a pre-set [IntegrationsState]
/// and records [loadIntegrations] calls.
class _StubIntegrationsNotifier extends StateNotifier<IntegrationsState>
    implements IntegrationsNotifier {
  _StubIntegrationsNotifier(super.initialState, this._loadCalls);

  final List<String> _loadCalls;

  @override
  Future<void> loadIntegrations() async {
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
  status: IntegrationStatus.connected,
  description: 'Sync runs and rides.',
);

/// An integration in the "available" group.
const _availableIntegration = IntegrationModel(
  id: 'fitbit',
  name: 'Fitbit',
  status: IntegrationStatus.available,
  description: 'Import activity data.',
);

/// An integration in the "coming soon" group.
const _comingSoonIntegration = IntegrationModel(
  id: 'garmin',
  name: 'Garmin',
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
    // ── Existing tests ────────────────────────────────────────────────────────

    testWidgets('smoke test: renders without crashing', (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'shows "Connected" section header when connected integrations exist',
      (tester) async {
        await tester.pumpWidget(
          _buildHarness(integrations: [_connectedIntegration]),
        );
        await tester.pump();
        // The section header AND the _ConnectedBadge on each tile both render
        // the text "Connected", so we assert at least one match rather than
        // exactly one.
        expect(find.text('Connected'), findsWidgets);
      },
    );

    testWidgets(
      'shows "Available" section header when available integrations exist',
      (tester) async {
        await tester.pumpWidget(
          _buildHarness(integrations: [_availableIntegration]),
        );
        await tester.pump();
        expect(find.text('Available'), findsOneWidget);
      },
    );

    testWidgets(
      'shows "Coming Soon" section header when comingSoon integrations exist',
      (tester) async {
        await tester.pumpWidget(
          _buildHarness(integrations: [_comingSoonIntegration]),
        );
        await tester.pump();
        expect(find.text('Coming Soon'), findsOneWidget);
      },
    );

    testWidgets(
      'shows all three section headers when all groups are populated',
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

        // "Connected" appears in both the section header and the tile badge.
        expect(find.text('Connected'), findsWidgets);
        expect(find.text('Available'), findsOneWidget);
        expect(find.text('Coming Soon'), findsOneWidget);
      },
    );

    testWidgets(
      'does not show "Connected" header when no connected integrations',
      (tester) async {
        await tester.pumpWidget(
          _buildHarness(integrations: [_availableIntegration]),
        );
        await tester.pump();
        expect(find.text('Connected'), findsNothing);
      },
    );

    testWidgets('pull-to-refresh triggers loadIntegrations', (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(
        _buildHarness(integrations: [_availableIntegration], loadCalls: calls),
      );
      await tester.pump();

      // Clear calls from initState.
      calls.clear();

      // Perform a drag-down to trigger RefreshIndicator.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
      await tester.pumpAndSettle();

      expect(calls, contains('loadIntegrations'));
    });

    // ── New search & compatible apps tests ────────────────────────────────────

    testWidgets('shows IntegrationsSearchBar', (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump();
      expect(find.byType(IntegrationsSearchBar), findsOneWidget);
    });

    testWidgets('shows CompatibleAppsSection', (tester) async {
      await tester.pumpWidget(_buildHarness());
      await tester.pump();
      expect(find.byType(CompatibleAppsSection), findsOneWidget);
    });

    testWidgets(
      'shows no-results text when search matches nothing in direct or compatible lists',
      (tester) async {
        // Start with an empty integrations list so there are no direct results
        // either; the "zzzzthiscannotmatchanything" query also matches no
        // compatible apps, so the no-results state must appear.
        await tester.pumpWidget(_buildHarness());
        await tester.pump();

        await tester.enterText(
          find.byType(TextField),
          'zzzzthiscannotmatchanything',
        );
        await tester.pump();

        expect(find.textContaining('No results for'), findsOneWidget);
      },
    );

    testWidgets(
      'hides no-results state when search matches a compatible app',
      (tester) async {
        // "Strava" matches CompatibleAppsRegistry even if no direct integration
        // is present, so the no-results state must NOT appear.
        await tester.pumpWidget(_buildHarness());
        await tester.pump();

        await tester.enterText(find.byType(TextField), 'Strava');
        await tester.pump();

        expect(find.textContaining('No results for'), findsNothing);
        expect(find.byType(CompatibleAppsSection), findsOneWidget);
      },
    );

    testWidgets(
      'filtering direct integrations by name hides non-matching section headers',
      (tester) async {
        await tester.pumpWidget(
          _buildHarness(
            integrations: [_connectedIntegration, _availableIntegration],
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Type "Strava" — should keep the Connected (Strava) section but hide
        // the Available (Fitbit) section header.
        await tester.enterText(find.byType(TextField), 'Strava');
        await tester.pump();

        // "Connected" section header should still be visible (Strava is connected).
        expect(find.text('Connected'), findsWidgets);
        // "Available" section header for Fitbit should be gone.
        expect(find.text('Available'), findsNothing);
      },
    );

    testWidgets(
      'search bar text is reflected in filtering (no crash on type)',
      (tester) async {
        await tester.pumpWidget(_buildHarness());
        await tester.pump(const Duration(milliseconds: 100));

        await tester.enterText(find.byType(TextField), 'Strava');
        await tester.pump();

        // At minimum the typed text exists somewhere in the widget tree.
        expect(find.text('Strava'), findsAtLeastNWidgets(1));
        expect(tester.takeException(), isNull);
      },
    );
  });
}
