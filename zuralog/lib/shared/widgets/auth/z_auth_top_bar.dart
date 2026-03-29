/// Zuralog Design System — Auth Top Bar.
///
/// A consistent top bar used across all authentication screens.
/// Centers the ZuraLog logo icon and optionally shows a back button.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/shared/widgets/buttons/z_icon_button.dart';

/// Top bar for auth screens: back button (optional) + centred logo.
///
/// The logo and back button are balanced by matching [SizedBox] spacers so
/// the logo stays perfectly centred regardless of whether [showBack] is true.
///
/// Example:
/// ```dart
/// ZAuthTopBar()                          // with back button
/// ZAuthTopBar(showBack: false)           // logo only, no back button
/// ZAuthTopBar(onBack: () => pop(context)) // custom back handler
/// ```
class ZAuthTopBar extends StatelessWidget {
  const ZAuthTopBar({
    super.key,
    this.showBack = true,
    this.onBack,
  });

  /// Whether to show the back arrow on the left side.
  final bool showBack;

  /// Callback fired when the back button is tapped.
  /// Pass null to disable the button while still showing it.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceSm,
        vertical: AppDimens.spaceSm,
      ),
      child: Row(
        children: [
          // Left: back button or balancing spacer
          if (showBack)
            ZIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onPressed: onBack,
              filled: false,
              semanticLabel: 'Back',
            )
          else
            SizedBox(width: AppDimens.touchTargetMin),

          // Centre: logo
          Expanded(
            child: Center(
              child: _LogoImage(),
            ),
          ),

          // Right: balancing spacer — always present to keep logo centred
          SizedBox(width: AppDimens.touchTargetMin),
        ],
      ),
    );
  }
}

/// Brightness-aware logo image.
///
/// - Dark mode: PNG asset with the Sage mark on transparent background.
/// - Light mode: SVG asset recoloured with [AppColorsOf.primary] (Deep Forest)
///   so it meets WCAG contrast on light canvases.
class _LogoImage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    if (brightness == Brightness.dark) {
      return Image.asset(
        AppAssets.logoSagePng,
        width: 28,
        height: 28,
      );
    }

    return SvgPicture.asset(
      AppAssets.logoSvg,
      width: 28,
      height: 28,
      colorFilter: ColorFilter.mode(
        AppColorsOf(context).primary,
        BlendMode.srcIn,
      ),
    );
  }
}
