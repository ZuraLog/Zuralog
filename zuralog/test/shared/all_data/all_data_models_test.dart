library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuralog/shared/all_data/all_data_models.dart';

void main() {
  group('AllDataDay', () {
    test('stores values by metric id', () {
      final day = AllDataDay(
        date: '2026-04-20',
        isToday: true,
        values: {'duration': 420.0, 'quality': 4.0, 'deep_sleep': null},
      );
      expect(day.date, '2026-04-20');
      expect(day.isToday, isTrue);
      expect(day.values['duration'], 420.0);
      expect(day.values['deep_sleep'], isNull);
    });
  });

  group('AllDataChartType', () {
    test('has exactly bar and line values', () {
      expect(AllDataChartType.values.length, 2);
      expect(AllDataChartType.values, contains(AllDataChartType.bar));
      expect(AllDataChartType.values, contains(AllDataChartType.line));
    });
  });

  group('AllDataMetricTab', () {
    test('valueExtractor returns value from AllDataDay', () {
      final day = AllDataDay(
        date: '2026-04-20',
        isToday: false,
        values: {'calories': 1850.0},
      );
      final tab = AllDataMetricTab(
        id: 'calories',
        label: 'Calories',
        chartType: AllDataChartType.bar,
        unit: 'kcal',
        valueExtractor: (d) => d.values['calories'],
      );
      expect(tab.valueExtractor(day), 1850.0);
    });

    test('emptyStateSource defaults to null', () {
      final tab = AllDataMetricTab(
        id: 'duration',
        label: 'Duration',
        chartType: AllDataChartType.bar,
        unit: 'h',
        valueExtractor: (d) => d.values['duration'],
      );
      expect(tab.emptyStateSource, isNull);
    });
  });

  group('AllDataSectionConfig', () {
    test('holds all required fields and fetchData is callable', () async {
      final config = AllDataSectionConfig(
        sectionTitle: 'Sleep',
        categoryColor: Colors.indigo,
        tabs: [],
        fetchData: (_) async => [],
      );
      expect(config.sectionTitle, 'Sleep');
      expect(config.tabs, isEmpty);
      final result = await config.fetchData('7d');
      expect(result, isEmpty);
    });
  });
}
