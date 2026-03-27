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
  });

  final String? imageUrl;
  final String? initials;

  /// Preferred size enum. Defaults to [ZAvatarSize.md] (36px).
  final ZAvatarSize avatarSize;

  /// Override diameter in logical pixels. When set, takes priority over
  /// [avatarSize]. Kept for backwards compatibility.
  final double? size;

  final VoidCallback? onTap;

  double get _diameter => size ?? avatarSize.diameter;

  @override
  Widget build(BuildContext context) {
    Widget avatar;

    if (imageUrl != null) {
      // Image avatar — no pattern needed
      avatar = Container(
        width: _diameter,
        height: _diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(
            image: NetworkImage(imageUrl!),
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      // Placeholder avatar with pattern overlay and Sage initials
      avatar = SizedBox(
        width: _diameter,
        height: _diameter,
        child: ClipOval(
          child: Stack(
            children: [
              // Background
              Container(color: AppColors.surfaceRaised),
              // Pattern overlay
              Positioned.fill(
                child: ZPatternOverlay(
                  variant: ZPatternVariant.original,
                  opacity: 0.15,
                  blendMode: BlendMode.screen,
                ),
              ),
              // Initials
              Center(
                child: Text(
                  (initials ?? '?').toUpperCase(),
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.primary,
                    fontSize: _diameter * 0.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (onTap != null) {
      avatar = GestureDetector(onTap: onTap, child: avatar);
    }
    return avatar;
  }
}
