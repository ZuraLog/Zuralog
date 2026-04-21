library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

class WorkoutSummaryScreen extends StatelessWidget {
  const WorkoutSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return ZuralogScaffold(
      appBar: AppBar(
        title: const Text('Workout Summary'),
        leading: const BackButton(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Center(
          child: Text(
            'Workout summary — full UI arrives in Plan 4.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium
                .copyWith(color: colors.textSecondary),
          ),
        ),
      ),
    );
  }
}
