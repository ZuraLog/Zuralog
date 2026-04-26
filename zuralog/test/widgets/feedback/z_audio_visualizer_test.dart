/// Widget tests for [ZAudioVisualizer].
///
/// Smoke tests confirming the widget mounts without error at both
/// ends of the [level] range.  Animation internals (controller ticks,
/// exact heights) are not tested here — they require [pump(Duration)]
/// and live outside the scope of these unit-level checks.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/core/theme/app_theme.dart';
import 'package:zuralog/shared/widgets/feedback/z_audio_visualizer.dart';

/// Wraps [child] in a themed [MaterialApp] so theme resolution works.
Widget _themed(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    home: Scaffold(
      body: Center(child: child),
    ),
  );
}

void main() {
  group('ZAudioVisualizer', () {
    testWidgets('renders without error at level 0', (tester) async {
      await tester.pumpWidget(
        _themed(const ZAudioVisualizer(level: 0.0)),
      );

      expect(find.byType(ZAudioVisualizer), findsOneWidget);
    });

    testWidgets('renders without error at max level', (tester) async {
      await tester.pumpWidget(
        _themed(const ZAudioVisualizer(level: 1.0)),
      );

      expect(find.byType(ZAudioVisualizer), findsOneWidget);
    });
  });
}
