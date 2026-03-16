/// Zuralog Design System — Log Grid Sheet.
///
/// A bottom sheet that shows a 4-column grid of loggable metric tiles.
/// Tapping a tile either opens a panel inline (Part 4–7), navigates to a
/// full-screen form, or shows a "coming soon" snackbar.
///
/// Part 2: Grid view only — panel content is a placeholder.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
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
/// Usage:
/// ```dart
/// showModalBottomSheet<void>(
///   context: context,
///   isScrollControlled: true,
///   builder: (_) => const ZLogGridSheet(),
/// );
/// ```
class ZLogGridSheet extends ConsumerStatefulWidget {
  const ZLogGridSheet({super.key});

  @override
  ConsumerState<ZLogGridSheet> createState() => _ZLogGridSheetState();
}

class _ZLogGridSheetState extends ConsumerState<ZLogGridSheet> {
  /// When non-null, the sheet shows the inline panel for this tile.
  _TileDef? _selectedTile;

  void _handleTileTap(_TileDef tile) {
    switch (tile.behaviour) {
      case _TileBehaviour.inline:
        setState(() => _selectedTile = tile);

      case _TileBehaviour.fullScreen:
        // Full-screen forms not yet wired in Part 2 — no-op.
        break;

      case _TileBehaviour.comingSoon:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Workout tracking is coming soon — stay tuned!'),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 3),
          ),
        );
    }
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
                    onPressed: () => setState(() => _selectedTile = null),
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

          // Content — grid or panel placeholder
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _selectedTile == null
                ? _GridView(
                    key: const ValueKey('grid'),
                    loggedTypes: loggedTypes,
                    onTileTap: _handleTileTap,
                  )
                : _PanelPlaceholder(
                    key: ValueKey(_selectedTile!.key),
                    type: _selectedTile!,
                    onSaved: () => setState(() => _selectedTile = null),
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

// ── _PanelPlaceholder ─────────────────────────────────────────────────────────

/// Temporary placeholder shown while the real inline panels are built in Chunk 4–7.
class _PanelPlaceholder extends StatelessWidget {
  const _PanelPlaceholder({
    super.key,
    required this.type,
    required this.onSaved,
  });

  final _TileDef type;

  /// Called after a successful log submission.
  final VoidCallback onSaved;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceLg,
      ),
      child: Center(
        child: Text(
          '${type.label} panel — coming in Chunk 4–7',
          style: AppTextStyles.bodyMedium.copyWith(
            color: colors.textTertiary,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
