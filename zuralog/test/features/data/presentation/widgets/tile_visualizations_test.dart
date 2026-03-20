/// Smoke tests for all 14 tile visualization widgets.
///
/// Each test verifies the widget renders without throwing when given valid data,
/// and that key structural elements are present in the widget tree.
library;

import 'package:fl_chart/fl_chart.dart'
    hide BarChartData, LineChartData, BarChartGroupData;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/features/data/domain/tile_models.dart';
import 'package:zuralog/features/data/presentation/widgets/tile_visualizations.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 200,
          height: 200,
          child: child,
        ),
      ),
    );

// ---------------------------------------------------------------------------
// BarChartViz
// ---------------------------------------------------------------------------

void main() {
  group('BarChartViz', () {
    testWidgets('renders BarChart without exception', (tester) async {
      final data = BarChartData(
        dailyValues: [6000, 8000, 10000, 7500, 9000, 11000, 8432],
        dayLabels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
        average: 8568,
        delta: 500,
      );
      await tester.pumpWidget(_wrap(
        BarChartViz(data: data, categoryColor: AppColors.categoryActivity),
      ));
      await tester.pump();
      expect(find.byType(BarChart), findsOneWidget);
    });

    testWidgets('renders without average line', (tester) async {
      final data = BarChartData(
        dailyValues: [5000, 7000, 9000, 6000, 8000, 10000, 7000],
        dayLabels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      );
      await tester.pumpWidget(_wrap(
        BarChartViz(data: data, categoryColor: AppColors.categoryActivity),
      ));
      await tester.pump();
      expect(find.byType(BarChart), findsOneWidget);
    });
  });

  // ── RingViz ──────────────────────────────────────────────────────────────

  group('RingViz', () {
    testWidgets('renders CircularProgressIndicator or CustomPaint',
        (tester) async {
      await tester.pumpWidget(_wrap(
        RingViz(
          data: const RingData(value: 6.5, max: 8.0),
          categoryColor: AppColors.categorySleep,
        ),
      ));
      await tester.pump();
      expect(
        find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
            find.byType(CustomPaint).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('renders with goalLabel', (tester) async {
      await tester.pumpWidget(_wrap(
        RingViz(
          data: const RingData(value: 400, max: 500, goalLabel: 'Goal'),
          categoryColor: AppColors.categoryActivity,
        ),
      ));
      await tester.pump();
      expect(find.text('Goal'), findsOneWidget);
    });

    testWidgets('renders percentage when no goalLabel', (tester) async {
      await tester.pumpWidget(_wrap(
        RingViz(
          data: const RingData(value: 4.0, max: 8.0),
          categoryColor: AppColors.categorySleep,
        ),
      ));
      await tester.pump();
      expect(find.text('50%'), findsOneWidget);
    });
  });

  // ── LineChartViz ──────────────────────────────────────────────────────────

  group('LineChartViz', () {
    testWidgets('renders LineChart without exception', (tester) async {
      await tester.pumpWidget(_wrap(
        LineChartViz(
          data: const LineChartData(
            values: [58, 60, 57, 62, 59, 61, 60],
            rangeLow: 55,
            rangeHigh: 65,
            delta: -1,
          ),
          categoryColor: AppColors.categoryHeart,
        ),
      ));
      await tester.pump();
      expect(find.byType(LineChart), findsOneWidget);
    });

    testWidgets('renders without range band', (tester) async {
      await tester.pumpWidget(_wrap(
        LineChartViz(
          data: const LineChartData(values: [40, 42, 45, 43, 44, 41, 43]),
          categoryColor: AppColors.categoryHeart,
        ),
      ));
      await tester.pump();
      expect(find.byType(LineChart), findsOneWidget);
    });
  });

  // ── StackedBarViz ─────────────────────────────────────────────────────────

  group('StackedBarViz', () {
    testWidgets('renders without exception', (tester) async {
      await tester.pumpWidget(_wrap(
        const StackedBarViz(
          data: StackedBarData(
            segments: [
              (label: 'Deep', hours: 1.5),
              (label: 'REM', hours: 2.0),
              (label: 'Light', hours: 3.5),
              (label: 'Awake', hours: 0.5),
            ],
          ),
        ),
      ));
      await tester.pump();
      // Should render a Row with colored segments
      expect(find.byType(Row), findsWidgets);
    });
  });

  // ── AreaChartViz ──────────────────────────────────────────────────────────

  group('AreaChartViz', () {
    testWidgets('renders LineChart (area mode) without exception',
        (tester) async {
      await tester.pumpWidget(_wrap(
        AreaChartViz(
          data: const AreaChartData(
            values: [78.0, 77.5, 77.8, 77.2, 76.9, 77.1, 76.8],
            targetValue: 75.0,
            delta: -0.3,
          ),
          categoryColor: AppColors.categoryBody,
        ),
      ));
      await tester.pump();
      expect(find.byType(LineChart), findsOneWidget);
    });

    testWidgets('renders without target line', (tester) async {
      await tester.pumpWidget(_wrap(
        AreaChartViz(
          data: const AreaChartData(
            values: [80.0, 79.5, 79.0, 78.5, 78.0, 77.5, 77.0],
          ),
          categoryColor: AppColors.categoryBody,
        ),
      ));
      await tester.pump();
      expect(find.byType(LineChart), findsOneWidget);
    });
  });

  // ── GaugeViz ─────────────────────────────────────────────────────────────

  group('GaugeViz', () {
    testWidgets('renders CustomPaint without exception', (tester) async {
      await tester.pumpWidget(_wrap(
        GaugeViz(
          data: const GaugeData(percent: 0.22, label: 'Normal'),
          categoryColor: AppColors.categoryBody,
        ),
      ));
      await tester.pump();
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(_wrap(
        GaugeViz(
          data: const GaugeData(percent: 0.3, label: 'Normal'),
          categoryColor: AppColors.categoryBody,
        ),
      ));
      await tester.pump();
      expect(find.text('Normal'), findsOneWidget);
    });
  });

  // ── ValueViz ─────────────────────────────────────────────────────────────

  group('ValueViz', () {
    testWidgets('renders primary value without exception', (tester) async {
      await tester.pumpWidget(_wrap(
        const ValueViz(
          data: ValueData(
            primaryValue: '48.2',
            secondaryLabel: 'mL/kg/min',
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('48.2'), findsOneWidget);
      expect(find.text('mL/kg/min'), findsOneWidget);
    });

    testWidgets('renders with statusColor dot', (tester) async {
      await tester.pumpWidget(_wrap(
        const ValueViz(
          data: ValueData(
            primaryValue: '98',
            secondaryLabel: 'Normal',
            statusColor: 0xFF30D158,
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('98'), findsOneWidget);
    });
  });

  // ── DualValueViz ─────────────────────────────────────────────────────────

  group('DualValueViz', () {
    testWidgets('renders both values without exception', (tester) async {
      await tester.pumpWidget(_wrap(
        const DualValueViz(
          data: DualValueData(
            topValue: '120',
            bottomValue: '80',
            topLabel: 'Systolic',
            bottomLabel: 'Diastolic',
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('120'), findsOneWidget);
      expect(find.text('80'), findsOneWidget);
    });
  });

  // ── MacroBarsViz ─────────────────────────────────────────────────────────

  group('MacroBarsViz', () {
    testWidgets('renders total calories and progress bars', (tester) async {
      await tester.pumpWidget(_wrap(
        MacroBarsViz(
          data: const MacroBarsData(
            totalCalories: '1,840',
            macros: [
              (label: 'Protein', current: 80, goal: 120),
              (label: 'Carbs', current: 200, goal: 250),
              (label: 'Fat', current: 55, goal: 70),
            ],
          ),
          categoryColor: AppColors.categoryNutrition,
        ),
      ));
      await tester.pump();
      expect(find.text('1,840'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsWidgets);
    });
  });

  // ── FillGaugeViz ─────────────────────────────────────────────────────────

  group('FillGaugeViz', () {
    testWidgets('renders without exception', (tester) async {
      await tester.pumpWidget(_wrap(
        FillGaugeViz(
          data: const FillGaugeData(current: 1.5, goal: 2.5, unit: 'L'),
          categoryColor: AppColors.categoryNutrition,
        ),
      ));
      await tester.pump();
      expect(
        find.byType(CustomPaint).evaluate().isNotEmpty ||
            find.byType(ClipRect).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('renders current/goal text', (tester) async {
      await tester.pumpWidget(_wrap(
        FillGaugeViz(
          data: const FillGaugeData(current: 1.5, goal: 2.5, unit: 'L'),
          categoryColor: AppColors.categoryNutrition,
        ),
      ));
      await tester.pump();
      // Widget renders "1.5 / 2.5L" as a single Text widget.
      expect(find.textContaining('1.5 / 2.5'), findsOneWidget);
    });
  });

  // ── DotsViz ──────────────────────────────────────────────────────────────

  group('DotsViz', () {
    testWidgets('renders 7 dots without exception', (tester) async {
      await tester.pumpWidget(_wrap(
        DotsViz(
          data: DotsData(
            values: [0.3, 0.5, 0.7, 0.4, 0.8, 0.6, 0.9],
            todayLabel: 'Good',
          ),
          categoryColor: AppColors.categoryWellness,
        ),
      ));
      await tester.pump();
      expect(find.byType(Row), findsWidgets);
    });

    testWidgets('renders todayLabel', (tester) async {
      await tester.pumpWidget(_wrap(
        DotsViz(
          data: DotsData(
            values: [0.5, 0.6, 0.7, 0.5, 0.8, 0.7, 0.9],
            todayLabel: 'Great',
          ),
          categoryColor: AppColors.categoryWellness,
        ),
      ));
      await tester.pump();
      expect(find.text('Great'), findsOneWidget);
    });
  });

  // ── CountBadgeViz ─────────────────────────────────────────────────────────

  group('CountBadgeViz', () {
    testWidgets('renders count without exception', (tester) async {
      await tester.pumpWidget(_wrap(
        const CountBadgeViz(
          data: CountBadgeData(
            count: 4,
            lastWorkoutType: 'Run',
            lastWorkoutDuration: '42min',
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('renders without lastWorkout metadata', (tester) async {
      await tester.pumpWidget(_wrap(
        const CountBadgeViz(
          data: CountBadgeData(count: 0),
        ),
      ));
      await tester.pump();
      expect(find.text('0'), findsOneWidget);
    });
  });

  // ── CalendarDotsViz ───────────────────────────────────────────────────────

  group('CalendarDotsViz', () {
    testWidgets('renders cycleDay and phaseLabel', (tester) async {
      await tester.pumpWidget(_wrap(
        const CalendarDotsViz(
          data: CalendarDotsData(
            cycleDay: 14,
            phaseLabel: 'Ovulation',
            dotStates: [true, true, false, true, false, true, false],
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('14'), findsOneWidget);
      expect(find.text('Ovulation'), findsOneWidget);
    });
  });

  // ── EnvironmentViz ────────────────────────────────────────────────────────

  group('EnvironmentViz', () {
    testWidgets('renders AQI and UV values', (tester) async {
      await tester.pumpWidget(_wrap(
        const EnvironmentViz(
          data: EnvironmentData(
            aqiValue: 42,
            aqiLabel: 'Good',
            uvIndex: 7,
            uvLabel: 'High',
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('42'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('color-codes high AQI without exception', (tester) async {
      await tester.pumpWidget(_wrap(
        const EnvironmentViz(
          data: EnvironmentData(
            aqiValue: 160,
            aqiLabel: 'Unhealthy',
            uvIndex: 11,
            uvLabel: 'Extreme',
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('160'), findsOneWidget);
    });
  });

  // ── buildTileVisualization factory ────────────────────────────────────────

  group('buildTileVisualization', () {
    testWidgets('dispatches BarChartData → BarChartViz', (tester) async {
      final data = BarChartData(
        dailyValues: [5000, 6000, 7000, 8000, 9000, 10000, 8500],
        dayLabels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      );
      await tester.pumpWidget(_wrap(
        buildTileVisualization(
          data: data,
          categoryColor: AppColors.categoryActivity,
        ),
      ));
      await tester.pump();
      expect(find.byType(BarChartViz), findsOneWidget);
    });

    testWidgets('dispatches RingData → RingViz', (tester) async {
      await tester.pumpWidget(_wrap(
        buildTileVisualization(
          data: const RingData(value: 6.5, max: 8.0),
          categoryColor: AppColors.categorySleep,
        ),
      ));
      await tester.pump();
      expect(find.byType(RingViz), findsOneWidget);
    });

    testWidgets('dispatches ValueData → ValueViz', (tester) async {
      await tester.pumpWidget(_wrap(
        buildTileVisualization(
          data: const ValueData(primaryValue: '48.2'),
          categoryColor: AppColors.categoryHeart,
        ),
      ));
      await tester.pump();
      expect(find.byType(ValueViz), findsOneWidget);
    });

    testWidgets('dispatches GaugeData → GaugeViz', (tester) async {
      await tester.pumpWidget(_wrap(
        buildTileVisualization(
          data: const GaugeData(percent: 0.22),
          categoryColor: AppColors.categoryBody,
        ),
      ));
      await tester.pump();
      expect(find.byType(GaugeViz), findsOneWidget);
    });

    testWidgets('dispatches EnvironmentData → EnvironmentViz', (tester) async {
      await tester.pumpWidget(_wrap(
        buildTileVisualization(
          data: const EnvironmentData(
            aqiValue: 42,
            aqiLabel: 'Good',
            uvIndex: 3,
            uvLabel: 'Moderate',
          ),
          categoryColor: AppColors.categoryEnvironment,
        ),
      ));
      await tester.pump();
      expect(find.byType(EnvironmentViz), findsOneWidget);
    });
  });
}
