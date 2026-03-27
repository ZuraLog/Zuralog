/// Zuralog Design System — Carousel Component.
///
/// A horizontal scrolling container that displays cards in a row with a
/// "peek" effect — the next card is partially visible on the right edge,
/// hinting that more content is available.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';

/// The amount of the next card visible on the right edge (in logical pixels).
const double _kPeekWidth = 24.0;

/// Gap between each card in the carousel.
const double _kItemGap = 12.0;

/// A horizontal scrolling card carousel with a peek affordance.
///
/// Shows cards in a horizontal row. The rightmost visible card peeks in
/// from the edge so users know they can scroll for more. No pagination
/// dots — the peek itself is the hint.
///
/// ```dart
/// ZCarousel(
///   height: 200,
///   children: [
///     ZSnapshotCard(...),
///     ZSnapshotCard(...),
///     ZSnapshotCard(...),
///   ],
/// )
/// ```
class ZCarousel extends StatelessWidget {
  /// Creates a horizontal card carousel.
  const ZCarousel({
    super.key,
    required this.children,
    this.height = 180.0,
    this.itemWidth,
    this.padding,
  });

  /// The cards (or any widgets) to display in the carousel.
  final List<Widget> children;

  /// Height of the carousel area. Defaults to 180.
  final double height;

  /// Fixed width for each item. When `null`, each item is sized to fill the
  /// visible area minus the peek amount so one-and-a-bit cards are visible.
  final double? itemWidth;

  /// Horizontal padding around the scroll content. Defaults to 16px on the
  /// left (matching the standard screen margin) and 0 on the right so cards
  /// scroll off the edge naturally.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.sizeOf(context).width;
    final resolvedPadding = padding ??
        const EdgeInsets.only(left: AppDimens.spaceMd);
    final leftInset = resolvedPadding.resolve(TextDirection.ltr).left;
    final computedItemWidth =
        itemWidth ?? (screenWidth - leftInset - _kPeekWidth);

    return Semantics(
      label: 'Scrollable carousel',
      child: SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: resolvedPadding,
          clipBehavior: Clip.none,
          itemCount: children.length,
          separatorBuilder: (_, _) => const SizedBox(width: _kItemGap),
          itemBuilder: (_, index) => SizedBox(
            width: computedItemWidth,
            child: children[index],
          ),
        ),
      ),
    );
  }
}
