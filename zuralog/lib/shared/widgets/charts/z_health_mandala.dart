/// Radial mandala visualization — the hero of the All Data screen.
///
/// One wedge per [HealthCategory] in clockwise order from top:
/// Sleep, Activity (Move), Heart, Nutrition (Food), Body, Wellness (Mind).
/// Each wedge has one spoke per metric. Spoke length encodes today's value
/// vs the user's 30-day baseline (long spoke = good day, always).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/data/domain/category_color.dart';
import 'package:zuralog/features/data/domain/data_models.dart' show HealthCategory;
import 'package:zuralog/features/data/domain/mandala_data.dart';

/// Fixed clockwise display order — Sleep at top.
const List<HealthCategory> kMandalaCategoryOrder = [
  HealthCategory.sleep,
  HealthCategory.activity,
  HealthCategory.heart,
  HealthCategory.nutrition,
  HealthCategory.body,
  HealthCategory.wellness,
];

/// Callback when the user taps a spoke. Receives the metric id.
typedef SpokeTapCallback = void Function(String metricId);

/// Callback when the user taps the center disc.
typedef CenterTapCallback = void Function();

class ZHealthMandala extends StatefulWidget {
  const ZHealthMandala({
    super.key,
    required this.data,
    required this.healthScore,
    this.onSpokeTap,
    this.onCenterTap,
  });

  /// The wedges + spokes to draw. Wedges should be in [kMandalaCategoryOrder]
  /// — missing categories render as empty wedges.
  final MandalaData data;

  /// Number rendered in the center disc. Pass `null` to render "—".
  final int? healthScore;

  final SpokeTapCallback? onSpokeTap;
  final CenterTapCallback? onCenterTap;

  @override
  State<ZHealthMandala> createState() => _ZHealthMandalaState();
}

