/// Zuralog Design System — Star Rating Input Component.
///
/// A row of tappable stars for wellness check-in ratings.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';

/// Star-based rating input for wellness check-ins.
///
/// Displays a row of [maxRating] stars. Filled stars use the brand Sage
/// color; empty stars use the theme's raised surface color. Each star
/// meets the 44px minimum touch target for accessibility.
class ZRatingBar extends StatelessWidget {
  /// Creates a [ZRatingBar].
  const ZRatingBar({
    super.key,
    required this.rating,
    required this.onChanged,
    this.maxRating = 5,
    this.size = 28.0,
    this.enabled = true,
  })  : assert(maxRating > 0, 'maxRating must be greater than zero'),
        assert(rating >= 0 && rating <= maxRating,
            'rating must be between 0 and maxRating');

  /// The current rating (1-based). Zero means no stars selected.
  final int rating;

  /// Called when the user taps a star. Passes the new rating value.
  final ValueChanged<int> onChanged;

  /// Total number of stars to display.
  final int maxRating;

  /// Icon size in logical pixels.
  final double size;

  /// Whether the rating bar accepts taps.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return Semantics(
      label: 'Rating: $rating out of $maxRating stars',
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(maxRating, (index) {
            final starValue = index + 1;
            final isFilled = starValue <= rating;

            final touchSize = size < 44 ? 44.0 : size;
            return SizedBox(
              width: touchSize,
              height: touchSize,
              child: GestureDetector(
                onTap: enabled ? () => onChanged(starValue) : null,
                behavior: HitTestBehavior.opaque,
                child: Center(
                  child: Icon(
                    Icons.star_rounded,
                    size: size,
                    color: isFilled ? AppColors.primary : colors.surfaceRaised,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
