library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import './tour_widgets.dart';

// ── Sleep stage chart painter ─────────────────────────────────────────────────

class _SleepStagePainter extends CustomPainter {
  _SleepStagePainter({
    required this.data,
    required this.color,
    required this.progress,
  });

  final List<int> data;
  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const levels = 4;
    const topPad = 8.0;
    const bottomPad = 8.0;
    final chartH = size.height - topPad - bottomPad;
    final stepW = size.width / data.length;

    double yForLevel(int level) {
      final norm = (levels - 1 - level) / (levels - 1);
      return topPad + norm * chartH;
    }

    final totalPoints = data.length;
    final visibleCount = (totalPoints * progress).ceil().clamp(1, totalPoints);

    final path = Path();
    path.moveTo(0, yForLevel(data[0]));
    for (int i = 0; i < visibleCount; i++) {
      final x = i * stepW;
      final nextX = (i + 1) * stepW;
      final y = yForLevel(data[i]);
      path.lineTo(x, y);
      if (i < visibleCount - 1) {
        path.lineTo(nextX, y);
      }
    }

    final lastX = (visibleCount - 1) * stepW + stepW * (progress * totalPoints - (visibleCount - 1)).clamp(0.0, 1.0);
    final lastY = yForLevel(data[visibleCount - 1]);
    path.lineTo(lastX, lastY);

    final fillPath = Path.from(path);
    fillPath.lineTo(lastX, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.28),
            color.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SleepStagePainter old) =>
      old.progress != progress || old.color != color;
}

class _SleepStageChart extends StatefulWidget {
  const _SleepStageChart({required this.color});
  final Color color;

  @override
  State<_SleepStageChart> createState() => _SleepStageChartState();
}

class _SleepStageChartState extends State<_SleepStageChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _progress;

  static const List<int> _data = [
    1, 1, 0, 0, 0, 1, 2, 1, 0, 1, 2, 2, 1, 1, 0, 0, 1, 2, 2, 1, 1, 3, 1, 2
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _progress = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
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
        size: const Size(double.infinity, 72),
        painter: _SleepStagePainter(
          data: _data,
          color: widget.color,
          progress: _progress.value,
        ),
      ),
    );
  }
}

// ── Legend row ────────────────────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label, required this.value});
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Insight box ───────────────────────────────────────────────────────────────

class _InsightBox extends StatelessWidget {
  const _InsightBox({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22), width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 13,
          fontWeight: FontWeight.w400,
          height: 1.55,
          color: Colors.white.withValues(alpha: 0.82),
        ),
      ),
    );
  }
}

// ── Mini stat card ────────────────────────────────────────────────────────────

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.title,
    required this.value,
    required this.sub,
  });
  final String title;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            sub,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Wind-down step ────────────────────────────────────────────────────────────

