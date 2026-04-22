library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import './tour_widgets.dart';

// ── Intro screen ──────────────────────────────────────────────────────────────

class TourIntroScreen extends StatefulWidget {
  const TourIntroScreen({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  State<TourIntroScreen> createState() => _TourIntroScreenState();
}

class _TourIntroScreenState extends State<TourIntroScreen>
    with TickerProviderStateMixin {
  late AnimationController _breatheCtrl;
  late AnimationController _revealCtrl;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _titleOpacity;
  late Animation<double> _subtitleOpacity;
  late Animation<double> _ctaOpacity;

  @override
  void initState() {
    super.initState();

    _breatheCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);

    _revealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    );

    _logoScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _revealCtrl,
        curve: const Interval(0.0, 0.35, curve: Cubic(0.22, 1, 0.36, 1)),
      ),
    );
    _logoOpacity = CurvedAnimation(
      parent: _revealCtrl,
      curve: const Interval(0.0, 0.28, curve: Curves.easeOut),
    );
    _titleOpacity = CurvedAnimation(
      parent: _revealCtrl,
      curve: const Interval(0.22, 0.52, curve: Curves.easeOut),
    );
    _subtitleOpacity = CurvedAnimation(
      parent: _revealCtrl,
      curve: const Interval(0.36, 0.60, curve: Curves.easeOut),
    );
    _ctaOpacity = CurvedAnimation(
      parent: _revealCtrl,
      curve: const Interval(0.56, 0.82, curve: Curves.easeOut),
    );

    _revealCtrl.forward();
  }

  @override
  void dispose() {
    _breatheCtrl.dispose();
    _revealCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TourScreen(
      topo: true,
      topoColor: AppColors.primary,
      topoSeed: 'intro',
      topoOpacity: 0.28,
      topoDensity: 18,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.4,
                  colors: [
                    Colors.transparent,
                    AppColors.canvas.withValues(alpha: 0.72),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: AnimatedBuilder(
              animation: _revealCtrl,
              builder: (context, _) {
                return Column(
                  children: [
                    const Spacer(flex: 3),
                    Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: AnimatedBuilder(
                          animation: _breatheCtrl,
                          builder: (_, __) => _LogoMark(
                            breathe: _breatheCtrl.value,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Opacity(
                      opacity: _titleOpacity.value,
                      child: const Text(
                        'ZuraLog',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 52,
                          fontWeight: FontWeight.w300,
                          letterSpacing: -2,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Opacity(
                      opacity: _subtitleOpacity.value,
                      child: Text(
                        'YOUR BODY. DECODED.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 3.5,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    const Spacer(flex: 4),
                    Opacity(
                      opacity: _ctaOpacity.value,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
                        child: TourPrimaryButton(
                          label: 'Begin',
                          onTap: widget.onNext,
                          color: AppColors.primary,
                          textColor: AppColors.textOnSageDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Opacity(
                      opacity: _ctaOpacity.value,
                      child: Text(
                        'No account needed.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark({required this.breathe});

  final double breathe;

  @override
  Widget build(BuildContext context) {
    final scale = 1.0 + breathe * 0.04;
    return Transform.scale(
      scale: scale,
      child: SizedBox(
        width: 120,
        height: 120,
        child: CustomPaint(painter: _LogoMarkPainter()),
      ),
    );
  }
}

class _LogoMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final radii = [44.0, 32.0, 20.0, 8.0];
    final opacities = [0.3, 0.5, 0.7, 0.95];

    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(cx, cy),
        radii[i],
        Paint()
          ..color = AppColors.primary.withValues(alpha: opacities[i])
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }

    canvas.drawCircle(
      Offset(cx, cy),
      radii[3],
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.95)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_LogoMarkPainter old) => false;
}

// ── Promise screen ────────────────────────────────────────────────────────────

class TourPromiseScreen extends StatelessWidget {
  const TourPromiseScreen({
    super.key,
    required this.index,
    required this.total,
    required this.title,
    required this.body,
    required this.progress,
    required this.accent,
    required this.onNext,
  });

  final int index;
  final int total;
  final String title;
  final String body;
  final double progress;
  final Color accent;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return TourScreen(
      topo: true,
      topoColor: accent,
      topoSeed: 'promise-$index',
      topoOpacity: 0.2,
      topoDensity: 12,
      child: Stack(
        children: [
          TourProgressBar(progress: progress, color: accent),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 120),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 150),
                    child: Text(
                      '$index / $total',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 4,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 300),
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 40,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -1.4,
                        height: 1.05,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 650),
                    child: Text(
                      body,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 17,
                        letterSpacing: -0.2,
                        height: 1.55,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Center(
                    child: _PromiseVisual(index: index, accent: accent),
                  ),
                  const Spacer(),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 1200),
                    child: TourPrimaryButton(
                      label: 'Continue',
                      onTap: onNext,
                      color: accent,
                      textColor: AppColors.textOnSageDark,
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromiseVisual extends StatefulWidget {
  const _PromiseVisual({required this.index, required this.accent});

  final int index;
  final Color accent;

  @override
  State<_PromiseVisual> createState() => _PromiseVisualState();
}

class _PromiseVisualState extends State<_PromiseVisual>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
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
        return switch (widget.index) {
          1 => _PillarOrbsVisual(breathe: _ctrl.value),
          2 => _WaveformVisual(breathe: _ctrl.value),
          _ => _StackedCardsVisual(breathe: _ctrl.value),
        };
      },
    );
  }
}

class _PillarOrbsVisual extends StatelessWidget {
  const _PillarOrbsVisual({required this.breathe});

  final double breathe;

  @override
  Widget build(BuildContext context) {
    const pillarIds = ['heart', 'sleep', 'workout', 'nutrients'];
    const orbColors = [
      AppColors.categoryHeart,
      AppColors.categorySleep,
      AppColors.categoryActivity,
      AppColors.categoryNutrition,
    ];

    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ...List.generate(4, (i) {
            final angle = (i / 4) * math.pi * 2 - math.pi / 2;
            const radius = 74.0;
            final dx = math.cos(angle) * radius;
            final dy = math.sin(angle) * radius;
            return Positioned(
              left: 110 + dx - 20,
              top: 110 + dy - 20,
              child: CustomPaint(
                size: const Size(200, 200),
                painter: _OrbLinePainter(dx: dx, dy: dy, color: orbColors[i]),
              ),
            );
          }),
          ...List.generate(4, (i) {
            final angle = (i / 4) * math.pi * 2 - math.pi / 2;
            const radius = 74.0;
            final dx = math.cos(angle) * radius;
            final dy = math.sin(angle) * radius;
            final orbScale = 1.0 + (breathe * (0.04 + i * 0.01));
            return Positioned(
              left: 110 + dx - 24,
              top: 110 + dy - 24,
              child: Transform.scale(
                scale: orbScale,
                child: _PillarOrb(
                  pillar: pillarIds[i],
                  color: orbColors[i],
                ),
              ),
            );
          }),
          Transform.scale(
            scale: 1.0 + breathe * 0.06,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
              ),
              child: Center(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.canvas,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrbLinePainter extends CustomPainter {
  const _OrbLinePainter({
    required this.dx,
    required this.dy,
    required this.color,
  });

  final double dx;
  final double dy;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(20 - dx, 20 - dy),
      const Offset(20, 20),
      Paint()
        ..color = color.withValues(alpha: 0.2)
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(_OrbLinePainter old) => false;
}

class _PillarOrb extends StatelessWidget {
  const _PillarOrb({required this.pillar, required this.color});

  final String pillar;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: PillarIcon(pillar: pillar, size: 22, color: color),
      ),
    );
  }
}

class _WaveformVisual extends StatelessWidget {
  const _WaveformVisual({required this.breathe});

  final double breathe;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(240, 100),
            painter: _WaveformPainter(breathe: breathe),
          ),
          Transform.scale(
            scale: 1.0 + breathe * 0.12,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          Transform.scale(
            scale: 1.0 + breathe * 0.28,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.08),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({required this.breathe});

  final double breathe;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final opacities = [0.15, 0.25, 0.4, 0.6];
    final ampFactors = [0.4, 0.6, 0.8, 1.0];
    final phaseOffsets = [0.0, 0.4, 0.8, 1.2];

    for (int w = 0; w < 4; w++) {
      final path = Path();
      final amp = 22.0 * ampFactors[w] * (1.0 + breathe * 0.1);
      final phase = phaseOffsets[w] + breathe * 0.5;

      path.moveTo(0, cy);
      for (double x = 0; x <= size.width; x++) {
        final y = cy + math.sin((x / size.width) * math.pi * 4 + phase) * amp;
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.primary.withValues(alpha: opacities[w])
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) => old.breathe != breathe;
}

class _StackedCardsVisual extends StatelessWidget {
  const _StackedCardsVisual({required this.breathe});

  final double breathe;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 170,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: -0.035,
            child: _GlassCard(
              opacity: 0.4 + breathe * 0.04,
              child: const SizedBox(width: 240, height: 130),
            ),
          ),
          Transform.rotate(
            angle: 0.035,
            child: _GlassCard(
              opacity: 0.5 + breathe * 0.04,
              child: const SizedBox(width: 240, height: 130),
            ),
          ),
          _GlassCard(
            opacity: 0.9,
            child: SizedBox(
              width: 240,
              height: 130,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today, for you',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'A lighter dinner tonight',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.4,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "You've hit your protein target. Something leafy helps sleep.",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        height: 1.4,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        TourChip(
                          label: 'Nutrients',
                          color: AppColors.categoryNutrition,
                        ),
                        const SizedBox(width: 8),
                        TourChip(
                          label: 'Sleep',
                          color: AppColors.categorySleep,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, required this.opacity});

  final Widget child;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacity * 0.055),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: opacity * 0.12),
          width: 0.8,
        ),
      ),
      child: child,
    );
  }
}

// ── Intent screen ─────────────────────────────────────────────────────────────

class TourIntentScreen extends StatelessWidget {
  const TourIntentScreen({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.progress,
    required this.onNext,
  });

  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final double progress;
  final VoidCallback onNext;

  void _toggle(String id) {
    final next = List<String>.from(selected);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final pillarOrder = ['heart', 'sleep', 'workout', 'nutrients', 'journal', 'water'];

    return TourScreen(
      topo: true,
      topoColor: AppColors.primary,
      topoSeed: 'intent',
      topoOpacity: 0.14,
      topoDensity: 14,
      child: Stack(
        children: [
          TourProgressBar(progress: progress),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(28, 110, 28, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RevealAnimation(
                          delay: const Duration(milliseconds: 100),
                          child: Text(
                            'STEP 1 OF 2',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2.5,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        RevealAnimation(
                          delay: const Duration(milliseconds: 220),
                          child: const Text(
                            'What do you want to focus on?',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 32,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -1,
                              height: 1.1,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        RevealAnimation(
                          delay: const Duration(milliseconds: 400),
                          child: Text(
                            'Pick as many as you want. We will tailor the tour to what matters to you.',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 15,
                              height: 1.45,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  sliver: SliverGrid.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      mainAxisExtent: 132,
                    ),
                    itemCount: pillarOrder.length,
                    itemBuilder: (context, i) {
                      final id = pillarOrder[i];
                      final info = kPillars[id]!;
                      final isSelected = selected.contains(id);
                      return RevealAnimation(
                        delay: Duration(milliseconds: 500 + i * 60),
                        child: _IntentTile(
                          info: info,
                          selected: isSelected,
                          onTap: () => _toggle(id),
                        ),
                      );
                    },
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 48),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      children: [
                        TourPrimaryButton(
                          label: selected.isEmpty
                              ? 'Pick at least one'
                              : '${selected.length} selected. Continue',
                          onTap: selected.isEmpty ? null : onNext,
                          disabled: selected.isEmpty,
                          color: AppColors.primary,
                          textColor: AppColors.textOnSageDark,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'You can change this later.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IntentTile extends StatelessWidget {
  const _IntentTile({
    required this.info,
    required this.selected,
    required this.onTap,
  });

  final PillarInfo info;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: selected
                ? info.color.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? info.color.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.1),
              width: selected ? 1.2 : 0.5,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: info.color.withValues(alpha: 0.18),
                      blurRadius: 16,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.all(14),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: info.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: PillarIcon(
                        pillar: info.id,
                        size: 20,
                        color: info.color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    info.name,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    info.subtitle,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              Positioned(
                top: 0,
                right: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? info.color : Colors.transparent,
                    border: Border.all(
                      color: selected
                          ? info.color
                          : Colors.white.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check,
                          size: 13,
                          color: Colors.white,
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
