/// Body silhouette (front OR back view) with invisible tap regions layered
/// over each muscle group. Tapping a region calls [onMuscleTap].
///
/// flutter_svg doesn't expose per-path hit-testing, so instead we overlay
/// `GestureDetector`s positioned by fractions of the aspect-ratio box.
/// The body renders via [MuscleHighlightDiagram.zones] with a cropped
/// viewBox (the widget already drops the unused half), so the fractions
/// below map directly to where the muscle lives on screen.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/workout/domain/exercise.dart' show MuscleGroup;
import 'package:zuralog/shared/widgets/muscle_highlight_diagram.dart';

/// Tap region as a fraction (0-1) of the aspect-ratio container.
typedef _Hit = ({MuscleGroup group, Rect rect});

// Hit regions as fractions (0-1) of the cropped 374.4 × 711.6 viewBox.
// Calibrated by reading the real path bounds out of body_map.svg — the
// arms don't reach the outer edges, they live in ~20-35% / 65-82% of the
// width; biceps and triceps share those same x-ranges on the front and
// back views respectively.
const List<_Hit> _frontHits = [
  (group: MuscleGroup.shoulders, rect: Rect.fromLTWH(0.14, 0.13, 0.72, 0.10)),
  (group: MuscleGroup.chest,     rect: Rect.fromLTWH(0.30, 0.18, 0.40, 0.12)),
  // Biceps — upper arm, each side.
  (group: MuscleGroup.biceps,    rect: Rect.fromLTWH(0.18, 0.23, 0.18, 0.13)),
  (group: MuscleGroup.biceps,    rect: Rect.fromLTWH(0.64, 0.23, 0.18, 0.13)),
  (group: MuscleGroup.abs,       rect: Rect.fromLTWH(0.32, 0.31, 0.36, 0.14)),
  // Forearms sit just below the biceps on each side.
  (group: MuscleGroup.forearms,  rect: Rect.fromLTWH(0.08, 0.37, 0.18, 0.13)),
  (group: MuscleGroup.forearms,  rect: Rect.fromLTWH(0.74, 0.37, 0.18, 0.13)),
  (group: MuscleGroup.quads,     rect: Rect.fromLTWH(0.28, 0.49, 0.44, 0.20)),
  (group: MuscleGroup.calves,    rect: Rect.fromLTWH(0.30, 0.71, 0.40, 0.22)),
];

// Back view hit regions. Same spatial layout as the front (body
// silhouette is symmetric), different labels — triceps where biceps are,
// back/glutes/hamstrings across the torso and lower body.
const List<_Hit> _backHits = [
  (group: MuscleGroup.shoulders,  rect: Rect.fromLTWH(0.14, 0.13, 0.72, 0.10)),
  (group: MuscleGroup.back,       rect: Rect.fromLTWH(0.30, 0.19, 0.40, 0.20)),
  // Triceps — mirror image of biceps, same x/y ranges.
  (group: MuscleGroup.triceps,    rect: Rect.fromLTWH(0.18, 0.23, 0.18, 0.13)),
  (group: MuscleGroup.triceps,    rect: Rect.fromLTWH(0.64, 0.23, 0.18, 0.13)),
  (group: MuscleGroup.forearms,   rect: Rect.fromLTWH(0.08, 0.37, 0.18, 0.13)),
  (group: MuscleGroup.forearms,   rect: Rect.fromLTWH(0.74, 0.37, 0.18, 0.13)),
  (group: MuscleGroup.glutes,     rect: Rect.fromLTWH(0.30, 0.40, 0.40, 0.10)),
  (group: MuscleGroup.hamstrings, rect: Rect.fromLTWH(0.28, 0.50, 0.44, 0.20)),
  (group: MuscleGroup.calves,     rect: Rect.fromLTWH(0.30, 0.71, 0.40, 0.22)),
];

class TappableBodySide extends StatelessWidget {
  const TappableBodySide({
    super.key,
    required this.isBack,
    required this.zones,
    required this.onMuscleTap,
    this.baseColor,
    this.label,
  });

  final bool isBack;
  final Map<MuscleGroup, Color> zones;
  final Color? baseColor;
  final void Function(MuscleGroup) onMuscleTap;

  /// Optional "FRONT" / "BACK" caption rendered below the figure.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final base = baseColor ?? colors.textSecondary.withValues(alpha: 0.40);
    final hits = isBack ? _backHits : _frontHits;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 374.4 / 711.6,
          child: LayoutBuilder(builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            final stack = Stack(children: [
              Positioned.fill(
                child: MuscleHighlightDiagram.zones(
                  zones: zones,
                  baseColor: base,
                  onlyFront: !isBack,
                  onlyBack: isBack,
                  strokeless: true,
                ),
              ),
              for (final hit in hits)
                Positioned(
                  left: hit.rect.left * w,
                  top: hit.rect.top * h,
                  width: hit.rect.width * w,
                  height: hit.rect.height * h,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onMuscleTap(hit.group),
                    child: const SizedBox.expand(),
                  ),
                ),
            ]);

            // Mirror the back view horizontally so the figure reads as
            // "person facing away from you" — anatomical convention in
            // body-map apps. Transform's default `transformHitTests:
            // true` mirrors the GestureDetector hit regions too, so
            // the user taps what they see and the right muscle fires.
            if (!isBack) return stack;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(-1.0, 1.0, 1.0),
              child: stack,
            );
          }),
        ),
        if (label != null) ...[
          const SizedBox(height: 6),
          Text(
            label!.toUpperCase(),
            style: AppTextStyles.labelSmall.copyWith(
              color: colors.textSecondary,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}
