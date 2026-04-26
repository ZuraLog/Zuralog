/// Zuralog Design System — Log Grid Sheet.
///
/// A bottom sheet that shows a 4-column grid of loggable metric tiles.
/// Tapping a tile either opens a panel inline (Part 4–7), navigates to a
/// full-screen form, or shows a "coming soon" snackbar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/progress/providers/progress_providers.dart';
import 'package:zuralog/features/today/data/today_repository.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/log_panels/z_steps_log_panel.dart';
import 'package:zuralog/shared/widgets/log_panels/z_water_log_panel.dart';
import 'package:zuralog/shared/widgets/log_panels/z_wellness_log_panel.dart';
import 'package:zuralog/shared/widgets/log_panels/z_weight_log_panel.dart';
import 'package:zuralog/shared/widgets/sheets/z_log_grid_cell.dart';

// ── Tile definitions ─────────────────────────────────────────────────────────

/// How a log tile behaves when tapped.
enum _TileBehaviour {
  /// Opens an inline panel inside the sheet.
  inline,

  /// Navigates to a full-screen logging form (not yet wired in Part 2).
  fullScreen,

  /// Tile is not yet available — shows a "coming soon" snackbar.
  comingSoon,
}

/// A single loggable metric tile definition.
class _TileDef {
  const _TileDef({
    required this.key,
    required this.icon,
    required this.label,
    required this.behaviour,
  });

  final String key;
  final IconData icon;
  final String label;
  final _TileBehaviour behaviour;
}

/// The ordered list of 10 loggable metric tiles.
const List<_TileDef> _tiles = [
  _TileDef(key: 'mood',       icon: Icons.self_improvement_rounded, label: 'Wellness',     behaviour: _TileBehaviour.inline),
  _TileDef(key: 'water',      icon: Icons.water_drop_rounded,       label: 'Water',        behaviour: _TileBehaviour.inline),
  _TileDef(key: 'sleep',      icon: Icons.bedtime_rounded,          label: 'Sleep',        behaviour: _TileBehaviour.fullScreen),
  _TileDef(key: 'weight',     icon: Icons.monitor_weight_rounded,   label: 'Weight',       behaviour: _TileBehaviour.inline),
  _TileDef(key: 'steps',      icon: Icons.directions_walk_rounded,  label: 'Steps',        behaviour: _TileBehaviour.inline),
  _TileDef(key: 'run',        icon: Icons.directions_run_rounded,   label: 'Run / Cardio', behaviour: _TileBehaviour.fullScreen),
  _TileDef(key: 'meal',       icon: Icons.restaurant_rounded,       label: 'Meal',         behaviour: _TileBehaviour.fullScreen),
  _TileDef(key: 'supplement', icon: Icons.medication_rounded,       label: 'Supplements',  behaviour: _TileBehaviour.fullScreen),
  _TileDef(key: 'symptom',    icon: Icons.healing_rounded,          label: 'Symptom',      behaviour: _TileBehaviour.fullScreen),
  _TileDef(key: 'workout',    icon: Icons.fitness_center_rounded,   label: 'Fitness',      behaviour: _TileBehaviour.fullScreen),
];

/// Maps each tile key to the canonical backend metric-type slug reported
/// by [todayLogSummaryProvider]. Used to determine whether a tile already
/// has an entry logged today.
///
/// Keys absent from this map (e.g. 'mood', 'energy', 'stress', 'steps')
/// match their metric_type slug directly and need no translation.
const Map<String, String> _tileKeyToSlug = {
  'water':      'water_ml',
  'weight':     'weight_kg',
  'sleep':      'sleep_duration',
  'run':        'exercise_minutes',
  'meal':       'calories',
  'supplement': 'supplement_taken',
  'symptom':    'symptom',
  'workout':    'workout',
};

// ── ZLogGridSheet ─────────────────────────────────────────────────────────────

/// A modal bottom sheet showing a 4-column grid of loggable metric tiles.
///
/// Reads [todayLogSummaryProvider] to show green checkmarks on tiles the
/// user has already logged today.
///
/// ## FAB positioning note
///
/// [AppShell] uses `extendBody: true` on its outer [Scaffold]. Flutter
/// therefore automatically injects the frosted nav bar's rendered height into
/// [MediaQuery.padding.bottom] for all children of the body — including the
/// inner [Scaffold] inside [ZuralogScaffold]. The inner [Scaffold]'s FAB
/// uses [FloatingActionButtonLocation.endFloat] by default, which already
/// reads [MediaQuery.padding.bottom] to lift the button above the nav bar.
/// No additional manual padding or [extendBody] override is needed here.
///
/// Usage:
/// ```dart
/// showModalBottomSheet<void>(
///   context: context,
///   isScrollControlled: true,
///   builder: (_) => ZLogGridSheet(
///     parentMessenger: ScaffoldMessenger.of(context),
///   ),
/// );
/// ```
class ZLogGridSheet extends ConsumerStatefulWidget {
  const ZLogGridSheet({
    super.key,
    this.onFullScreenRoute,
    this.parentMessenger,
    this.initialTileKey,
  });

