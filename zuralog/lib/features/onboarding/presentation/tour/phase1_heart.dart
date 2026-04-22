library;

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import './tour_widgets.dart';

// ── Chapter hero ──────────────────────────────────────────────────────────────

class TourChapterHero extends StatelessWidget {
  const TourChapterHero({
    super.key,
    required this.pillar,
    required this.title,
    required this.subtitle,
    required this.chapterNum,
    required this.chapterTotal,
    required this.progress,
    required this.onNext,
  });

  final String pillar;
  final String title;
  final String subtitle;
  final int chapterNum;
  final int chapterTotal;
  final double progress;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final pillarInfo = kPillars[pillar]!;
    final pillarColor = pillarInfo.color;

    return TourScreen(
      bg: pillarColor,
      topo: true,
      topoColor: Colors.black,
      topoSeed: 'hero-$pillar',
      topoOpacity: 0.45,
      topoDensity: 22,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    pillarColor.withValues(alpha: 0.67),
                  ],
                ),
              ),
            ),
          ),
          TourProgressBar(
            progress: progress,
            color: Colors.white.withValues(alpha: 0.85),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 96),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 200),
                    child: Text(
                      'CHAPTER $chapterNum OF $chapterTotal',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.5,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                  const Spacer(flex: 2),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 350),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                          width: 0.8,
                        ),
                      ),
                      child: PillarIcon(
                        pillar: pillar,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 550),
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 56,
                        fontWeight: FontWeight.w300,
                        letterSpacing: -2.5,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 850),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Text(
                        subtitle,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 18,
                          height: 1.45,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 3),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 1100),
                    child: GestureDetector(
                      onTap: onNext,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 18,
                          horizontal: 24,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          'Explore ${pillarInfo.name} →',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color: Colors.white,
                          ),
                        ),
                      ),
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

// ── Heart screen 1: resting BPM ───────────────────────────────────────────────

class HeartScreen1 extends StatefulWidget {
  const HeartScreen1({
    super.key,
    required this.progress,
    required this.onNext,
  });

  final double progress;
  final VoidCallback onNext;

  @override
  State<HeartScreen1> createState() => _HeartScreen1State();
}

