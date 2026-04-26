import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zuralog/core/network/api_client.dart';
import 'package:zuralog/core/storage/prefs_service.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/features/today/data/weight_log_local_repository.dart';
import 'package:zuralog/features/today/data/weight_log_sync_service.dart';
import 'package:zuralog/features/today/domain/log_summary_models.dart';
import 'package:zuralog/features/today/domain/weight_log.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/log_panels/z_weight_log_panel.dart';

// ── Test doubles ───────────────────────────────────────────────────────────────

/// No-op sync service — suppresses all network calls in widget tests.
class _FakeWeightLogSyncService extends WeightLogSyncService {
  _FakeWeightLogSyncService(WeightLogLocalRepository repo)
      : super(localRepo: repo, client: ApiClient(dio: Dio()));

  @override
  Future<void> syncLog(WeightLog log) async {}

  @override
  Future<void> syncPending() async {}
}

// ── Test helpers ───────────────────────────────────────────────────────────────

Widget _wrap(
  Widget child, {
  required SharedPreferences prefs,
  Map<String, dynamic> latestWeight = const {},
}) {
  return ProviderScope(
    overrides: [
      prefsProvider.overrideWithValue(prefs),
      weightLogSyncServiceProvider.overrideWith(
        (ref) => _FakeWeightLogSyncService(
          ref.watch(weightLogLocalRepositoryProvider),
        ),
      ),
      todayLogSummaryProvider.overrideWith(
        (ref) async => TodayLogSummary.empty,
      ),
      latestLogValuesProvider(latestLogValuesKey(const {'weight'})).overrideWith(
        (ref) async => latestWeight.isEmpty
            ? const <String, dynamic>{}
            : {'weight': latestWeight},
      ),
      weightHistoryProvider.overrideWith((ref) async => List<double?>.filled(7, null)),
      unitsSystemProvider.overrideWithValue(UnitsSystem.metric),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

/// Pumps long enough for async FutureProvider overrides to resolve without
/// calling pumpAndSettle, which would hang on the continuous pattern overlay
/// animation inside ZButton.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  group('ZWeightLogPanel', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('Shows default 70.0 kg and dash when no previous log', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(_wrap(
        ZWeightLogPanel(onSave: (_) async {}, onBack: () {}),
        prefs: prefs,
      ));
      await _settle(tester);

      expect(find.textContaining('70'), findsOneWidget);
      expect(find.textContaining('Last logged: —'), findsOneWidget);
    });

    testWidgets('Pre-fills with latest logged weight from cloud brain', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(_wrap(
        ZWeightLogPanel(onSave: (_) async {}, onBack: () {}),
        prefs: prefs,
        latestWeight: {
          'value': 78.4,
          'date': '2026-03-15T08:22:00Z',
          'unit': 'kg',
        },
      ));
      await _settle(tester);

      expect(find.textContaining('78.4'), findsWidgets);
    });

    testWidgets('Delta indicator shows positive delta after increment', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(_wrap(
        ZWeightLogPanel(onSave: (_) async {}, onBack: () {}),
        prefs: prefs,
        latestWeight: {
          'value': 78.0,
          'date': '2026-03-15T08:22:00Z',
          'unit': 'kg',
        },
      ));
      // Extra pump so ref.listen + addPostFrameCallback populates _lastLoggedKg.
      await _settle(tester);
      await tester.pump();

      // Tap increment — value goes from 78.0 to 78.1, delta = +0.1 kg.
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pump();

      // _DeltaIndicator renders "↑ 0.1 kg" for a positive gain.
      expect(find.textContaining('↑'), findsOneWidget);
      expect(find.textContaining('0.1'), findsWidgets);
    });

    testWidgets('Save calls onSave with current value in kg', (tester) async {
      WeightLogData? savedData;
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(_wrap(
        ZWeightLogPanel(
          onSave: (data) async => savedData = data,
          onBack: () {},
        ),
        prefs: prefs,
      ));
      await _settle(tester);

      await tester.tap(find.widgetWithText(GestureDetector, 'Save Weight'));
      await tester.pump();
      // Pump past the SharedPreferences write and the 200 ms overlay delay.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(savedData, isNotNull);
      expect(savedData!.valueKg, closeTo(70.0, 0.1));
    });

    testWidgets('Last logged omits source for manual entries', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(_wrap(
        ZWeightLogPanel(onSave: (_) async {}, onBack: () {}),
        prefs: prefs,
        latestWeight: {
          'value': 75.0,
          'date': '2026-03-10T09:00:00Z',
          'unit': 'kg',
        },
      ));
      await _settle(tester);

      expect(find.textContaining('manual'), findsNothing);
      expect(find.textContaining('Manual'), findsNothing);
      expect(find.textContaining('Last logged:'), findsOneWidget);
    });
  });

  group('formatWeightDelta', () {
    test('gain: 80.0 → 80.5 kg shows "+0.5 kg"', () {
      expect(formatWeightDelta(80.0, 80.5), equals('+0.5 kg'));
    });

    test('loss: 80.0 → 79.3 kg shows "-0.7 kg"', () {
      expect(formatWeightDelta(80.0, 79.3), equals('-0.7 kg'));
    });

    test('no previous entry → null', () {
      expect(formatWeightDelta(null, 80.0), isNull);
    });

    test('negligible change (< 0.05 kg) → null', () {
      expect(formatWeightDelta(80.0, 80.02), isNull);
    });
  });
}