class _ZHealthMandalaState extends State<ZHealthMandala>
    with TickerProviderStateMixin {
  AnimationController? _entryCtrl;
  AnimationController? _breathCtrl;
  bool _reducedMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced == _reducedMotion && (_entryCtrl != null || reduced)) return;
    _reducedMotion = reduced;
    _disposeControllers();
    if (!reduced) {
      _entryCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 700),
      )..forward();
      _breathCtrl = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 6),
      )..repeat(reverse: true);
    }
  }

  void _disposeControllers() {
    _entryCtrl?.dispose();
    _entryCtrl = null;
    _breathCtrl?.dispose();
    _breathCtrl = null;
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = math.min(constraints.maxWidth, constraints.maxHeight);
          return Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    ?_entryCtrl,
                    ?_breathCtrl,
                  ]),
                  builder: (context, _) {
                    final entry =
                        _reducedMotion ? 1.0 : (_entryCtrl?.value ?? 1.0);
                    final breath = _reducedMotion
                        ? 0.55
                        : 0.4 + ((_breathCtrl?.value ?? 0.5) * 0.25);
                    return CustomPaint(
                      painter: _MandalaPainter(
                        data: widget.data,
                        colors: colors,
                        entryProgress: entry,
                        breathOpacity: breath,
                      ),
                    );
                  },
                ),
              ),
              // Center tap target (disc).
              SizedBox(
                width: size * 0.27,
                height: size * 0.27,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onCenterTap,
                  child: Center(
                    child: Text(
                      widget.healthScore?.toString() ?? '—',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.displayLarge.copyWith(
                        fontFamily: 'Lora',
                        fontWeight: FontWeight.w600,
                        fontSize: size * 0.115,
                        height: 1.0,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              // Spoke tap targets.
              ..._buildSpokeTapTargets(size),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildSpokeTapTargets(double size) {
    final targets = <Widget>[];
    final centerOffset = Offset(size / 2, size / 2);
    final outerRadius = size / 2;
    final spokeBaseRadius = outerRadius * 0.85;
    final baselineRadius = spokeBaseRadius * 0.7;
    const wedgeArc = math.pi / 3; // 60°
    const wedgePad = math.pi / 36; // 5°

    for (var w = 0; w < kMandalaCategoryOrder.length; w++) {
      final cat = kMandalaCategoryOrder[w];
      final wedge = widget.data.wedges.firstWhere(
        (wd) => wd.category == cat,
        orElse: () => MandalaWedge(category: cat, spokes: const []),
      );
      if (wedge.spokes.isEmpty) continue;

      final wedgeStart = -math.pi / 2 + (w * wedgeArc);
      final usable = wedgeArc - 2 * wedgePad;
      final spokes = wedge.spokes;
      for (var i = 0; i < spokes.length; i++) {
        final s = spokes[i];
        final ratio = computeSpokeRatio(
          todayValue: s.todayValue,
          baseline: s.baseline30d,
          inverted: s.inverted,
        );
        if (ratio == null) continue;
        final angle = spokes.length == 1
            ? wedgeStart + wedgeArc / 2
            : wedgeStart +
                wedgePad +
                (usable * (i / (spokes.length - 1)));
        final length = baselineRadius * ratio;
        final tipX = centerOffset.dx + math.cos(angle) * length;
        final tipY = centerOffset.dy + math.sin(angle) * length;
        targets.add(Positioned(
          left: tipX - 12,
          top: tipY - 12,
          width: 24,
          height: 24,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.onSpokeTap?.call(s.metricId),
            child: const SizedBox.expand(),
          ),
        ));
      }
    }
    return targets;
  }
}

class _MandalaPainter extends CustomPainter {
  _MandalaPainter({
    required this.data,
    required this.colors,
    required this.entryProgress,
    required this.breathOpacity,
  });

  final MandalaData data;
  final AppColorsOf colors;
  final double entryProgress;
  final double breathOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.shortestSide / 2;
    final spokeBaseRadius = outerRadius * 0.85;
    final baselineRadius = spokeBaseRadius * 0.7;

    _paintHalo(canvas, center, outerRadius);
    _paintWedges(canvas, center, outerRadius);
    _paintBaselineRing(canvas, center, baselineRadius);
    _paintSeparators(canvas, center, outerRadius);
    _paintSpokes(canvas, center, baselineRadius);
    _paintCenterDisc(canvas, center, outerRadius);
  }

  void _paintHalo(Canvas canvas, Offset center, double r) {
    final shader = RadialGradient(
      colors: [
        AppColors.primary.withValues(alpha: 0.16),
        AppColors.primary.withValues(alpha: 0.04),
        Colors.transparent,
      ],
      stops: const [0.0, 0.6, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, Paint()..shader = shader);
  }

  void _paintWedges(Canvas canvas, Offset center, double outerRadius) {
    const wedgeArc = math.pi / 3;
    final wedgeRadius = outerRadius * 0.85;
    for (var w = 0; w < kMandalaCategoryOrder.length; w++) {
      final cat = kMandalaCategoryOrder[w];
      final color = categoryColor(cat);
      final start = -math.pi / 2 + (w * wedgeArc);

      final shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.22),
          color.withValues(alpha: 0.04),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: wedgeRadius));

      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: wedgeRadius),
          start,
          wedgeArc,
          false,
        )
        ..close();
      canvas.drawPath(path, Paint()..shader = shader);
    }
  }

  void _paintBaselineRing(Canvas canvas, Offset center, double r) {
    final paint = Paint()
      ..color = colors.textSecondary.withValues(alpha: breathOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    _drawDashedCircle(canvas, center, r, paint, dash: 3, gap: 4);
  }

  void _paintSeparators(Canvas canvas, Offset center, double outerRadius) {
    const wedgeArc = math.pi / 3;
    final paint = Paint()
      ..color = colors.canvas.withValues(alpha: 0.6)
      ..strokeWidth = 1.5;
    final r = outerRadius * 0.85;
    for (var w = 0; w < kMandalaCategoryOrder.length; w++) {
      final angle = -math.pi / 2 + (w * wedgeArc);
      canvas.drawLine(
        center,
        center + Offset(math.cos(angle) * r, math.sin(angle) * r),
        paint,
      );
    }
  }

  void _paintSpokes(Canvas canvas, Offset center, double baselineRadius) {
    const wedgeArc = math.pi / 3;
    const wedgePad = math.pi / 36;

    for (var w = 0; w < kMandalaCategoryOrder.length; w++) {
      final cat = kMandalaCategoryOrder[w];
      final color = categoryColor(cat);
      final wedge = data.wedges.firstWhere(
        (wd) => wd.category == cat,
        orElse: () => MandalaWedge(category: cat, spokes: const []),
      );
      if (wedge.spokes.isEmpty) continue;

      // Stagger: 40ms / 700ms ≈ 0.057 per category, each spoke 220ms ≈ 0.31.
      final categoryProgress =
          ((entryProgress - w * 0.057) / 0.31).clamp(0.0, 1.0);
      if (categoryProgress <= 0) continue; // not yet animating in

      final wedgeStart = -math.pi / 2 + (w * wedgeArc);
      final usable = wedgeArc - 2 * wedgePad;
      final spokes = wedge.spokes;

      for (var i = 0; i < spokes.length; i++) {
        final s = spokes[i];
        final ratio = computeSpokeRatio(
          todayValue: s.todayValue,
          baseline: s.baseline30d,
          inverted: s.inverted,
        );
        if (ratio == null) continue;
        final angle = spokes.length == 1
            ? wedgeStart + wedgeArc / 2
            : wedgeStart +
                wedgePad +
                (usable * (i / (spokes.length - 1)));
        final length = baselineRadius * ratio * categoryProgress;
        final tip = center +
            Offset(math.cos(angle) * length, math.sin(angle) * length);
        final atOrAbove = ratio >= 1.0;
        final opacity = atOrAbove ? 1.0 : 0.65;

        canvas.drawLine(
          center,
          tip,
          Paint()
            ..color = color.withValues(alpha: opacity)
            ..strokeWidth = 1.8
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawCircle(
          tip,
          2.6,
          Paint()..color = color.withValues(alpha: opacity),
        );
      }
    }
  }

  void _paintCenterDisc(Canvas canvas, Offset center, double outerRadius) {
    final r = outerRadius * 0.135;
    canvas.drawCircle(center, r, Paint()..color = colors.surface);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = colors.elevatedSurface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
  }

  void _drawDashedCircle(
    Canvas canvas,
    Offset center,
    double r,
    Paint paint, {
    required double dash,
    required double gap,
  }) {
    final circumference = 2 * math.pi * r;
    final dashCount = (circumference / (dash + gap)).floor();
    final stepAngle = (2 * math.pi) / dashCount;
    final dashAngle = stepAngle * (dash / (dash + gap));
    for (var i = 0; i < dashCount; i++) {
      final start = i * stepAngle;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        start,
        dashAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MandalaPainter old) =>
      old.data != data ||
      old.colors != colors ||
      old.entryProgress != entryProgress ||
      old.breathOpacity != breathOpacity;
}
