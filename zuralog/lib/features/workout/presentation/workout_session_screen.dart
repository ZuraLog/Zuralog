library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/workout/domain/exercise.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

class WorkoutSessionScreen extends ConsumerStatefulWidget {
  const WorkoutSessionScreen({super.key});

  @override
  ConsumerState<WorkoutSessionScreen> createState() =>
      _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState
    extends ConsumerState<WorkoutSessionScreen> {
  final List<Exercise> _picked = [];

  Future<void> _openCatalogue() async {
    final result = await context.push<List<Exercise>>(
      RouteNames.workoutExercisesPath,
    );
    if (result != null && result.isNotEmpty) {
      setState(() => _picked.addAll(result));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return ZuralogScaffold(
      appBar: AppBar(
        title: const Text('Workout'),
        leading: const BackButton(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Workout session — full UI arrives in Plan 2.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            if (_picked.isNotEmpty) ...[
              Text(
                'Picked exercises (${_picked.length}):',
                style: AppTextStyles.titleMedium,
              ),
              const SizedBox(height: AppDimens.spaceSm),
              Expanded(
                child: ListView.separated(
                  itemCount: _picked.length,
                  separatorBuilder: (itemContext, index) =>
                      const SizedBox(height: AppDimens.spaceSm),
                  itemBuilder: (itemContext, i) => Text(
                    _picked[i].name,
                    style: AppTextStyles.bodyMedium,
                  ),
                ),
              ),
            ] else
              const Spacer(),
            ZButton(
              label: 'Add Exercises',
              onPressed: _openCatalogue,
            ),
            const SizedBox(height: AppDimens.spaceSm),
          ],
        ),
      ),
    );
  }
}
