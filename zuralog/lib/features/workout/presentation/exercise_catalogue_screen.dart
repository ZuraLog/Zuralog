library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/workout/domain/exercise.dart';
import 'package:zuralog/features/workout/presentation/widgets/exercise_grid_tile.dart';
import 'package:zuralog/features/workout/providers/exercise_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

class ExerciseCatalogueScreen extends ConsumerStatefulWidget {
  const ExerciseCatalogueScreen({super.key});

  @override
  ConsumerState<ExerciseCatalogueScreen> createState() =>
      _ExerciseCatalogueScreenState();
}

class _ExerciseCatalogueScreenState
    extends ConsumerState<ExerciseCatalogueScreen> {
  final _searchCtrl = TextEditingController();
  final Set<Exercise> _selected = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggle(Exercise e) {
    setState(() {
      if (_selected.contains(e)) {
        _selected.remove(e);
      } else {
        _selected.add(e);
      }
    });
  }

  String get _buttonLabel {
    final n = _selected.length;
    if (n <= 1) return 'Add Exercise';
    return 'Add $n Exercises';
  }

  void _submit() {
    if (_selected.isEmpty) return;
    context.pop<List<Exercise>>(_selected.toList(growable: false));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final resultsAsync = ref.watch(exerciseSearchProvider);
    final currentFilter = ref.watch(exerciseMuscleGroupFilterProvider);
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return ZuralogScaffold(
      appBar: AppBar(
        title: const Text('Add Exercises'),
        leading: const BackButton(),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              AppDimens.spaceMd,
              AppDimens.spaceMd,
              AppDimens.spaceSm,
            ),
            child: ZSearchBar(
              controller: _searchCtrl,
              placeholder: 'Search exercises...',
              onChanged: (value) {
                ref.read(exerciseSearchQueryProvider.notifier).state = value;
              },
              onClear: () {
                ref.read(exerciseSearchQueryProvider.notifier).state = '';
              },
            ),
          ),
          // Muscle group filter chips
          SizedBox(
            height: AppDimens.iconContainerMd,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: AppDimens.spaceSm),
                  child: ZChip(
                    label: 'All',
                    isActive: currentFilter == null,
                    onTap: () {
                      ref
                          .read(exerciseMuscleGroupFilterProvider.notifier)
                          .state = null;
                    },
                  ),
                ),
                for (final group in MuscleGroup.values
                    .where((g) => g != MuscleGroup.other))
                  Padding(
                    padding: const EdgeInsets.only(right: AppDimens.spaceSm),
                    child: ZChip(
                      label: group.label,
                      isActive: currentFilter == group,
                      onTap: () {
                        ref
                            .read(exerciseMuscleGroupFilterProvider.notifier)
                            .state = currentFilter == group ? null : group;
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          // Exercise grid
          Expanded(
            child: resultsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Could not load exercises.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppDimens.spaceMd),
                    ZButton(
                      label: 'Retry',
                      onPressed: () => ref.refresh(exerciseListProvider),
                    ),
                  ],
                ),
              ),
              data: (results) {
                if (results.isEmpty) {
                  return Center(
                    child: Text(
                      'No exercises match your search.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceMd,
                    vertical: AppDimens.spaceSm,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: AppDimens.spaceMd,
                    crossAxisSpacing: AppDimens.spaceMd,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: results.length,
                  itemBuilder: (_, i) {
                    final exercise = results[i];
                    return ExerciseGridTile(
                      key: ValueKey('exercise-${exercise.id}'),
                      exercise: exercise,
                      isSelected: _selected.contains(exercise),
                      onTap: () => _toggle(exercise),
                    );
                  },
                );
              },
            ),
          ),
          // Add button
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              AppDimens.spaceSm,
              AppDimens.spaceMd,
              AppDimens.spaceSm + bottomPad,
            ),
            child: ZButton(
              label: _buttonLabel,
              onPressed: _selected.isEmpty ? null : _submit,
            ),
          ),
        ],
      ),
    );
  }
}
