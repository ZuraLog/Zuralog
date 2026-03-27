/// Zuralog Design System — Theme-Aware Divider.
///
/// Brand bible spec: 1px solid rgba(240,238,233,0.06).
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';

/// A thin horizontal divider matching the brand bible specification.
///
/// Uses the brand bible divider color token (warm white at 6% opacity).
///
/// Example:
/// ```dart
/// const ZDivider()
/// const ZDivider(inset: 16)
/// ```
class ZDivider extends StatelessWidget {
  const ZDivider({
    super.key,
    this.indent = 0,
    this.endIndent = 0,
    this.inset = 0,
  });

  final double indent;
  final double endIndent;

  /// Horizontal margin applied equally on both sides.
  /// This is a convenience shorthand — when set, it overrides [indent]
  /// and [endIndent].
  final double inset;

  @override
  Widget build(BuildContext context) {
    final effectiveIndent = inset > 0 ? inset : indent;
    final effectiveEndIndent = inset > 0 ? inset : endIndent;

    return Container(
      height: 1,
      margin: EdgeInsets.only(
        left: effectiveIndent,
        right: effectiveEndIndent,
      ),
      color: AppColors.dividerDefault,
    );
  }
}
