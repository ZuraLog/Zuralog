library;

import 'dart:math' show min;

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

  static const int _kPageSize = 20;
  int _visibleCount = _kPageSize;

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

  void _resetPagination() {
    if (mounted) setState(() => _visibleCount = _kPageSize);
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
    final currentMuscle = ref.watch(exerciseMuscleGroupFilterProvider);
    final currentEquipment = ref.watch(exerciseEquipmentFilterProvider);
    final bookmarksOnly = ref.watch(exerciseBookmarksOnlyFilterProvider);

    ref.listen(exerciseSearchQueryProvider, (_, _) => _resetPagination());
    ref.listen(exerciseMuscleGroupFilterProvider, (_, _) => _resetPagination());
    ref.listen(exerciseEquipmentFilterProvider, (_, _) => _resetPagination());
    ref.listen(exerciseBookmarksOnlyFilterProvider, (_, _) => _resetPagination());

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
          // Filter row — bookmarks toggle + two dropdowns
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
              vertical: AppDimens.spaceSm,
            ),
            child: Row(
              children: [
                // Bookmarks toggle
                ZChip(
                  label: 'Bookmarks',
                  icon: Icons.bookmark_rounded,
                  isActive: bookmarksOnly,
                  onTap: () {
                    ref
                        .read(exerciseBookmarksOnlyFilterProvider.notifier)
                        .state = !bookmarksOnly;
                    if (!bookmarksOnly) {
                      ref
                          .read(exerciseMuscleGroupFilterProvider.notifier)
                          .state = null;
                      ref
                          .read(exerciseEquipmentFilterProvider.notifier)
                          .state = null;
                    }
                  },
                ),
                const SizedBox(width: AppDimens.spaceSm),
                // Muscle group dropdown
                Expanded(
                  child: _FilterDropdown<MuscleGroup>(
                    label: currentMuscle?.label ?? 'Muscle Group',
                    isActive: currentMuscle != null,
                    items: [
                      _DropdownItem(
                        label: 'All',
                        value: null,
                        isSelected: currentMuscle == null,
                      ),
                      for (final g in MuscleGroup.values
                          .where((g) => g != MuscleGroup.other))
                        _DropdownItem(
                          label: g.label,
                          value: g,
                          isSelected: currentMuscle == g,
                        ),
                    ],
                    onSelected: (value) {
                      ref
                          .read(exerciseBookmarksOnlyFilterProvider.notifier)
                          .state = false;
                      ref
                          .read(exerciseMuscleGroupFilterProvider.notifier)
                          .state = value;
                    },
                  ),
                ),
                const SizedBox(width: AppDimens.spaceSm),
                // Equipment dropdown
                Expanded(
                  child: _FilterDropdown<Equipment>(
                    label: currentEquipment?.label ?? 'Equipment',
                    isActive: currentEquipment != null,
                    items: [
                      _DropdownItem(
                        label: 'All',
                        value: null,
                        isSelected: currentEquipment == null,
                      ),
                      for (final eq in Equipment.values
                          .where((e) => e != Equipment.other))
                        _DropdownItem(
                          label: eq.label,
                          value: eq,
                          isSelected: currentEquipment == eq,
                        ),
                    ],
                    onSelected: (value) {
                      ref
                          .read(exerciseBookmarksOnlyFilterProvider.notifier)
                          .state = false;
                      ref
                          .read(exerciseEquipmentFilterProvider.notifier)
                          .state = value;
                    },
                  ),
                ),
              ],
            ),
          ),
          // Exercise grid with pagination
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

                final visibleCount = _visibleCount.clamp(0, results.length);
                final hasMore = visibleCount < results.length;

                return NotificationListener<ScrollUpdateNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.extentAfter < 300 && hasMore) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() => _visibleCount =
                              min(_visibleCount + _kPageSize, results.length));
                        }
                      });
                    }
                    return false;
                  },
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.spaceMd,
                          vertical: AppDimens.spaceSm,
                        ),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: AppDimens.spaceMd,
                            crossAxisSpacing: AppDimens.spaceMd,
                            childAspectRatio: 0.85,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (_, i) {
                              final exercise = results[i];
                              return ExerciseGridTile(
                                key: ValueKey('exercise-${exercise.id}'),
                                exercise: exercise,
                                isSelected: _selected.contains(exercise),
                                onTap: () => _toggle(exercise),
                              );
                            },
                            childCount: visibleCount,
                          ),
                        ),
                      ),
                      if (hasMore)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Add button — pinned to bottom
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

// ──────────────────────────────────────────
// Dropdown filter button
// ──────────────────────────────────────────

class _DropdownItem<T> {
  const _DropdownItem({
    required this.label,
    required this.value,
    required this.isSelected,
  });

  final String label;
  final T? value;
  final bool isSelected;
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    super.key,
    required this.label,
    required this.isActive,
    required this.items,
    required this.onSelected,
  });

  final String label;
  final bool isActive;
  final List<_DropdownItem<T>> items;
  final void Function(T? value) onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final borderColor = isActive ? colors.primary : colors.divider;
    final labelColor = isActive ? colors.primary : colors.textSecondary;

    return PopupMenuButton<T?>(
      offset: const Offset(0, 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusInput),
        side: BorderSide(color: colors.divider),
      ),
      color: colors.surface,
      elevation: 4,
      // onSelected is not used because Flutter skips the callback when value is
      // null. Each item fires onSelected directly via onTap instead.
      itemBuilder: (_) => items
          .map(
            (item) => PopupMenuItem<T?>(
              value: item.value,
              onTap: () => onSelected(item.value),
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
                vertical: AppDimens.spaceSm,
              ),
              child: Row(
                children: [
                  if (item.isSelected)
                    Icon(Icons.check_rounded,
                        size: 16, color: colors.primary)
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: AppDimens.spaceSm),
                  Text(
                    item.label,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: item.isSelected ? colors.primary : colors.textPrimary,
                      fontWeight: item.isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        height: AppDimens.iconContainerMd,
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceSm),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(AppDimens.radiusInput),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall.copyWith(
                  color: labelColor,
                  fontWeight:
                      isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: labelColor,
            ),
          ],
        ),
      ),
    );
  }
}
