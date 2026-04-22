// Shared primitives for the onboarding product tour.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';

// ── Pillar data ───────────────────────────────────────────────────────────────

class PillarInfo {
  const PillarInfo({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.color,
  });

  final String id;
  final String name;
  final String subtitle;
  final Color color;
}

const Map<String, PillarInfo> kPillars = {
  'heart':     PillarInfo(id: 'heart',     name: 'Heart',     subtitle: 'Your cardiovascular story', color: AppColors.categoryHeart),
  'sleep':     PillarInfo(id: 'sleep',     name: 'Sleep',     subtitle: 'Every night, decoded',      color: AppColors.categorySleep),
  'workout':   PillarInfo(id: 'workout',   name: 'Workout',   subtitle: 'Train with intention',      color: AppColors.categoryActivity),
  'nutrients': PillarInfo(id: 'nutrients', name: 'Nutrients', subtitle: 'Every meal, understood',    color: AppColors.categoryNutrition),
  'journal':   PillarInfo(id: 'journal',   name: 'Journal',   subtitle: 'Reflect, daily',            color: AppColors.primary),
  'water':     PillarInfo(id: 'water',     name: 'Water',     subtitle: 'Hydrate with rhythm',       color: AppColors.categoryBody),
};

// ── Topo background ───────────────────────────────────────────────────────────

class TopoBG extends StatefulWidget {
  const TopoBG({
    super.key,
    this.color = AppColors.primary,
    this.seed = 'zura',
    this.opacity = 0.45,
    this.density = 14,
    this.strokeWidth = 0.8,
    this.animate = true,
  });

  final Color color;
  final String seed;
  final double opacity;
  final int density;
  final double strokeWidth;
  final bool animate;

  @override
  State<TopoBG> createState() => _TopoBGState();
}

class _TopoBGState extends State<TopoBG> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );
    if (widget.animate) _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => CustomPaint(
            painter: _TopoPainter(
              color: widget.color,
              seed: widget.seed,
              opacity: widget.opacity,
              density: widget.density,
              strokeWidth: widget.strokeWidth,
              drift: _ctrl.value * 6.0,
            ),
          ),
        ),
      ),
    );
  }
}

class _TopoPainter extends CustomPainter {
  _TopoPainter({
    required this.color,
    required this.seed,
    required this.opacity,
    required this.density,
    required this.strokeWidth,
    required this.drift,
  });

  final Color color;
  final String seed;
  final double opacity;
  final int density;
  final double strokeWidth;
  final double drift;

  static int _hash(String s) {
    int h = 2166136261;
    for (int i = 0; i < s.length; i++) {
      h ^= s.codeUnitAt(i);
      h = (h * 16777619) & 0xFFFFFFFF;
    }
    return h;
  }

  List<double> _makeRng() {
    final out = <double>[];
    int st = _hash(seed);
    for (int i = 0; i < 300; i++) {
      st = (st + 0x6D2B79F5) & 0xFFFFFFFF;
      int t = st ^ (st >>> 15);
      t = (t * (1 | st)) & 0xFFFFFFFF;
      t ^= t + ((t * (61 | t)) & 0xFFFFFFFF);
      t ^= (t >>> 14);
      out.add((t & 0xFFFFFFFF) / 4294967296.0);
    }
    return out;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rng = _makeRng();
    int ri = 0;
    double r() => rng[ri++ % rng.length];

    for (int i = 0; i < density; i++) {
      final baseY = (i / (density - 1)) * (size.height * 1.4) - size.height * 0.2;
      final segs = 5 + (r() * 3).floor();
      final pts = <Offset>[];

      for (int s = 0; s <= segs; s++) {
        final x = (s / segs) * (size.width + 80) - 40;
        final amp = 26 + r() * 60;
        final phase = r() * math.pi * 2;
        final y = baseY
            + math.sin(s * 1.3 + phase + i * 0.4) * amp
            + (r() - 0.5) * 18;
        pts.add(Offset(x - drift, y - drift * 0.5));
      }

      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (int s = 1; s < pts.length - 1; s++) {
        final mx = (pts[s].dx + pts[s + 1].dx) / 2;
        final my = (pts[s].dy + pts[s + 1].dy) / 2;
        path.quadraticBezierTo(pts[s].dx, pts[s].dy, mx, my);
      }
      path.lineTo(pts.last.dx, pts.last.dy);

      final lineOpacity = (opacity
          * (0.35 + 0.65 * (1 - (i / (density - 1) - 0.5).abs() * 1.2)))
          .clamp(0.0, 1.0);

      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: lineOpacity)
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_TopoPainter old) =>
      old.drift != drift || old.color != color || old.opacity != opacity;
}

