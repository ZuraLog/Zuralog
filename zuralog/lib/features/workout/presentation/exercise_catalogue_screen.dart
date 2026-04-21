library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/features/workout/domain/exercise.dart';
import 'package:zuralog/features/workout/presentation/widgets/exercise_grid_tile.dart';
import 'package:zuralog/features/workout/providers/exercise_bookmarks_provider.dart';
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
    final bookmarksOnly = ref.watch(exerciseBookmarksOnlyFilterProvider);

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
                // Bookmarks chip — first in row
                Padding(
                  padding: const EdgeInsets.only(right: AppDimens.spaceSm),
                  child: ZChip(
                    label: 'Bookmarks',
                    icon: Icons.bookmark_rounded,
                    isActive: bookmarksOnly,
                    onTap: () {
                      ref
                          .read(exerciseBookmarksOnlyFilterProvider.notifier)
                          .state = !bookmarksOnly;
                      if (!bookmarksOnly) {
                        // Activating bookmarks — clear muscle group filter.
                        ref
                            .read(exerciseMuscleGroupFilterProvider.notifier)
                            .state = null;
                      }
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: AppDimens.spaceSm),
                  child: ZChip(
                    label: 'All',
                    isActive: currentFilter == null && !bookmarksOnly,
                    onTap: () {
                      ref
                          .read(exerciseBookmarksOnlyFilterProvider.notifier)
                          .state = false;
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
                            .read(exerciseBookmarksOnlyFilterProvider.notifier)
                            .state = false;
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
              error: (err, st) => ZErrorState(
                message: 'Could not load exercises.',
                onRetry: () => ref.refresh(exerciseListProvider),
              ),
              data: (results) {
                if (results.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimens.spaceLg),
                      child: Text(
                        bookmarksOnly
                            ? 'No bookmarked exercises yet.\nTap the bookmark icon on any exercise to save it.'
                            : 'No exercises match your search.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: colors.textSecondary,
                        ),
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
          // Add button — tight bottom bar
          SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ZDivider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.spaceMd,
                    AppDimens.spaceXs,
                    AppDimens.spaceMd,
                    AppDimens.spaceXs,
                  ),
                  child: ZButton(
                    label: _buttonLabel,
                    onPressed: _selected.isEmpty ? null : _submit,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
