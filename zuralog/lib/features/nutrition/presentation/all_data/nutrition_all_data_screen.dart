library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';
import 'package:zuralog/shared/all_data/all_data_models.dart';
import 'package:zuralog/shared/all_data/all_data_screen.dart';

/// Entry point for the Nutrition All-Data screen.
class NutritionAllDataScreen extends ConsumerWidget {
  const NutritionAllDataScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(nutritionRepositoryProvider);
    final config = AllDataSectionConfig(
      sectionTitle: 'Nutrition',
      categoryColor: AppColors.categoryNutrition,
      tabs: [
        AllDataMetricTab(
          id: 'calories',
          label: 'Calories',
          chartType: AllDataChartType.bar,
          unit: 'kcal',
          valueExtractor: (d) => d.values['calories'],
        ),
        AllDataMetricTab(
          id: 'protein',
          label: 'Protein',
          chartType: AllDataChartType.bar,
          unit: 'g',
          valueExtractor: (d) => d.values['protein'],
        ),
        AllDataMetricTab(
          id: 'carbs',
          label: 'Carbs',
          chartType: AllDataChartType.bar,
          unit: 'g',
          valueExtractor: (d) => d.values['carbs'],
        ),
        AllDataMetricTab(
          id: 'fat',
          label: 'Fat',
          chartType: AllDataChartType.bar,
          unit: 'g',
          valueExtractor: (d) => d.values['fat'],
        ),
        AllDataMetricTab(
          id: 'meals',
          label: 'Meals',
          chartType: AllDataChartType.bar,
          unit: '',
          valueExtractor: (d) => d.values['meals'],
        ),
      ],
      fetchData: repo.getNutritionAllData,
    );
    return AllDataScreen(config: config);
  }
}