// ── Tour screen wrapper ───────────────────────────────────────────────────────

class TourScreen extends StatelessWidget {
  const TourScreen({
    super.key,
    required this.child,
    this.bg = AppColors.canvas,
    this.topo = false,
    this.topoColor = AppColors.primary,
    this.topoSeed = 'zura',
    this.topoOpacity = 0.35,
    this.topoDensity = 14,
    this.topoAnimate = true,
  });

  final Widget child;
  final Color bg;
  final bool topo;
  final Color topoColor;
  final String topoSeed;
  final double topoOpacity;
  final int topoDensity;
  final bool topoAnimate;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: bg,
      child: Stack(
        children: [
          if (topo)
            TopoBG(
              color: topoColor,
              seed: topoSeed,
              opacity: topoOpacity,
              density: topoDensity,
              animate: topoAnimate,
            ),
          child,
        ],
      ),
    );
  }
}

// ── Progress bar ──────────────────────────────────────────────────────────────

class TourProgressBar extends StatelessWidget {
  const TourProgressBar({
    super.key,
    required this.progress,
    this.color = AppColors.primary,
  });

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 72,
      left: 24,
      right: 24,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Container(
          height: 3,
          color: Colors.white.withValues(alpha: 0.08),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress.clamp(0.0, 1.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Primary button ────────────────────────────────────────────────────────────

class TourPrimaryButton extends StatefulWidget {
  const TourPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color = AppColors.primary,
    this.textColor = AppColors.textOnSageDark,
    this.disabled = false,
  });

  final String label;
  final VoidCallback? onTap;
  final Color color;
  final Color textColor;
  final bool disabled;

  @override
  State<TourPrimaryButton> createState() => _TourPrimaryButtonState();
}

class _TourPrimaryButtonState extends State<TourPrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        if (!widget.disabled) widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 180),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          decoration: BoxDecoration(
            color: widget.disabled
                ? Colors.white.withValues(alpha: 0.08)
                : widget.color,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontWeight: FontWeight.w600,
              fontSize: 17,
              letterSpacing: -0.2,
              color: widget.disabled
                  ? Colors.white.withValues(alpha: 0.3)
                  : widget.textColor,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Reveal animation ──────────────────────────────────────────────────────────

class RevealAnimation extends StatefulWidget {
  const RevealAnimation({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 700),
    this.offsetY = 20.0,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offsetY;

  @override
  State<RevealAnimation> createState() => _RevealAnimationState();
}

class _RevealAnimationState extends State<RevealAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<double> _translateY;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _translateY = Tween<double>(begin: widget.offsetY, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Cubic(0.22, 1, 0.36, 1)),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Opacity(
        opacity: _opacity.value,
        child: Transform.translate(
          offset: Offset(0, _translateY.value),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

// ── Chip ──────────────────────────────────────────────────────────────────────

class TourChip extends StatelessWidget {
  const TourChip({
    super.key,
    required this.label,
    required this.color,
    this.filled = false,
  });

  final String label;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.27), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
          color: filled ? AppColors.canvas : color,
        ),
      ),
    );
  }
}

