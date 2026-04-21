library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zuralog/core/storage/prefs_service.dart';
import 'package:zuralog/features/workout/presentation/exercise_catalogue_screen.dart';

// ── Minimal valid 1×1 RGB PNG ─────────────────────────────────────────────────
// Returned for pattern image requests so the image codec does not throw.
// Generated with Python struct + zlib against the PNG spec.
const _kPng1x1 = <int>[
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, // signature
  0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52, // IHDR
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
  0xde, 0x00, 0x00, 0x00, 0x0c, 0x49, 0x44, 0x41, // IDAT
  0x54, 0x78, 0x9c, 0x63, 0xf8, 0xcf, 0xf0, 0x1f,
  0x00, 0x04, 0x00, 0x01, 0xff, 0x22, 0x0a, 0x3a,
  0xf0, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, // IEND
  0x44, 0xae, 0x42, 0x60, 0x82,
];

// ── Asset stub ─────────────────────────────────────────────────────────────────

const _exercisesKey = 'assets/data/exercises.json';

// All pattern PNG paths that ZPatternOverlay inside ZSearchBar / ZChip requests.
const _patternAssets = {
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

const _fixture = '['
    '{"id":"bench_press","name":"Bench Press","muscleGroup":"chest","equipment":"barbell","instructions":""},'
    '{"id":"pull_up","name":"Pull-Up","muscleGroup":"back","equipment":"bodyweight","instructions":""},'
    '{"id":"squat","name":"Back Squat","muscleGroup":"quads","equipment":"barbell","instructions":""},'
    '{"id":"running","name":"Running","muscleGroup":"cardio","equipment":"other","instructions":""}'
    ']';

// Build a binary AssetManifest that includes both exercise data and pattern PNGs
// so Flutter's asset manifest lookup succeeds before the load call.
ByteData _buildManifestBin() {
  final entries = <String, Object>{
    _exercisesKey: <Object>[],
    for (final path in _patternAssets) path: <Object>[],
  };
  final data = const StandardMessageCodec().encodeMessage(entries);
  return ByteData.sublistView(
    data!.buffer.asUint8List(0, data.lengthInBytes),
  );
}

void _installAssetMocks() {
  final manifestBin = _buildManifestBin();
  final exercisesBytes = ByteData.sublistView(utf8.encode(_fixture));
  final pngBytes = ByteData.sublistView(Uint8List.fromList(_kPng1x1));

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
    'flutter/assets',
    (ByteData? message) async {
      final key = utf8.decode(message!.buffer.asUint8List());

      if (key == _exercisesKey) return exercisesBytes;
      if (key == 'AssetManifest.bin') return manifestBin;
      if (key == 'AssetManifest.json') {
        // Legacy JSON manifest for older Flutter versions.
        final map = {
          _exercisesKey: <Object>[],
          for (final p in _patternAssets) p: <Object>[],
        };
        return ByteData.sublistView(utf8.encode(
          '{${map.entries.map((e) => '"${e.key}":[]').join(',')}}',
        ));
      }
      // Pattern PNGs — valid bytes so the image codec succeeds.
      if (_patternAssets.contains(key)) return pngBytes;
      // Everything else (fonts, etc.) — null; google_fonts falls back to
      // system font when allowRuntimeFetching is false.
      return null;
    },
  );
}

void _removeAssetMocks() {
  // Clear rootBundle's internal cache so the next test's mock handler is
  // actually called instead of returning stale cached bytes.
  rootBundle.clear();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', null);
}

// ── Test harness ───────────────────────────────────────────────────────────────

Widget _harness(SharedPreferences prefs) {
  final router = GoRouter(
    initialLocation: '/catalogue',
    routes: [
      GoRoute(
        path: '/catalogue',
        pageBuilder: (context, state) =>
            const MaterialPage(child: ExerciseCatalogueScreen()),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(body: Text('home')),
      ),
    ],
    redirect: (context, state) => null,
  );
  return ProviderScope(
    overrides: [
      prefsProvider.overrideWithValue(prefs),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

// Pump helper: gives the FutureProvider time to resolve without calling
// pumpAndSettle, which never settles due to the image-loading retry loop
// from ZPatternOverlay inside ZSearchBar.
//
// Three pump calls are used:
// 1. An initial pump to trigger the widget tree build.
// 2. A 300 ms advance to let both FutureProviders in the chain resolve.
//    (exerciseListProvider → exerciseSearchProvider, each with a microtask.)
// 3. A final 100 ms pump to capture any trailing setState / grid rebuild.
Future<void> _pump(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 100));
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  late SharedPreferences prefs;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Prevent google_fonts from loading fonts over the network or from assets
    // during tests — it falls back to the system font silently.
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  setUp(() {
    _installAssetMocks();
  });

  tearDown(() {
    _removeAssetMocks();
  });

  // Uses a wide (2400px) and tall (1920px) surface so that:
  // - All 14 muscle-group chips are visible without horizontal scrolling
  //   (each chip is ~100-120px wide, 14 chips × 120px = 1680px < 2400px)
  // - All 4 exercise grid tiles (2 rows) are visible without vertical scrolling
  // Both conditions eliminate ambiguous widget finders in chip/tile assertions.
  Future<void> pumpHarness(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 1920);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(_harness(prefs));
    await _pump(tester);
  }

  testWidgets('shows the full list on first open', (tester) async {
    await pumpHarness(tester);
    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Pull-Up'), findsOneWidget);
    expect(find.text('Back Squat'), findsOneWidget);
    expect(find.text('Running'), findsOneWidget);
  });

  testWidgets('tapping an exercise updates the bottom button label',
      (tester) async {
    await pumpHarness(tester);
    await tester.tap(find.text('Bench Press'));
    await _pump(tester);
    expect(find.text('Add Exercise'), findsOneWidget);
    await tester.tap(find.text('Pull-Up'));
    await _pump(tester);
    expect(find.text('Add 2 Exercises'), findsOneWidget);
  });

  testWidgets('tapping a selected exercise deselects it', (tester) async {
    await pumpHarness(tester);
    await tester.tap(find.text('Bench Press'));
    await _pump(tester);
    expect(find.text('Add Exercise'), findsOneWidget);
    await tester.tap(find.text('Bench Press'));
    await _pump(tester);
    expect(find.text('Add Exercise'), findsOneWidget);
  });

  testWidgets('muscle-group chip filters the grid', (tester) async {
    // The 2400px-wide harness ensures all muscle-group chips are visible
    // without horizontal scrolling. 'Cardio' also appears as the muscle-group
    // subtitle of the 'Running' tile, so we use find.text(...).at(0) to tap
    // the first match — which is the chip (rendered before the tile subtitles
    // in document order).
    await pumpHarness(tester);
    // Tap the first 'Cardio' widget — in this layout it is the chip because
    // chips are rendered above the grid in the Column.
    await tester.tap(find.text('Cardio').first);
    await _pump(tester);
    await _pump(tester);
    expect(find.text('Running'), findsOneWidget);
    expect(find.text('Bench Press'), findsNothing);
    await tester.tap(find.text('All').first);
    await _pump(tester);
    await _pump(tester);
    expect(find.text('Bench Press'), findsOneWidget);
  });

  testWidgets('typing in the search bar filters by name', (tester) async {
    await pumpHarness(tester);
    await tester.enterText(find.byType(TextFormField), 'pull');
    await _pump(tester);
    expect(find.text('Pull-Up'), findsOneWidget);
    expect(find.text('Bench Press'), findsNothing);
  });
}
