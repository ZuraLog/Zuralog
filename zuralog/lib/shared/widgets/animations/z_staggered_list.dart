/// Zuralog Design System — Staggered Entrance Animation Wrapper.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

/// Wraps each child in a [ZFadeSlideIn] with an increasing delay so items
/// cascade in one after another — a "waterfall" entrance effect.
///
/// Example:
/// ```dart
/// ZStaggeredList(
///   children: [
///     CardA(),
///     CardB(),
///     CardC(),
///   ],
/// )
/// ```
class ZStaggeredList extends StatelessWidget {
  const ZStaggeredList({
    super.key,
    required this.children,
    this.staggerDelay = AppMotion.staggerDelay,
    this.itemDuration,
    this.offset = 12.0,
  });

  /// The widgets to display in a staggered cascade.
  final List<Widget> children;

  /// Time between each child's entrance start. Defaults to 60ms.
  final Duration staggerDelay;

  /// How long each individual fade + slide animation lasts.
  /// Defaults to [AppMotion.durationEntrance] (600ms).
  final Duration? itemDuration;

  /// Vertical slide distance in logical pixels. Positive = starts below.
  final double offset;

  @override
  Widget build(BuildContext context) {
    final duration = itemDuration ?? AppMotion.durationEntrance;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++)
          ZFadeSlideIn(
            delay: staggerDelay * (i < 10 ? i : 10),
            duration: duration,
            offset: offset,
            child: children[i],
          ),
      ],
    );
  }
}
