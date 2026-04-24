library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/auth/domain/user_profile.dart';
import 'package:zuralog/features/body/domain/body_state.dart';
import 'package:zuralog/features/body/domain/coach_message.dart';
import 'package:zuralog/features/body/providers/body_now_coach_message_provider.dart';
import 'package:zuralog/features/body/providers/pillar_metrics_providers.dart';
import 'package:zuralog/features/body/providers/body_state_provider.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/progress/providers/progress_providers.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/features/today/domain/log_summary_models.dart';
import 'package:zuralog/features/today/domain/today_models.dart';
import 'package:zuralog/features/today/presentation/today_feed_screen.dart';
import 'package:zuralog/features/today/presentation/widgets/body_now/body_now_hero_card.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/cards/z_daily_goals_card.dart';

// ── Asset stubs ────────────────────────────────────────────────────────────────
// The Today screen renders BodyNowHeroCard which loads body_map.svg via
// rootBundle, and BodyNowCoachStrip which loads pattern PNGs. Both must be
// stubbed so asset loading resolves instantly in the test environment.

// Minimal 1×1 PNG — valid enough for the image codec not to throw.
const _kPng1x1 = <int>[
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
  0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
  0xde, 0x00, 0x00, 0x00, 0x0c, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9c, 0x63, 0xf8, 0xcf, 0xf0, 0x1f,
  0x00, 0x04, 0x00, 0x01, 0xff, 0x22, 0x0a, 0x3a,
  0xf0, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e,
  0x44, 0xae, 0x42, 0x60, 0x82,
];

// Minimal SVG — valid enough for flutter_svg not to throw.
const _kMinimalSvg = '<svg xmlns="http://www.w3.org/2000/svg" '
    'viewBox="0 0 100 100"><path id="chest_left_front" '
    'style="fill:#888888" d="M0 0h50v100H0z"/></svg>';

const _kBodyMapKey = 'assets/images/body_map.svg';
const _kPatternAssets = {
  'assets/brand/pattern/Original.PNG',
  'assets/brand/pattern/Sage.PNG',
  'assets/brand/pattern/Crimson.PNG',
  'assets/brand/pattern/Green.PNG',
  'assets/brand/pattern/Periwinkle.PNG',
  'assets/brand/pattern/Rose.PNG',
  'assets/brand/pattern/Amber.PNG',
  'assets/brand/pattern/Sky Blue.PNG',
  'assets/brand/pattern/Teal.PNG',
  'assets/brand/pattern/Purple.PNG',
  'assets/brand/pattern/Yellow.PNG',
  'assets/brand/pattern/Mint.PNG',
};

ByteData _buildManifestBin() {
  final entries = <String, Object>{
    _kBodyMapKey: <Object>[],
    for (final path in _kPatternAssets) path: <Object>[],
  };
  final data = const StandardMessageCodec().encodeMessage(entries);
  return ByteData.sublistView(
    data!.buffer.asUint8List(0, data.lengthInBytes),
  );
}

void _installAssetMocks() {
  final manifestBin = _buildManifestBin();
  final svgBytes = ByteData.sublistView(
    Uint8List.fromList(_kMinimalSvg.codeUnits),
  );
  final pngBytes = ByteData.sublistView(Uint8List.fromList(_kPng1x1));

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (ByteData? message) async {
    final key = utf8.decode(message!.buffer.asUint8List());
    if (key == _kBodyMapKey) return svgBytes;
    if (key == 'AssetManifest.bin') return manifestBin;
    if (key == 'AssetManifest.json') {
      final map = {
        _kBodyMapKey: <Object>[],
        for (final p in _kPatternAssets) p: <Object>[],
      };
      return ByteData.sublistView(
        Uint8List.fromList(
          '{${map.entries.map((e) => '"${e.key}":[]').join(',')}}'.codeUnits,
        ),
      );
    }
    if (_kPatternAssets.contains(key)) return pngBytes;
    return null;
  });
}

void _removeAssetMocks() {
  rootBundle.clear();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', null);
}

// ── Pump helper ────────────────────────────────────────────────────────────────
// pumpAndSettle never settles because BodyNowCoachStrip contains a
// ZPatternOverlay with animate:true (a 20-second repeating animation).
// Drive the clock forward by fixed intervals instead.
Future<void> _pump(WidgetTester tester) async {
  await tester.pump();                                     // first build
  await tester.pump(const Duration(milliseconds: 100));   // microtasks / futures
  await tester.pump(const Duration(milliseconds: 500));   // FutureProviders settle
  await tester.pump(const Duration(milliseconds: 500));   // delayed animations
  await tester.pump(const Duration(milliseconds: 500));   // trailing rebuilds
}

