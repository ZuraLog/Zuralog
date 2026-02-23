/// Zuralog Settings — Theme Selector Widget.
///
/// A segmented pill control that lets the user choose between System,
/// Light, and Dark theme modes. The selected option is visually
/// distinguished by a filled sage-green background with an animated
/// slide transition.
///
/// Reads and writes [themeModeProvider] from the Riverpod graph.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/core/theme/theme_provider.dart';

/// Duration for the animated slide between theme selection pills.
const Duration _kAnimDuration = Duration(milliseconds: 200);

/// Segmented pill control for selecting app theme mode.
///
/// Displays three equally-sized options — "System", "Light", "Dark" — in a
/// single row. The active pill animates smoothly between selections using
/// [AnimatedContainer]. Tapping a pill writes the corresponding [ThemeMode]
/// to [themeModeProvider].
///
/// Example usage:
/// ```dart
/// const ThemeSelector()
/// ```
class ThemeSelector extends ConsumerWidget {
  /// Creates a [ThemeSelector].
  const ThemeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(themeModeProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Container(
      height: AppDimens.touchTargetMin,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppDimens.radiusButton),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          _ThemePill(
            label: 'System',
            mode: ThemeMode.system,
            currentMode: currentMode,
            colorScheme: colorScheme,
            onTap: () => ref.read(themeModeProvider.notifier).state =
                ThemeMode.system,
          ),
          _ThemePill(
            label: 'Light',
            mode: ThemeMode.light,
            currentMode: currentMode,
            colorScheme: colorScheme,
            onTap: () => ref.read(themeModeProvider.notifier).state =
                ThemeMode.light,
          ),
          _ThemePill(
            label: 'Dark',
            mode: ThemeMode.dark,
            currentMode: currentMode,
            colorScheme: colorScheme,
            onTap: () => ref.read(themeModeProvider.notifier).state =
                ThemeMode.dark,
          ),
        ],
      ),
    );
  }
}

/// A single selectable pill within [ThemeSelector].
///
/// Animates its background color between the selected and unselected
/// states using [AnimatedContainer]. The selected state uses
/// [AppColors.primary] as fill; unselected is transparent.
class _ThemePill extends StatelessWidget {
  /// The human-readable label for this option (e.g., "System").
  final String label;

  /// The [ThemeMode] this pill represents.
  final ThemeMode mode;

  /// The currently active [ThemeMode] (used to determine selected state).
  final ThemeMode currentMode;

  /// The active [ColorScheme] for text colour.
  final ColorScheme colorScheme;

  /// Callback invoked when this pill is tapped.
  final VoidCallback onTap;

  /// Creates a [_ThemePill].
  const _ThemePill({
    required this.label,
    required this.mode,
    required this.currentMode,
    required this.colorScheme,
    required this.onTap,
  });

  /// Whether this pill is currently selected.
  bool get _isSelected => mode == currentMode;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: _kAnimDuration,
          curve: Curves.easeInOut,
          margin: const EdgeInsets.all(AppDimens.spaceXs),
          decoration: BoxDecoration(
            color: _isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimens.radiusButton),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontWeight: _isSelected ? FontWeight.w600 : FontWeight.w400,
              color: _isSelected
                  ? AppColors.primaryButtonText
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
