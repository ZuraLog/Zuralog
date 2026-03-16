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
  final String icon;
  final String label;
  final _TileBehaviour behaviour;
}

/// The ordered list of 10 loggable metric tiles.
const List<_TileDef> _tiles = [
  _TileDef(key: 'mood',       icon: '✨', label: 'Wellness',     behaviour: _TileBehaviour.inline),
  _TileDef(key: 'water',      icon: '💧', label: 'Water',        behaviour: _TileBehaviour.inline),
  _TileDef(key: 'sleep',      icon: '😴', label: 'Sleep',        behaviour: _TileBehaviour.fullScreen),
  _TileDef(key: 'weight',     icon: '⚖️', label: 'Weight',       behaviour: _TileBehaviour.inline),
  _TileDef(key: 'steps',      icon: '👟', label: 'Steps',        behaviour: _TileBehaviour.inline),
  _TileDef(key: 'run',        icon: '🏃', label: 'Run / Cardio', behaviour: _TileBehaviour.fullScreen),
  _TileDef(key: 'meal',       icon: '🍽️', label: 'Meal',         behaviour: _TileBehaviour.fullScreen),
  _TileDef(key: 'supplement', icon: '💊', label: 'Supplements',  behaviour: _TileBehaviour.fullScreen),
  _TileDef(key: 'symptom',    icon: '🩹', label: 'Symptom',      behaviour: _TileBehaviour.fullScreen),
  _TileDef(key: 'workout',    icon: '🏋️', label: 'Workout',      behaviour: _TileBehaviour.comingSoon),
];

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

  @override
  ConsumerState<ZLogGridSheet> createState() => _ZLogGridSheetState();
}

class _ZLogGridSheetState extends ConsumerState<ZLogGridSheet> {
  /// When non-null, the sheet shows the inline panel for this tile.
  _TileDef? _selectedTile;

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
            content: const Text('Workout tracking is coming soon — stay tuned!'),
            backgroundColor: AppColors.primary,
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
        : '${_selectedTile!.icon} ${_selectedTile!.label}';

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
                    onBack: _backToGrid,
                    parentMessenger: widget.parentMessenger,
                    onSaved: () {
                      ref.invalidate(todayLogSummaryProvider);
                      if (mounted) Navigator.of(context).pop();
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
          final isLogged = loggedTypes.contains(tile.key);
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
class _PanelView extends ConsumerWidget {
  const _PanelView({
    super.key,
    required this.tile,
    required this.onBack,
    required this.onSaved,
    this.parentMessenger,
  });

  final _TileDef tile;
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
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (tile.key) {
      'water' => ZWaterLogPanel(
          onSave: (ml) async {
            try {
              await ref.read(todayRepositoryProvider).logWater(amountMl: ml);
              onSaved();
            } catch (e) {
              debugPrint('logWater failed: $e');
              final messenger = parentMessenger ??
                  (context.mounted ? ScaffoldMessenger.of(context) : null);
              messenger?.showSnackBar(
                const SnackBar(
                  content: Text('Could not save water. Please try again.'),
                ),
              );
            }
          },
          onBack: onBack,
        ),
      'mood' => ZWellnessLogPanel(
          onSave: (data) async {
            try {
              await ref.read(todayRepositoryProvider).logWellness(
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
          onSave: (_) => onSaved(),
          onBack: onBack,
        ),
      'steps' => ZStepsLogPanel(
          onSave: (steps, mode) async {
            try {
              await ref
                  .read(todayRepositoryProvider)
                  .logSteps(steps: steps, mode: mode);
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
