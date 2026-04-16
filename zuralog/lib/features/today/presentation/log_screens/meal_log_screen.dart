/// Zuralog — Meal Log Screen (redirect).
///
/// This screen serves as a bridge between the legacy meal log route
/// and the new [LogMealSheet]. It opens the sheet on mount and pops
/// itself when the sheet closes.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/features/nutrition/presentation/log_meal_sheet.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

class MealLogScreen extends ConsumerStatefulWidget {
  const MealLogScreen({super.key});

  @override
  ConsumerState<MealLogScreen> createState() => _MealLogScreenState();
}

class _MealLogScreenState extends ConsumerState<MealLogScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await LogMealSheet.show(context);
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const ZuralogScaffold(body: SizedBox.shrink());
  }
}