// ── Stubs ──────────────────────────────────────────────────────────────────────

class _StubUserProfileNotifier extends UserProfileNotifier {
  @override
  UserProfile? build() => null;
}

class _StubUserPreferencesNotifier extends UserPreferencesNotifier {
  @override
  Future<UserPreferencesModel> build() async {
    return const UserPreferencesModel(id: 'test', userId: 'test');
  }

  @override
  Future<void> save(UserPreferencesModel updated) async {
    state = AsyncData(updated);
  }

  @override
  Future<void> mutate(
      UserPreferencesModel Function(UserPreferencesModel) fn) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(fn(current));
  }

  @override
  Future<void> refresh() async {}
}

// ── Shared test stub for CoachMessage ─────────────────────────────────────────
const _kStubCoachMessage = CoachMessage(
  text: 'hi',
  ctaLabel: 'Connect',
  ctaRoute: '/settings/integrations',
);

// ── Router ────────────────────────────────────────────────────────────────────

GoRouter _router() => GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const TodayFeedScreen(),
        ),
      ],
    );

// ── Default provider overrides ────────────────────────────────────────────────

ProviderContainer _container({
  List<DailyGoal> dailyGoals = const [],
}) =>
    ProviderContainer(
      overrides: [
        userProfileProvider.overrideWith(() => _StubUserProfileNotifier()),
        userPreferencesProvider
            .overrideWith(() => _StubUserPreferencesNotifier()),
        healthScoreProvider.overrideWith(
          (ref) async =>
              const HealthScoreData(score: 78, trend: [], dataDays: 5),
        ),
        todayFeedProvider.overrideWith(
          (ref) async => TodayFeedData(insights: [], streak: null),
        ),
        todayLogSummaryProvider.overrideWith(
          (ref) async => TodayLogSummary.empty,
        ),
        userLoggedTypesProvider.overrideWith(
          (ref) async => const <String>{},
        ),
        goalsProvider.overrideWith(
          (ref) async => const GoalList(goals: []),
        ),
        dailyGoalsProvider.overrideWith(
          (ref) async => dailyGoals,
        ),
        bodyStateProvider.overrideWith((ref) async => BodyState.empty),
        pillarMetricsProvider
            .overrideWith((ref) async => PillarMetrics.empty),
        bodyNowCoachMessageProvider
            .overrideWith((ref) async => _kStubCoachMessage),
      ],
    );

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(_installAssetMocks);
  tearDown(_removeAssetMocks);

  group('TodayFeedScreen', () {
    testWidgets('renders without error', (tester) async {
      final container = _container();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: _router()),
        ),
      );
      await _pump(tester);
      expect(find.byType(TodayFeedScreen), findsOneWidget);
    });

    testWidgets('renders BodyNowHeroCard at the top of the feed',
        (tester) async {
      final container = _container();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: _router()),
        ),
      );
      await _pump(tester);
      expect(find.byType(BodyNowHeroCard), findsOneWidget);
    });

    testWidgets('does NOT render Quick Actions section', (tester) async {
      final container = _container();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: _router()),
        ),
      );
      await _pump(tester);
      expect(find.text('Quick Actions'), findsNothing);
    });

    testWidgets('does NOT render Wellness Check-in card', (tester) async {
      final container = _container();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: _router()),
        ),
      );
      await _pump(tester);
      expect(find.text('How are you feeling today?'), findsNothing);
    });

    testWidgets('renders ZDailyGoalsCard with setup prompt', (tester) async {
      // dailyGoalsProvider returns empty list → card shows setup prompt.
      final container = _container();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: _router()),
        ),
      );
      await _pump(tester);
      // The BodyNowHeroCard is taller than before (body diagram = 240px), so
      // ZDailyGoalsCard is below the fold. Scroll down to bring it into the
      // lazy ListView render window before asserting.
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await _pump(tester);
      expect(find.byType(ZDailyGoalsCard), findsOneWidget);
      expect(find.text('Set a daily goal'), findsOneWidget);
    });

    testWidgets(
        'renders ZDailyGoalsCard with goal progress bars when data is present',
        (tester) async {
      final container = _container(
        dailyGoals: const [
          DailyGoal(
            id: 'g1',
            label: 'Steps',
            current: 6240,
            target: 8000,
            unit: 'steps',
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: _router()),
        ),
      );
      await _pump(tester);
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await _pump(tester);
      expect(find.byType(ZDailyGoalsCard), findsOneWidget);
      expect(find.text('Steps'), findsOneWidget);
      expect(find.text('Set a daily goal'), findsNothing);
    });

    testWidgets(
        'invalidates dailyGoalsProvider when goalsProvider emits new data',
        (tester) async {
      var dailyGoalsFetchCount = 0;

      final container = ProviderContainer(
        overrides: [
          userProfileProvider.overrideWith(() => _StubUserProfileNotifier()),
          userPreferencesProvider
              .overrideWith(() => _StubUserPreferencesNotifier()),
          healthScoreProvider.overrideWith(
            (ref) async =>
                const HealthScoreData(score: 78, trend: [], dataDays: 5),
          ),
          todayFeedProvider.overrideWith(
            (ref) async => TodayFeedData(insights: [], streak: null),
          ),
          todayLogSummaryProvider.overrideWith(
            (ref) async => TodayLogSummary.empty,
          ),
          userLoggedTypesProvider.overrideWith(
            (ref) async => const <String>{},
          ),
          goalsProvider.overrideWith(
            (ref) async => const GoalList(goals: []),
          ),
          dailyGoalsProvider.overrideWith((ref) async {
            dailyGoalsFetchCount++;
            return const <DailyGoal>[];
          }),
          bodyStateProvider.overrideWith((ref) async => BodyState.empty),
          pillarMetricsProvider
              .overrideWith((ref) async => PillarMetrics.empty),
          bodyNowCoachMessageProvider
              .overrideWith((ref) async => _kStubCoachMessage),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: _router()),
        ),
      );
      await _pump(tester);
      // Scroll down so the lazy ListView renders _DailyGoalsSection and
      // begins watching dailyGoalsProvider for the first time.
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await _pump(tester);

      final initialFetchCount = dailyGoalsFetchCount;

      // Simulate the Progress tab invalidating goalsProvider after a goal change.
      container.invalidate(goalsProvider);
      await _pump(tester);

      // The ref.listen in TodayFeedScreen should have re-fetched dailyGoalsProvider.
      expect(dailyGoalsFetchCount, greaterThan(initialFetchCount));
    });

    // ── Building briefing state test ──────────────────────────────────────────

    testWidgets('shows "More insights unlock at Day 7" during building state',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          userProfileProvider.overrideWith(() => _StubUserProfileNotifier()),
          userPreferencesProvider
              .overrideWith(() => _StubUserPreferencesNotifier()),
          healthScoreProvider.overrideWith(
            (ref) async =>
                const HealthScoreData(score: 30, trend: [], dataDays: 4),
          ),
          todayFeedProvider.overrideWith(
            (ref) async => TodayFeedData(
              insights: [
                InsightCard(
                  id: 'i1',
                  title: 'Early observation',
                  summary: 'Test insight body',
                  type: InsightType.trend,
                  category: 'Sleep',
                  isRead: false,
                ),
              ],
              streak: null,
            ),
          ),
          todayLogSummaryProvider.overrideWith(
            (ref) async => TodayLogSummary.empty,
          ),
          userLoggedTypesProvider.overrideWith(
            (ref) async => const <String>{},
          ),
          goalsProvider.overrideWith(
            (ref) async => const GoalList(goals: []),
          ),
          dailyGoalsProvider.overrideWith((ref) async => const <DailyGoal>[]),
          bodyStateProvider.overrideWith((ref) async => BodyState.empty),
          pillarMetricsProvider
              .overrideWith((ref) async => PillarMetrics.empty),
          bodyNowCoachMessageProvider
              .overrideWith((ref) async => _kStubCoachMessage),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: _router()),
        ),
      );
      await _pump(tester);
      // Scroll down to reveal briefing section (below the fold).
      // The BodyNowHeroCard is taller than the old hero, so the briefing
      // section is deeper in the list — scroll further than before.
      await tester.drag(find.byType(ListView), const Offset(0, -1500));
      await _pump(tester);
      expect(find.text('More insights unlock at Day 7'), findsOneWidget);
      expect(find.text('Early observation'), findsOneWidget);
    });
  });
}