// ── Pillar icon ───────────────────────────────────────────────────────────────

class PillarIcon extends StatelessWidget {
  const PillarIcon({
    super.key,
    required this.pillar,
    this.size = 28.0,
    this.color,
  });

  final String pillar;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? kPillars[pillar]?.color ?? AppColors.primary;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _PillarIconPainter(pillar: pillar, color: c, size: size)),
    );
  }
}

class _PillarIconPainter extends CustomPainter {
  _PillarIconPainter({required this.pillar, required this.color, required this.size});

  final String pillar;
  final Color color;
  final double size;

  @override
  void paint(Canvas canvas, Size sz) {
    final scale = sz.width / 28.0;
    canvas.save();
    canvas.scale(scale, scale);

    final p = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (pillar) {
      case 'heart':
        canvas.drawPath(
          Path()
            ..moveTo(14, 23.5)
            ..cubicTo(6, 19, 6, 11.5, 10.6, 7.5)
            ..cubicTo(12.4, 5.8, 15.6, 5.8, 17.4, 7.5)
            ..cubicTo(22, 11.5, 22, 19, 14, 23.5),
          p,
        );
        break;
      case 'sleep':
        canvas.drawPath(
          Path()
            ..moveTo(21, 15.5)
            ..arcToPoint(const Offset(12.5, 7), radius: const Radius.circular(8), clockwise: false)
            ..arcToPoint(const Offset(21, 15.5), radius: const Radius.circular(8), clockwise: false),
          p,
        );
        break;
      case 'workout':
        for (final l in [
          [4.0, 14.0, 6.0, 14.0],
          [22.0, 14.0, 24.0, 14.0],
          [8.0, 10.0, 8.0, 18.0],
          [20.0, 10.0, 20.0, 18.0],
          [8.0, 14.0, 20.0, 14.0],
          [12.0, 8.0, 12.0, 20.0],
          [16.0, 8.0, 16.0, 20.0],
        ]) {
          canvas.drawLine(Offset(l[0], l[1]), Offset(l[2], l[3]), p);
        }
        break;
      case 'nutrients':
        canvas.drawPath(
          Path()
            ..moveTo(14, 4)
            ..cubicTo(18, 4, 21, 7, 21, 11)
            ..cubicTo(21, 17, 14, 24, 14, 24)
            ..cubicTo(14, 24, 7, 17, 7, 11)
            ..cubicTo(7, 7, 10, 4, 14, 4)
            ..close(),
          p,
        );
        canvas.drawLine(const Offset(14, 8), const Offset(14, 16), p);
        canvas.drawLine(const Offset(10, 12), const Offset(18, 12), p);
        break;
      case 'journal':
        canvas.drawPath(
          Path()
            ..moveTo(6, 5)
            ..lineTo(20, 5)
            ..lineTo(20, 23)
            ..lineTo(7, 23)
            ..lineTo(6, 23)
            ..lineTo(6, 5)
            ..close(),
          p,
        );
        canvas.drawLine(const Offset(10, 10), const Offset(16, 10), p);
        canvas.drawLine(const Offset(10, 14), const Offset(16, 14), p);
        break;
      case 'water':
        canvas.drawPath(
          Path()
            ..moveTo(14, 4)
            ..cubicTo(7, 12, 7, 22, 14, 22)
            ..cubicTo(21, 22, 21, 12, 14, 4),
          p,
        );
        break;
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_PillarIconPainter old) =>
      old.pillar != pillar || old.color != color;
}

// ── App header (shown inside tour screens) ────────────────────────────────────

class TourAppHeader extends StatelessWidget {
  const TourAppHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 70, 20, 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.06),
            ),
            child: Icon(Icons.arrow_back_ios_new, size: 14,
                color: Colors.white.withValues(alpha: 0.8)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 34),
        ],
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class TourStatCard extends StatelessWidget {
  const TourStatCard({super.key, required this.child, this.color});

  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color != null
            ? color!.withValues(alpha: 0.07)
            : Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: color != null
              ? color!.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.08),
          width: 0.5,
        ),
      ),
      child: child,
    );
  }
}

