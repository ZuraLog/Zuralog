/// Zuralog Design System — Avatar Widget.
///
/// Brand bible sizes: 48 (lg), 36 (md), 24 (sm).
/// Placeholder: surfaceRaised with pattern overlay and Sage initials.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

/// Avatar size presets matching the brand bible.
enum ZAvatarSize {
  lg(48),
  md(36),
  sm(24);

  const ZAvatarSize(this.diameter);
  final double diameter;
}

/// Circular avatar showing a network image or initials fallback.
///
/// When no image is provided, renders a surfaceRaised circle with a
/// subtle pattern overlay and Sage-colored initials.
///
/// Example:
/// ```dart
/// ZAvatar(imageUrl: user.avatarUrl, initials: 'JD')
/// ZAvatar(initials: 'AB', size: ZAvatarSize.sm)
/// ```
class ZAvatar extends StatelessWidget {
  const ZAvatar({
    super.key,
    this.imageUrl,
    this.initials,
    this.avatarSize = ZAvatarSize.md,
    this.size,
    this.onTap,
    this.semanticLabel,
  });

  final String? imageUrl;
  final String? initials;

  /// Preferred size enum. Defaults to [ZAvatarSize.md] (36px).
  final ZAvatarSize avatarSize;

  /// Override diameter in logical pixels. When set, takes priority over
  /// [avatarSize]. Kept for backwards compatibility.
  final double? size;

  final VoidCallback? onTap;

  /// Accessibility label for screen readers.
  final String? semanticLabel;

  double get _diameter => size ?? avatarSize.diameter;

  /// Returns the initials/icon placeholder — used both as the default avatar
  /// and as the fallback when a network image fails or is still loading.
  Widget _placeholder(AppColorsOf colors) {
    return SizedBox(
      width: _diameter,
      height: _diameter,
      child: ClipOval(
        child: Stack(
          children: [
            // Background
            Container(color: colors.surfaceRaised),
            // Pattern overlay
            Positioned.fill(
              child: ZPatternOverlay(
                variant: ZPatternVariant.original,
                opacity: 0.15,
                blendMode: BlendMode.screen,
              ),
            ),
            // Initials (max 2 characters)
            Center(
              child: Text(
                (initials ?? '?').toUpperCase().characters.take(2).string,
                overflow: TextOverflow.clip,
                maxLines: 1,
                style: AppTextStyles.labelLarge.copyWith(
                  color: colors.primary,
                  fontSize: _diameter * 0.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    Widget avatar;

    if (imageUrl != null) {
      // Image avatar — ClipOval + Image.network for error/loading callbacks.
      avatar = SizedBox(
        width: _diameter,
        height: _diameter,
        child: ClipOval(
          child: Image.network(
            imageUrl!,
            width: _diameter,
            height: _diameter,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _placeholder(AppColorsOf(context)),
            loadingBuilder: (context, child, loadingProgress) =>
                loadingProgress == null ? child : _placeholder(AppColorsOf(context)),
          ),
        ),
      );
    } else {
      // Placeholder avatar with pattern overlay and Sage initials
      avatar = _placeholder(colors);
    }

    if (onTap != null) {
      avatar = Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: avatar,
        ),
      );
    }

    return Semantics(
      label: semanticLabel ?? 'Avatar',
      button: onTap != null,
      excludeSemantics: true,
      child: avatar,
    );
  }
}