  /// Called when a full-screen log tile is tapped.
  /// Receives the named route string (e.g. RouteNames.sleepLog).
  final ValueChanged<String>? onFullScreenRoute;

  /// Optional [ScaffoldMessengerState] from the parent context.
  ///
  /// Used to show snackbars above the modal bottom sheet. If null, falls back
  /// to [ScaffoldMessenger.of(context)] resolved inside the sheet — which may
  /// not surface correctly from within a detached modal context.
  final ScaffoldMessengerState? parentMessenger;

  /// When provided, the sheet opens directly to the inline panel for this
  /// metric type key (e.g. `'water'`, `'mood'`, `'weight'`, `'steps'`),
  /// skipping the grid picker entirely.
  ///
  /// Only effective for inline-behaviour tiles. If the key maps to a
  /// full-screen tile or is unrecognised, it is silently ignored and the grid
  /// picker is shown instead.
  final String? initialTileKey;

  @override
  ConsumerState<ZLogGridSheet> createState() => _ZLogGridSheetState();
}

class _ZLogGridSheetState extends ConsumerState<ZLogGridSheet> {
  /// When non-null, the sheet shows the inline panel for this tile.
  _TileDef? _selectedTile;

  @override
  void initState() {
    super.initState();
    // If an initialTileKey was provided, pre-navigate to the inline panel
    // for that tile so the sheet opens directly at the right panel.
    // Only inline tiles support this — full-screen and comingSoon tiles
    // are ignored (caller should use context.pushNamed for full-screen).
    final key = widget.initialTileKey;
    if (key != null) {
      try {
        final match = _tiles.firstWhere(
          (t) => t.key == key && t.behaviour == _TileBehaviour.inline,
        );
        _selectedTile = match;
      } catch (_) {
        // No inline tile found for this key — show the grid picker.
      }
    }
  }

  void _backToGrid() => setState(() => _selectedTile = null);

  void _handleTileTap(_TileDef tile) {
    switch (tile.behaviour) {
      case _TileBehaviour.inline:
        setState(() => _selectedTile = tile);

      case _TileBehaviour.fullScreen:
        widget.onFullScreenRoute?.call(_routeForTile(tile.key));

      case _TileBehaviour.comingSoon:
        (widget.parentMessenger ?? ScaffoldMessenger.of(context)).showSnackBar(
          SnackBar(
            content: const Text('This feature is coming soon — stay tuned!'),
            backgroundColor: AppColorsOf(context).primary,
            duration: const Duration(seconds: 3),
          ),
        );
    }
  }

  String _routeForTile(String key) {
    return switch (key) {
      'sleep'      => RouteNames.sleepLog,
      'run'        => RouteNames.runLog,
      'meal'       => RouteNames.mealLog,
      'supplement' => RouteNames.supplementsLog,
      'symptom'    => RouteNames.symptomLog,
      'workout'    => RouteNames.workoutLog,
      _            => throw AssertionError('No route mapped for full-screen tile key: $key'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final loggedTypes =
        ref.watch(todayLogSummaryProvider).valueOrNull?.loggedTypes ??
            const <String>{};

    final title = _selectedTile == null
        ? 'What do you want to log?'
        : _selectedTile!.label;

    return Container(
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppDimens.shapeLg),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: AppDimens.spaceMd),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(AppDimens.shapePill),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),

          // Header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            child: Row(
              children: [
                if (_selectedTile != null)
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: _backToGrid,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                if (_selectedTile != null) const SizedBox(width: AppDimens.spaceSm),
                Text(
                  title,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),

          // Content — grid or inline panel
          // Resolve repo here, in the stable ConsumerStatefulWidget,
          // so _PanelView's async closures never hold a stale ref.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _selectedTile == null
                ? _GridView(
                    key: const ValueKey('grid'),
                    loggedTypes: loggedTypes,
                    onTileTap: _handleTileTap,
                  )
                : _PanelView(
                    key: ValueKey(_selectedTile!.key),
                    tile: _selectedTile!,
                    repo: ref.read(todayRepositoryProvider),
                    onBack: _backToGrid,
                    parentMessenger: widget.parentMessenger,
                    onSaved: () {
                      if (!mounted) return;
                      Navigator.of(context).pop();
                      // Defer provider invalidation until after the sheet is
                      // fully popped. Calling ref.invalidate() synchronously
                      // while the Scaffold is mid-layout causes
                      // markNeedsBuild() to fire inside a LayoutBuilder
                      // layout callback, producing an ErrorWidget (gray panel)
                      // on the Today tab.
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        ref.invalidate(todayLogSummaryProvider);
                        ref.invalidate(progressHomeProvider);
                        ref.invalidate(goalsProvider);
                      });
                    },
                  ),
          ),

          const SizedBox(height: AppDimens.spaceLg),
        ],
      ),
    );
  }
}

