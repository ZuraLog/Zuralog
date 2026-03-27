/// Zuralog Design System — Collapsible Component.
///
/// A simple show/hide toggle for any content area. Unlike [ZAccordion], this
/// has no card container — it can be embedded inside any layout. The header is
/// tappable and the content animates in/out with a smooth height transition.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';

/// A lightweight collapsible wrapper that toggles content visibility.
///
/// No card, no border, no background — just wraps content with an animated
/// show/hide triggered by tapping the [header].
///
/// ```dart
/// ZCollapsible(
///   header: Text('Advanced settings'),
///   content: Column(children: [/* settings widgets */]),
/// )
/// ```
class ZCollapsible extends StatefulWidget {
  /// Creates a collapsible section.
  const ZCollapsible({
    super.key,
    required this.header,
    required this.content,
    this.initiallyExpanded = false,
  });

  /// The always-visible tappable header that toggles the content.
  final Widget header;

  /// The widget revealed or hidden when the header is tapped.
  final Widget content;

  /// Whether the content starts visible. Defaults to `false`.
  final bool initiallyExpanded;

  @override
  State<ZCollapsible> createState() => _ZCollapsibleState();
}

class _ZCollapsibleState extends State<ZCollapsible> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  void _toggle() {
    setState(() => _isExpanded = !_isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header ────────────────────────────────────────────────────────
        GestureDetector(
          onTap: _toggle,
          behavior: HitTestBehavior.opaque,
          child: widget.header,
        ),

        // ── Content with smooth height animation ─────────────────────────
        AnimatedSize(
          duration: AppMotion.durationMedium,
          curve: AppMotion.curveTransition,
          alignment: Alignment.topCenter,
          child: _isExpanded ? widget.content : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