// ── Animated line chart ───────────────────────────────────────────────────────

class TourLineChart extends StatefulWidget {
  const TourLineChart({
    super.key,
    required this.points,
    required this.color,
    this.labels,
    this.height = 140.0,
  });

  final List<double> points;
  final Color color;
  final List<String>? labels;
  final double height;

  @override
  State<TourLineChart> createState() => _TourLineChartState();
}

class _TourLineChartState extends State<TourLineChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _progress = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (_, __) => CustomPaint(
        size: Size(double.infinity, widget.height),
        painter: _LineChartPainter(
          points: widget.points,
          color: widget.color,
          labels: widget.labels,
          progress: _progress.value,
          height: widget.height,
        ),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.points,
    required this.color,
    required this.labels,
    required this.progress,
    required this.height,
  });

  final List<double> points;
  final Color color;
  final List<String>? labels;
  final double progress;
  final double height;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    const pad = 10.0;
    final chartH = height - pad * 2 - (labels != null ? 20.0 : 0);
    final minV = points.reduce(math.min);
    final maxV = points.reduce(math.max);
    final range = (maxV - minV).abs().clamp(1.0, double.infinity);

    final xs = List.generate(
        points.length, (i) => pad + (i / (points.length - 1)) * (size.width - pad * 2));
    final ys = points
        .map((v) => pad + (1 - (v - minV) / range) * chartH)
        .toList();

    // Clip to progress
    final clipPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));
    canvas.save();
    canvas.clipPath(clipPath);

    // Area fill
    final area = Path()..moveTo(xs.first, ys.first);
    for (int i = 1; i < points.length; i++) {
      area.lineTo(xs[i], ys[i]);
    }
    area.lineTo(xs.last, height - (labels != null ? 20 : 0));
    area.lineTo(xs.first, height - (labels != null ? 20 : 0));
    area.close();

    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, height)),
    );

    // Line
    final linePath = Path()..moveTo(xs.first, ys.first);
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(xs[i], ys[i]);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Dots
    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(
        Offset(xs[i], ys[i]),
        3,
        Paint()..color = color,
      );
    }

    canvas.restore();

    // Labels
    if (labels != null) {
      final tp = TextPainter(textDirection: TextDirection.ltr);
      for (int i = 0; i < math.min(labels!.length, xs.length); i++) {
        tp.text = TextSpan(
          text: labels![i],
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        );
        tp.layout();
        tp.paint(canvas, Offset(xs[i] - tp.width / 2, height - 16));
      }
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter old) => old.progress != progress;
}

// ── Bar chart ─────────────────────────────────────────────────────────────────

class TourBarChart extends StatefulWidget {
  const TourBarChart({
    super.key,
    required this.bars,
    required this.color,
    this.labels,
    this.height = 120.0,
  });

  final List<double> bars;
  final Color color;
  final List<String>? labels;
  final double height;

  @override
  State<TourBarChart> createState() => _TourBarChartState();
}

class _TourBarChartState extends State<TourBarChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final val = CurvedAnimation(
            parent: _ctrl, curve: const Cubic(0.22, 1, 0.36, 1))
            .value;
        return SizedBox(
          height: widget.height + 20,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(widget.bars.length, (i) {
              final barH = widget.bars[i] * widget.height * val;
              return Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 600 + i * 80),
                        curve: const Cubic(0.22, 1, 0.36, 1),
                        height: barH.clamp(0.0, widget.height),
                        decoration: BoxDecoration(
                          color: widget.bars[i] > 0
                              ? widget.color
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    if (widget.labels != null && i < widget.labels!.length)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          widget.labels![i],
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
