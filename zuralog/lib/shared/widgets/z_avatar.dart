/// Zuralog Design System — Avatar Widget.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// Circular avatar showing a network image or initials fallback.
///
/// Example:
/// ```dart
/// ZAvatar(imageUrl: user.avatarUrl, initials: 'JD')
/// ZAvatar(initials: 'AB', size: 56)
/// ```
class ZAvatar extends StatelessWidget {
  const ZAvatar({
    super.key,
    this.imageUrl,
    this.initials,
    this.size = AppDimens.avatarMd,
    this.onTap,
  });

  final String? imageUrl;
  final String? initials;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.surfaceContainerHighest,
        image: imageUrl != null
            ? DecorationImage(
                image: NetworkImage(imageUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: imageUrl == null
          ? Center(
              child: Text(
                (initials ?? '?').toUpperCase(),
                style: AppTextStyles.labelLarge.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: size * 0.35,
                ),
              ),
            )
          : null,
    );

    if (onTap != null) {
      avatar = GestureDetector(onTap: onTap, child: avatar);
    }
    return avatar;
  }
}
