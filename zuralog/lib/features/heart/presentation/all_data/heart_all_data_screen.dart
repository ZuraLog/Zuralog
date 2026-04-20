library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/features/heart/providers/heart_providers.dart';
import 'package:zuralog/shared/all_data/all_data_models.dart';
import 'package:zuralog/shared/all_data/all_data_screen.dart';

class HeartAllDataScreen extends ConsumerWidget {
  const HeartAllDataScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(heartRepositoryProvider);
    final config = AllDataSectionConfig(
      sectionTitle: 'Heart',
      categoryColor: AppColors.categoryHeart,
      tabs: [
        AllDataMetricTab(
          id: 'resting_hr',
          label: 'Resting HR',
          chartType: AllDataChartType.line,
          unit: 'bpm',
          valueExtractor: (day) => day.values['resting_hr'],
          emptyStateSource: 'Connect a wearable',
        ),
        AllDataMetricTab(
          id: 'hrv',
          label: 'HRV',
          chartType: AllDataChartType.line,
          unit: 'ms',
          valueExtractor: (day) => day.values['hrv'],
          emptyStateSource: 'Connect a wearable',
        ),
        AllDataMetricTab(
          id: 'avg_hr',
          label: 'Avg HR',
          chartType: AllDataChartType.line,
          unit: 'bpm',
          valueExtractor: (day) => day.values['avg_hr'],
          emptyStateSource: 'Connect a wearable',
        ),
        AllDataMetricTab(
          id: 'respiratory_rate',
          label: 'Resp. Rate',
          chartType: AllDataChartType.line,
          unit: 'brpm',
          valueExtractor: (day) => day.values['respiratory_rate'],
          emptyStateSource: 'Connect a wearable',
        ),
        AllDataMetricTab(
          id: 'vo2_max',
          label: 'VO2 Max',
          chartType: AllDataChartType.line,
          unit: 'mL/kg/min',
          valueExtractor: (day) => day.values['vo2_max'],
          emptyStateSource: 'Connect a wearable',
        ),
        AllDataMetricTab(
          id: 'spo2',
          label: 'SpO2',
          chartType: AllDataChartType.line,
          unit: '%',
          valueExtractor: (day) => day.values['spo2'],
          emptyStateSource: 'Connect a wearable',
        ),
        AllDataMetricTab(
          id: 'bp_systolic',
          label: 'Blood Pressure',
          chartType: AllDataChartType.line,
          unit: 'mmHg',
          valueExtractor: (day) => day.values['bp_systolic'],
          secondaryValueExtractor: (day) => day.values['bp_diastolic'],
          secondaryLabel: 'Diastolic',
          emptyStateSource: 'Connect a source',
        ),
      ],
      fetchData: repo.getHeartAllData,
    );
    return AllDataScreen(config: config);
  }
}