// ── _GridView ─────────────────────────────────────────────────────────────────

/// Private 4-column grid of log tiles.
class _GridView extends StatelessWidget {
  const _GridView({
    super.key,
    required this.loggedTypes,
    required this.onTileTap,
  });

  final Set<String> loggedTypes;
  final ValueChanged<_TileDef> onTileTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: GridView.count(
        crossAxisCount: 4,
        crossAxisSpacing: AppDimens.spaceMd,
        mainAxisSpacing: AppDimens.spaceLg,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: _tiles.map((tile) {
          final slug = _tileKeyToSlug[tile.key] ?? tile.key;
          final isLogged = loggedTypes.contains(slug);
          return ZLogGridCell(
            icon: tile.icon,
            label: tile.label,
            isLogged: isLogged,
            isComingSoon: tile.behaviour == _TileBehaviour.comingSoon,
            onTap: () => onTileTap(tile),
          );
        }).toList(),
      ),
    );
  }
}

// ── _PanelView ────────────────────────────────────────────────────────────────

/// Renders the correct inline log panel for the selected tile.
class _PanelView extends StatelessWidget {
  const _PanelView({
    super.key,
    required this.tile,
    required this.repo,
    required this.onBack,
    required this.onSaved,
    this.parentMessenger,
  });

  final _TileDef tile;
  final TodayRepositoryInterface repo;
  final VoidCallback onBack;
  final VoidCallback onSaved;

  /// Optional messenger from the parent scaffold context.
  ///
  /// [_PanelView] lives inside a modal bottom sheet whose [BuildContext] is
  /// detached from the host page's [Scaffold]. Passing [parentMessenger] from
  /// [ZLogGridSheet.parentMessenger] ensures error snackbars surface above the
  /// sheet rather than being swallowed by the modal's detached scaffold.
  final ScaffoldMessengerState? parentMessenger;

  @override
  Widget build(BuildContext context) {
    return switch (tile.key) {
      'water' => ZWaterLogPanel(
          onSave: (ml, {String? vesselKey}) async {
            // Local save + cloud sync are handled inside ZWaterLogPanel.
            // This callback's only job is to close the sheet and refresh providers.
            onSaved();
          },
          onBack: onBack,
        ),
      'mood' => ZWellnessLogPanel(
          onSave: (data) async {
            try {
              await repo.logWellness(
                mood: data.mood,
                energy: data.energy,
                stress: data.stress,
                notes: data.notes,
              );
              onSaved();
            } catch (e) {
              debugPrint('logWellness failed: $e');
              final messenger = parentMessenger ??
                  (context.mounted ? ScaffoldMessenger.of(context) : null);
              messenger?.showSnackBar(
                const SnackBar(
                  content: Text('Could not save check-in. Please try again.'),
                ),
              );
            }
          },
          onBack: onBack,
        ),
      'weight' => ZWeightLogPanel(
          onSave: (kg) async {
            try {
              await repo.logWeight(valueKg: kg);
              onSaved();
            } catch (e) {
              debugPrint('logWeight failed: $e');
              final messenger = parentMessenger ??
                  (context.mounted ? ScaffoldMessenger.of(context) : null);
              messenger?.showSnackBar(
                const SnackBar(
                  content: Text('Could not save weight. Please try again.'),
                ),
              );
            }
          },
          onBack: onBack,
        ),
      'steps' => ZStepsLogPanel(
          onSave: (steps, mode) async {
            try {
              await repo.logSteps(steps: steps, mode: mode);
              onSaved();
            } catch (e) {
              debugPrint('logSteps failed: $e');
              final messenger = parentMessenger ??
                  (context.mounted ? ScaffoldMessenger.of(context) : null);
              messenger?.showSnackBar(
                const SnackBar(
                  content: Text('Could not save steps. Please try again.'),
                ),
              );
            }
          },
          onBack: onBack,
        ),
      _ => Center(
          child: Text(
            '${tile.label} — not available',
            // This branch is unreachable in production — all inline tiles are wired above.
          ),
        ),
    };
  }
}
