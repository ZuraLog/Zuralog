import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/features/data/presentation/widgets/viz/calendar_grid_viz.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  final days = List.generate(28, (i) => CalendarDay(
    dayNumber: i + 1,
    value: i % 5 < 3 ? 0.8 : 0.2,
    phase: i < 5 ? 'Menstrual' : (i < 14 ? 'Follicular' : 'Luteal'),
    phaseColor: i < 5 ? Colors.red : Colors.pink,
  ));
  final config = CalendarGridConfig(days: days, totalDays: 28);

  testWidgets('square: renders without exception', (tester) async {
    await tester.pumpWidget(_wrap(SizedBox(
      height: 100, width: 150,
      child: CalendarGridViz(config: config, color: Colors.pink, size: TileSize.square),
    )));
    expect(find.byType(CalendarGridViz), findsOneWidget);
  });

  testWidgets('renders without exception for all sizes', (tester) async {
    for (final size in TileSize.values) {
      await tester.pumpWidget(_wrap(SizedBox(
        height: 200, width: 200,
        child: CalendarGridViz(config: config, color: Colors.pink, size: size),
      )));
    }
  });
}
