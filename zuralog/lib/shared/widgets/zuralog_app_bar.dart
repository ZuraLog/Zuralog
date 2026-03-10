/// Zuralog — ZuralogAppBar shared widget.
///
/// Zuralog shared AppBar — base properties hardcoded (elevation,
/// scrolledUnderElevation, surfaceTintColor), ProfileAvatarButton
/// always appended as last action. Used by every root tab screen.
/// Background color is inherited from AppBarTheme in AppTheme.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/onboarding_tooltip.dart';
import 'package:zuralog/shared/widgets/profile_avatar_button.dart';

// ── ZuralogAppBarTooltipConfig ────────────────────────────────────────────────

/// Configures the optional [OnboardingTooltip] on the [ZuralogAppBar] title.
///
/// When provided to [ZuralogAppBar.tooltipConfig], the title text is wrapped in
/// an [OnboardingTooltip] using these values.
class ZuralogAppBarTooltipConfig {
  const ZuralogAppBarTooltipConfig({
    required this.screenKey,
    required this.tooltipKey,
    required this.message,
  });

  final String screenKey;
  final String tooltipKey;
  final String message;
}

// ── ZuralogAppBar ─────────────────────────────────────────────────────────────

/// Zuralog shared AppBar — base properties hardcoded (elevation,
/// scrolledUnderElevation, surfaceTintColor), ProfileAvatarButton
/// always appended as last action. Background inherited from AppBarTheme.
/// Used by every root tab screen.
///
/// Note: this widget embeds [ProfileAvatarButton], which is a Riverpod
/// [ConsumerWidget] and requires a [ProviderScope] ancestor. Wrap with
/// [ProviderScope] in widget tests.
class ZuralogAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ZuralogAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.tooltipConfig,
  });

  /// The title text displayed in the app bar.
  final String title;

  /// An optional leading widget (e.g. back button).
  final Widget? leading;

  /// Optional tab-specific action buttons inserted BEFORE the avatar.
  final List<Widget>? actions;

  /// When provided, wraps the title in an [OnboardingTooltip].
  final ZuralogAppBarTooltipConfig? tooltipConfig;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final titleText = Text(title, style: AppTextStyles.displaySmall);

    final Widget titleWidget = tooltipConfig != null
        ? OnboardingTooltip(
            screenKey: tooltipConfig!.screenKey,
            tooltipKey: tooltipConfig!.tooltipKey,
            message: tooltipConfig!.message,
            child: titleText,
          )
        : titleText;

    final fullActions = [
      ...?actions,
      const Padding(
        padding: EdgeInsets.only(right: AppDimens.spaceMd),
        child: ProfileAvatarButton(),
      ),
    ];

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: leading,
      title: titleWidget,
      actions: fullActions,
    );
  }
}
