/// Zuralog Design System — Log Floating Action Button.
///
/// Brand bible: 56px circle, Sage fill with pattern overlay (sage, 0.18,
/// colorBurn), textOnSage icon, drop shadow. The ONLY component with a
/// shadow in dark mode.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/shared/widgets/buttons/spring_button.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

/// Floating action button for opening the log grid sheet.
///
/// Pass this as the `floatingActionButton` parameter on [ZuralogScaffold].
/// [onPressed] is called on every tap — the caller must debounce if needed.
class ZLogFab extends StatelessWidget {
  const ZLogFab({super.key, required this.onPressed});

  /// Called when the FAB is tapped.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Semantics(
      button: true,
      label: 'Log new entry',
      child: ZuralogSpringButton(
        onTap: onPressed,
        scaleTarget: 0.90,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.primary,
            boxShadow: const [
              BoxShadow(
                color: Color(0x4D000000), // rgba(0,0,0,0.3)
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Sage fill (already the container background)
                const SizedBox.expand(),
                // Pattern overlay — extended horizontally so BoxFit.cover
                // creates vertical overflow, giving the alignment drift room
                // to produce visible movement. ClipOval handles the clipping.
                Positioned(
                  left: -32,
                  right: -32,
                  top: 0,
                  bottom: 0,
                  child: ZPatternOverlay(
                    variant: ZPatternVariant.sage,
                    opacity: 0.5,
                    animate: true,
                  ),
                ),
                // Icon
                Icon(
                  Icons.add_rounded,
                  size: AppDimens.iconMd,
                  color: colors.textOnSage,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
