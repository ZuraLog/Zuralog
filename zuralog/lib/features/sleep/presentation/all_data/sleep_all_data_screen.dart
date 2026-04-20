library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/features/sleep/providers/sleep_providers.dart';
import 'package:zuralog/shared/all_data/all_data_models.dart';
import 'package:zuralog/shared/all_data/all_data_screen.dart';

/// Entry point for the Sleep All-Data screen. Constructs the section config
/// and delegates all rendering to [AllDataScreen].
class SleepAllDataScreen extends ConsumerWidget {
  const SleepAllDataScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(sleepRepositoryProvider);
    final config = AllDataSectionConfig(
      sectionTitle: 'Sleep',
      categoryColor: AppColors.categorySleep,
      tabs: [
        AllDataMetricTab(
          id: 'duration',
          label: 'Duration',
          chartType: AllDataChartType.bar,
          unit: 'h',
          valueExtractor: (d) {
            final mins = d.values['duration'];
            return mins != null ? mins / 60.0 : null;
          },
        ),
        AllDataMetricTab(
          id: 'quality',
          label: 'Quality',
          chartType: AllDataChartType.bar,
          unit: '',
          valueExtractor: (d) => d.values['quality'],
        ),
        AllDataMetricTab(
          id: 'deep_sleep',
          label: 'Deep Sleep',
          chartType: AllDataChartType.bar,
          unit: 'h',
          valueExtractor: (d) {
            final mins = d.values['deep_sleep'];
            return mins != null ? mins / 60.0 : null;
          },
          emptyStateSource: 'Connect a wearable to see this metric',
        ),
        AllDataMetricTab(
          id: 'rem',
          label: 'REM',
          chartType: AllDataChartType.bar,
          unit: 'h',
          valueExtractor: (d) {
            final mins = d.values['rem'];
            return mins != null ? mins / 60.0 : null;
          },
          emptyStateSource: 'Connect a wearable to see this metric',
        ),
        AllDataMetricTab(
          id: 'light_sleep',
          label: 'Light Sleep',
          chartType: AllDataChartType.bar,
          unit: 'h',
          valueExtractor: (d) {
            final mins = d.values['light_sleep'];
            return mins != null ? mins / 60.0 : null;
          },
          emptyStateSource: 'Connect a wearable to see this metric',
        ),
        AllDataMetricTab(
          id: 'heart_rate',
          label: 'Heart Rate',
          chartType: AllDataChartType.line,
          unit: 'bpm',
          valueExtractor: (d) => d.values['heart_rate'],
          emptyStateSource: 'Connect a wearable to see this metric',
        ),
        AllDataMetricTab(
          id: 'efficiency',
          label: 'Efficiency',
          chartType: AllDataChartType.line,
          unit: '%',
          valueExtractor: (d) => d.values['efficiency'],
          emptyStateSource: 'Connect a wearable to see this metric',
        ),
      ],
      fetchData: repo.getSleepAllData,
    );
    return AllDataScreen(config: config);
  }
}
