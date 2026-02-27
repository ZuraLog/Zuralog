/// Zuralog — Platform Badges Widget.
///
/// Renders small Apple and/or Android icon badges indicating which health
/// data platforms a compatible app supports.
library;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Displays platform compatibility badges for a compatible app.
///
/// Shows Apple icon for HealthKit support and Android icon for Health Connect.
///
/// Parameters:
///   supportsHealthKit: Whether to show the Apple badge.
///   supportsHealthConnect: Whether to show the Android badge.
///   iconSize: Size of each icon in logical pixels (default 14).
class PlatformBadges extends StatelessWidget {
  /// Creates [PlatformBadges].
  const PlatformBadges({
    super.key,
    required this.supportsHealthKit,
    required this.supportsHealthConnect,
    this.iconSize = 14.0,
  });

  /// Whether the app syncs with Apple HealthKit.
  final bool supportsHealthKit;

  /// Whether the app syncs with Google Health Connect.
  final bool supportsHealthConnect;

  /// Size of each icon in logical pixels.
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (supportsHealthKit) ...[
          FaIcon(FontAwesomeIcons.apple, color: color, size: iconSize),
          if (supportsHealthConnect) const SizedBox(width: 4),
        ],
        if (supportsHealthConnect)
          Icon(Icons.android_rounded, color: color, size: iconSize),
      ],
    );
  }
}