class _HeartScreen1State extends State<HeartScreen1>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  Timer? _bpmTimer;
  int _bpm = 62;

  final _bpmValues = [58, 60, 62, 64, 63, 61, 58, 60, 65, 63, 62, 60];
  int _bpmIndex = 0;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _bpmTimer = Timer.periodic(const Duration(milliseconds: 1100), (_) {
      if (!mounted) return;
      setState(() {
        _bpmIndex = (_bpmIndex + 1) % _bpmValues.length;
        _bpm = _bpmValues[_bpmIndex];
      });
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _bpmTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TourScreen(
      topo: true,
      topoColor: AppColors.categoryHeart,
      topoSeed: 'heart-1',
      topoOpacity: 0.12,
      topoDensity: 14,
      child: Stack(
        children: [
          TourProgressBar(
            progress: widget.progress,
            color: AppColors.categoryHeart,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TourAppHeader(title: 'Heart'),
                  const SizedBox(height: 24),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 100),
                    child: Text(
                      'RIGHT NOW',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.5,
                        color: AppColors.categoryHeart,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 220),
                    child: const Text(
                      'Your heart is resting.',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.8,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: _BpmDisplay(
                      pulseCtrl: _pulseCtrl,
                      bpm: _bpm,
                    ),
                  ),
                  const SizedBox(height: 32),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 500),
                    child: Text(
                      'We watch your heart rate and recovery in the background. You will see patterns you never noticed before.',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 15,
                        height: 1.55,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  const Spacer(),
                  TourPrimaryButton(
                    label: 'Continue',
                    onTap: widget.onNext,
                    color: AppColors.categoryHeart,
                    textColor: Colors.white,
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

class _BpmDisplay extends StatelessWidget {
  const _BpmDisplay({
    required this.pulseCtrl,
    required this.bpm,
  });

  final AnimationController pulseCtrl;
  final int bpm;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ...List.generate(3, (i) {
            final delayFraction = i / 3;
            return AnimatedBuilder(
              animation: pulseCtrl,
              builder: (_, __) {
                final t = ((pulseCtrl.value + delayFraction) % 1.0);
                final scale = 0.6 + t * 0.9;
                final opacity = (1.0 - t).clamp(0.0, 0.38);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.categoryHeart.withValues(alpha: opacity),
                    ),
                  ),
                );
              },
            );
          }),
          AnimatedBuilder(
            animation: pulseCtrl,
            builder: (_, __) {
              final breathe = math.sin(pulseCtrl.value * math.pi * 2) * 0.5 + 0.5;
              return Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.categoryHeart.withValues(alpha: 0.9 + breathe * 0.1),
                      AppColors.categoryHeart.withValues(alpha: 0.55),
                    ],
                  ),
                ),
              );
            },
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  '$bpm',
                  key: ValueKey<int>(bpm),
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 72,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -2,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
              ),
              Text(
                'BPM',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Heart screen 2: 7-day trend ───────────────────────────────────────────────

class HeartScreen2 extends StatelessWidget {
  const HeartScreen2({
    super.key,
    required this.progress,
    required this.onNext,
  });

  final double progress;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return TourScreen(
      topo: true,
      topoColor: AppColors.categoryHeart,
      topoSeed: 'heart-2',
      topoOpacity: 0.08,
      topoDensity: 14,
      child: Stack(
        children: [
          TourProgressBar(
            progress: progress,
            color: AppColors.categoryHeart,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TourAppHeader(title: 'Heart'),
                  const SizedBox(height: 24),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 100),
                    child: Text(
                      'LAST 7 DAYS',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.5,
                        color: AppColors.categoryHeart,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 220),
                    child: const Text(
                      'Your resting rate dropped 4 bpm.',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.6,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 400),
                    child: TourStatCard(
                      color: AppColors.categoryHeart,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'RESTING',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                '58',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 34,
                                  fontWeight: FontWeight.w300,
                                  letterSpacing: -1,
                                  color: Colors.white,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  'bpm',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 15,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              TourChip(
                                label: 'Down 4 bpm',
                                color: AppColors.categoryHeart,
                                filled: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TourLineChart(
                            points: [66, 64, 65, 63, 60, 59, 58],
                            color: AppColors.categoryHeart,
                            labels: ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
                            height: 130,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 700),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.categoryHeart.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.categoryHeart.withValues(alpha: 0.2),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.categoryHeart,
                            ),
                            child: Center(
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'Sleeping longer this week with consistent training. That is why your heart is resting easier.',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 14,
                                height: 1.5,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  TourPrimaryButton(
                    label: 'Continue',
                    onTap: onNext,
                    color: AppColors.categoryHeart,
                    textColor: Colors.white,
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

// ── Heart screen 3: HRV ───────────────────────────────────────────────────────

class HeartScreen3 extends StatefulWidget {
  const HeartScreen3({
    super.key,
    required this.progress,
    required this.onNext,
  });

  final double progress;
  final VoidCallback onNext;

  @override
  State<HeartScreen3> createState() => _HeartScreen3State();
}

class _HeartScreen3State extends State<HeartScreen3>
    with SingleTickerProviderStateMixin {
  late AnimationController _barCtrl;

  @override
  void initState() {
    super.initState();
    _barCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _barCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TourScreen(
      topo: true,
      topoColor: AppColors.categoryHeart,
      topoSeed: 'heart-3',
      topoOpacity: 0.1,
      topoDensity: 14,
      child: Stack(
        children: [
          TourProgressBar(
            progress: widget.progress,
            color: AppColors.categoryHeart,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TourAppHeader(title: 'Heart rate variability'),
                  const SizedBox(height: 24),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 100),
                    child: Text(
                      'HRV. LAST NIGHT',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.5,
                        color: AppColors.categoryHeart,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 220),
                    child: const Text(
                      'You recovered deeply.',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.8,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 350),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '62',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 88,
                            fontWeight: FontWeight.w200,
                            letterSpacing: -4,
                            color: AppColors.categoryHeart,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            'ms',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 20,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TourChip(
                            label: '+8 vs avg',
                            color: AppColors.categoryHeart,
                            filled: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 500),
                    child: SizedBox(
                      height: 72,
                      child: AnimatedBuilder(
                        animation: _barCtrl,
                        builder: (_, __) => _HrvBars(breathe: _barCtrl.value),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 700),
                    child: Row(
                      children: [
                        _HrvMiniStat(label: 'Avg', value: '54ms'),
                        const SizedBox(width: 10),
                        _HrvMiniStat(label: 'Peak', value: '74ms'),
                        const SizedBox(width: 10),
                        _HrvMiniStat(label: 'Low', value: '38ms'),
                      ],
                    ),
                  ),
                  const Spacer(),
                  TourPrimaryButton(
                    label: 'Continue',
                    onTap: widget.onNext,
                    color: AppColors.categoryHeart,
                    textColor: Colors.white,
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

class _HrvBars extends StatelessWidget {
  const _HrvBars({required this.breathe});

  final double breathe;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 72),
      painter: _HrvBarsPainter(breathe: breathe),
    );
  }
}

class _HrvBarsPainter extends CustomPainter {
  const _HrvBarsPainter({required this.breathe});

  final double breathe;

  @override
  void paint(Canvas canvas, Size size) {
    const barCount = 44;
    final barWidth = (size.width - (barCount - 1) * 2.0) / barCount;

    for (int i = 0; i < barCount; i++) {
      final phase = i / barCount * math.pi * 6;
      final base = (math.sin(phase) * 0.5 + 0.5);
      final breatheOffset = math.sin(breathe * math.pi * 2 + i * 0.3) * 0.08;
      final heightFactor = (base + breatheOffset).clamp(0.12, 1.0);
      final opacityFactor = (0.3 + heightFactor * 0.7).clamp(0.0, 1.0);

      final barH = heightFactor * size.height;
      final x = i * (barWidth + 2.0);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - barH, barWidth, barH),
          const Radius.circular(3),
        ),
        Paint()
          ..color = AppColors.categoryHeart.withValues(alpha: opacityFactor),
      );
    }
  }

  @override
  bool shouldRepaint(_HrvBarsPainter old) => old.breathe != breathe;
}

class _HrvMiniStat extends StatelessWidget {
  const _HrvMiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.5,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 18,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.5,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Heart screen 4: morning readiness ────────────────────────────────────────

class HeartScreen4 extends StatelessWidget {
  const HeartScreen4({
    super.key,
    required this.progress,
    required this.onNext,
  });

  final double progress;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return TourScreen(
      topo: true,
      topoColor: AppColors.categoryHeart,
      topoSeed: 'heart-4',
      topoOpacity: 0.1,
      topoDensity: 14,
      child: Stack(
        children: [
          TourProgressBar(
            progress: progress,
            color: AppColors.categoryHeart,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TourAppHeader(title: 'Today'),
                  const SizedBox(height: 24),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 100),
                    child: Text(
                      'THIS MORNING',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.5,
                        color: AppColors.categoryHeart,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 220),
                    child: const Text(
                      'You recovered well.',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.8,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 380),
                    child: _RecoveryCard(),
                  ),
                  const SizedBox(height: 14),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 600),
                    child: _QuickActionRow(),
                  ),
                  const Spacer(),
                  TourPrimaryButton(
                    label: 'Continue',
                    onTap: onNext,
                    color: AppColors.categoryHeart,
                    textColor: Colors.white,
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

class _EnergyCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.categoryHeart.withValues(alpha: 0.13),
                AppColors.categoryHeart.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.categoryHeart.withValues(alpha: 0.27),
              width: 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ENERGY SCORE',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  color: AppColors.categoryHeart,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '91',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 68,
                  fontWeight: FontWeight.w200,
                  letterSpacing: -3,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Your heart has recovered well. A good day to push yourself.',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.white.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: TopoBG(
              color: AppColors.categoryHeart,
              seed: 'energy-card',
              opacity: 0.25,
              density: 10,
              animate: false,
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickActionRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.categoryHeart.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: PillarIcon(
                pillar: 'workout',
                size: 22,
                color: AppColors.categoryHeart,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Start a workout',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Suggested. 32 min moderate',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: Colors.white.withValues(alpha: 0.35),
            size: 20,
          ),
        ],
      ),
    );
  }
}