class _WindDownStep extends StatelessWidget {
  const _WindDownStep({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.delay,
  });
  final int number;
  final String title;
  final String subtitle;
  final Color color;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return RevealAnimation(
      delay: delay,
      offsetY: 14,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '$number',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Heatmap ───────────────────────────────────────────────────────────────────

class _SleepHeatmap extends StatelessWidget {
  const _SleepHeatmap({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(5, (row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(7, (col) {
              final idx = row * 7 + col;
              final t = math.sin(idx * 0.72 + row * 1.1) * 0.5 + 0.5;
              final opacity = 0.12 + t * 0.75;
              return Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(6),
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}

// ── Screen 1: Last night's sleep ──────────────────────────────────────────────

class SleepScreen1 extends StatelessWidget {
  const SleepScreen1({super.key, required this.onContinue, required this.progress});
  final VoidCallback onContinue;
  final double progress;

  static const Color _sleep = AppColors.categorySleep;
  static const Color _rem = Color(0xFF8B8BFF);

  @override
  Widget build(BuildContext context) {
    return TourScreen(
      bg: AppColors.canvas,
      topo: true,
      topoColor: _sleep,
      topoOpacity: 0.12,
      topoSeed: 'sleep-1',
      child: SafeArea(
        child: Column(
          children: [
            TourProgressBar(progress: progress, color: _sleep),
            TourAppHeader(title: 'Sleep'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RevealAnimation(
                      delay: const Duration(milliseconds: 80),
                      child: Text(
                        'LAST NIGHT',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.0,
                          color: _sleep,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    RevealAnimation(
                      delay: const Duration(milliseconds: 160),
                      child: const Text(
                        '7h 42m of restful sleep.',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.8,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    RevealAnimation(
                      delay: const Duration(milliseconds: 280),
                      child: TourStatCard(
                        color: _sleep,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SLEEP STAGES  |  11:32PM TO 7:14AM',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.0,
                                color: _sleep.withValues(alpha: 0.75),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _SleepStageChart(color: _sleep),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _LegendDot(
                                  color: _sleep,
                                  label: 'DEEP',
                                  value: '1h 32m',
                                ),
                                _LegendDot(
                                  color: _rem,
                                  label: 'REM',
                                  value: '2h 04m',
                                ),
                                _LegendDot(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  label: 'LIGHT',
                                  value: '3h 58m',
                                ),
                                _LegendDot(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  label: 'AWAKE',
                                  value: '8m',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    RevealAnimation(
                      delay: const Duration(milliseconds: 400),
                      child: _InsightBox(
                        color: _sleep,
                        text:
                            'Quiet night. Your deep sleep was 12% above your average. That is your body repairing.',
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: TourPrimaryButton(
                label: 'Continue',
                onTap: onContinue,
                color: _sleep,
                textColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Screen 2: Sleep score ─────────────────────────────────────────────────────

class SleepScreen2 extends StatelessWidget {
  const SleepScreen2({super.key, required this.onContinue, required this.progress});
  final VoidCallback onContinue;
  final double progress;

  static const Color _sleep = AppColors.categorySleep;

  @override
  Widget build(BuildContext context) {
    return TourScreen(
      bg: AppColors.canvas,
      topo: true,
      topoColor: _sleep,
      topoOpacity: 0.10,
      topoSeed: 'sleep-2',
      child: SafeArea(
        child: Column(
          children: [
            TourProgressBar(progress: progress, color: _sleep),
            TourAppHeader(title: 'Sleep'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RevealAnimation(
                      delay: const Duration(milliseconds: 80),
                      child: Text(
                        'SLEEP SCORE',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.0,
                          color: _sleep,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    RevealAnimation(
                      delay: const Duration(milliseconds: 160),
                      child: RichText(
                        text: TextSpan(
                          children: [
                            const TextSpan(
                              text: '88',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.8,
                                color: Colors.white,
                              ),
                            ),
                            TextSpan(
                              text: ' / 100',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.8,
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    RevealAnimation(
                      delay: const Duration(milliseconds: 260),
                      child: GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.55,
                        children: const [
                          _MiniStatCard(
                            title: 'EFFICIENCY',
                            value: '94%',
                            sub: 'Time asleep vs in bed',
                          ),
                          _MiniStatCard(
                            title: 'TIME ASLEEP',
                            value: '7h 42m',
                            sub: 'Target 7h 30m',
                          ),
                          _MiniStatCard(
                            title: 'RESTFULNESS',
                            value: 'High',
                            sub: '3 mild disturbances',
                          ),
                          _MiniStatCard(
                            title: 'HEART DIP',
                            value: 'Down 18%',
                            sub: 'Deep recovery',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    RevealAnimation(
                      delay: const Duration(milliseconds: 400),
                      child: _InsightBox(
                        color: _sleep,
                        text:
                            'Tonight: head to bed by 10:48pm to hit 88+ again.',
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: TourPrimaryButton(
                label: 'Continue',
                onTap: onContinue,
                color: _sleep,
                textColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Screen 3: Wind-down ───────────────────────────────────────────────────────

class SleepScreen3 extends StatelessWidget {
  const SleepScreen3({super.key, required this.onContinue, required this.progress});
  final VoidCallback onContinue;
  final double progress;

  static const Color _sleep = AppColors.categorySleep;

  @override
  Widget build(BuildContext context) {
    return TourScreen(
      bg: AppColors.canvas,
      topo: true,
      topoColor: _sleep,
      topoOpacity: 0.18,
      topoDensity: 18,
      topoSeed: 'sleep-3',
      child: SafeArea(
        child: Column(
          children: [
            TourProgressBar(progress: progress, color: _sleep),
            TourAppHeader(title: 'Wind down'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RevealAnimation(
                      delay: const Duration(milliseconds: 80),
                      child: Text(
                        'TONIGHT AT 10:30PM',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.0,
                          color: _sleep,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    RevealAnimation(
                      delay: const Duration(milliseconds: 160),
                      child: const Text(
                        'We will help your body get ready for sleep.',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.7,
                          color: Colors.white,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _WindDownStep(
                      number: 1,
                      title: 'Dim the lights',
                      subtitle: '10:30pm. 60 min before bed',
                      color: _sleep,
                      delay: const Duration(milliseconds: 280),
                    ),
                    _WindDownStep(
                      number: 2,
                      title: 'Breathing reset',
                      subtitle: '4-7-8 breathing. 3 min',
                      color: _sleep,
                      delay: const Duration(milliseconds: 360),
                    ),
                    _WindDownStep(
                      number: 3,
                      title: 'Device night mode',
                      subtitle: 'Blue light filtered',
                      color: _sleep,
                      delay: const Duration(milliseconds: 440),
                    ),
                    _WindDownStep(
                      number: 4,
                      title: 'Gentle wake at 6:45am',
                      subtitle: 'Light sleep stage alarm',
                      color: _sleep,
                      delay: const Duration(milliseconds: 520),
                    ),
                    const SizedBox(height: 10),
                    RevealAnimation(
                      delay: const Duration(milliseconds: 620),
                      child: Text(
                        'You set the time. We send the nudge.',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: TourPrimaryButton(
                label: 'Continue',
                onTap: onContinue,
                color: _sleep,
                textColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Screen 4: Sleep patterns ──────────────────────────────────────────────────

class SleepScreen4 extends StatelessWidget {
  const SleepScreen4({super.key, required this.onContinue, required this.progress});
  final VoidCallback onContinue;
  final double progress;

  static const Color _sleep = AppColors.categorySleep;

  @override
  Widget build(BuildContext context) {
    return TourScreen(
      bg: AppColors.canvas,
      topo: true,
      topoColor: _sleep,
      topoOpacity: 0.14,
      topoSeed: 'sleep-4',
      child: SafeArea(
        child: Column(
          children: [
            TourProgressBar(progress: progress, color: _sleep),
            TourAppHeader(title: 'Sleep patterns'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RevealAnimation(
                      delay: const Duration(milliseconds: 80),
                      child: Text(
                        'PATTERN  |  30 DAYS',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.0,
                          color: _sleep,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    RevealAnimation(
                      delay: const Duration(milliseconds: 160),
                      child: const Text(
                        'You sleep best on active days.',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.7,
                          color: Colors.white,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    RevealAnimation(
                      delay: const Duration(milliseconds: 280),
                      child: TourStatCard(
                        color: _sleep,
                        child: Column(
                          children: [
                            _SleepHeatmap(color: _sleep),
                            const SizedBox(height: 14),
                            Text(
                              'On days you trained, you slept 47 minutes longer on average. Your deep sleep nearly doubled.',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 13,
                                height: 1.5,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: TourPrimaryButton(
                label: 'Continue',
                onTap: onContinue,
                color: _sleep,
                textColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
