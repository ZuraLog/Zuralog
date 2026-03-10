/// Zuralog Design System — Theme-Aware Divider.
library;

import 'package:flutter/material.dart';

/// A thin horizontal divider that uses theme border color.
///
/// Prefer this over [Divider] directly to prevent accidental hardcoded colors.
///
/// Example:
/// ```dart
/// const ZDivider()
/// const ZDivider(indent: 16)
/// ```
class ZDivider extends StatelessWidget {
  const ZDivider({
    super.key,
    this.indent = 0,
    this.endIndent = 0,
  });

  final double indent;
  final double endIndent;

  @override
  Widget build(BuildContext context) {
    return Divider(
      thickness: 0.5,
      indent: indent,
      endIndent: endIndent,
      // Color from theme's dividerTheme — never hardcoded.
    );
  }
}
