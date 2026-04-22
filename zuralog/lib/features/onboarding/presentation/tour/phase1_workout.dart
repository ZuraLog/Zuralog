library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import './tour_widgets.dart';

// ── Exercise row ──────────────────────────────────────────────────────────────

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({
    required this.index,
    required this.name,
    required this.sets,
    required this.reps,
    required this.weight,
    required this.isActive,
    required this.delay,
    required this.color,
  });
  final int index;
  final String name;
  final int sets;
  final int reps;
  final String weight;
  final bool isActive;
  final Duration delay;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return RevealAnimation(
      delay: delay,
      offsetY: 12,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive
                ? color.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.07),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isActive
                    ? color
                    : Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isActive ? AppColors.canvas : Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$sets x $reps  |  $weight',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 8),
              Row(
                children: List.generate(sets, (i) {
                  return Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      color: i == 0
                          ? color
                          : color.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Workout screens ───────────────────────────────────────────────────────────

class WorkoutScreen1 extends StatelessWidget {
  const WorkoutScreen1({super.key, required this.onContinue, required this.progress});
  final VoidCallback onContinue;
  final double progress;

  static const Color _workout = AppColors.categoryActivity;

  static const List<_ExerciseData> _exercises = [
    _ExerciseData('Bench press', 4, 8, '145 lb', true),
    _ExerciseData('Overhead press', 3, 10, '95 lb', false),
    _ExerciseData('Incline DB press', 3, 12, '40 lb', false),
    _ExerciseData('Cable fly', 3, 15, '30 lb', false),
    _ExerciseData('Tricep pushdown', 4, 12, '50 lb', false),
  ];

  @override
  Widget build(BuildContext context) {
    return TourScreen(
      bg: AppColors.canvas,
      topo: true,
      topoColor: _workout,
      topoOpacity: 0.12,
      topoSeed: 'workout-1',
      child: SafeArea(
        child: Column(
          children: [
            TourProgressBar(progress: progress, color: _workout),
            TourAppHeader(title: "Today's session"),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RevealAnimation(
                      delay: const Duration(milliseconds: 80),
                      child: Text(
                        'UPPER PUSH',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.0,
                          color: _workout,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    RevealAnimation(
                      delay: const Duration(milliseconds: 160),
                      child: const Text(
                        'Ready when you are.',
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
                    ...List.generate(_exercises.length, (i) {
                      final e = _exercises[i];
                      return _ExerciseRow(
                        index: i,
                        name: e.name,
                        sets: e.sets,
                        reps: e.reps,
                        weight: e.weight,
                        isActive: e.isActive,
                        color: _workout,
                        delay: Duration(milliseconds: 240 + i * 80),
                      );
                    }),
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
                color: _workout,
                textColor: AppColors.canvas,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseData {
  const _ExerciseData(this.name, this.sets, this.reps, this.weight, this.isActive);
  final String name;
  final int sets;
  final int reps;
  final String weight;
  final bool isActive;
}

// ── Screen 2: Log your set (interactive) ─────────────────────────────────────

class WorkoutScreen2 extends StatefulWidget {
  const WorkoutScreen2({super.key, required this.onContinue, required this.progress});
  final VoidCallback onContinue;
  final double progress;

  @override
  State<WorkoutScreen2> createState() => _WorkoutScreen2State();
}

class _WorkoutScreen2State extends State<WorkoutScreen2> {
  int _reps = 0;

  static const Color _workout = AppColors.categoryActivity;

  void _increment() => setState(() => _reps++);
  void _decrement() => setState(() {
    if (_reps > 0) _reps--;
  });

  @override
  Widget build(BuildContext context) {
    final bool hasReps = _reps > 0;
    final bool isGood = _reps >= 8;

    return TourScreen(
      bg: AppColors.canvas,
      topo: true,
      topoColor: _workout,
      topoOpacity: 0.10,
      topoSeed: 'workout-2',
      child: SafeArea(
        child: Column(
          children: [
            TourProgressBar(progress: widget.progress, color: _workout),
            TourAppHeader(title: 'Bench press. Set 1'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LOG YOUR SET  |  TRY TAPPING',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.0,
                        color: _workout,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '145 lb. Target 8 reps.',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                        color: Colors.white,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Center(
                      child: Text(
                        'REPS COMPLETED',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 3.0,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 120,
                          fontWeight: FontWeight.w200,
                          letterSpacing: -6,
                          color: hasReps ? _workout : Colors.white,
                        ),
                        child: Text('$_reps'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: _decrement,
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.06),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                                width: 0.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '-',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 26,
                                fontWeight: FontWeight.w300,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        GestureDetector(
                          onTap: _increment,
                          child: Container(
                            width: 120,
                            height: 60,
                            decoration: BoxDecoration(
                              color: _workout,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '+ Tap',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.canvas,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        key: ValueKey(isGood),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: _workout.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _workout.withValues(alpha: 0.2),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          isGood
                              ? 'Nice set. We will tune your next workout based on how that felt.'
                              : 'Tap the green button as you rep. Or let your watch count automatically.',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13,
                            height: 1.55,
                            color: Colors.white.withValues(alpha: 0.82),
                          ),
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
                label: _reps > 0 ? 'Log $_reps reps. Continue' : 'Continue',
                onTap: widget.onContinue,
                color: _workout,
                textColor: AppColors.canvas,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Screen 3: Progression ─────────────────────────────────────────────────────

class WorkoutScreen3 extends StatelessWidget {
  const WorkoutScreen3({super.key, required this.onContinue, required this.progress});
  final VoidCallback onContinue;
  final double progress;

  static const Color _workout = AppColors.categoryActivity;

  static const List<double> _chartPoints = [
    120, 125, 125, 130, 130, 135, 135, 140, 140, 142, 145, 145
  ];

  static const List<String> _chartLabels = [
    'Jan', '', 'Feb', '', 'Mar', '', 'Apr'
  ];

  @override
  Widget build(BuildContext context) {
    return TourScreen(
      bg: AppColors.canvas,
      topo: true,
      topoColor: _workout,
      topoOpacity: 0.10,
      topoSeed: 'workout-3',
      child: SafeArea(
        child: Column(
          children: [
            TourProgressBar(progress: progress, color: _workout),
            TourAppHeader(title: 'Progression'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RevealAnimation(
                      delay: const Duration(milliseconds: 80),
                      child: Text(
                        'BENCH  |  LAST 12 WEEKS',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.0,
                          color: _workout,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    RevealAnimation(
                      delay: const Duration(milliseconds: 160),
                      child: const Text(
                        'You have added 25 lb since January.',
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
                        color: _workout,
                        child: TourLineChart(
                          points: _chartPoints,
                          color: _workout,
                          labels: _chartLabels,
                          height: 140,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    RevealAnimation(
                      delay: const Duration(milliseconds: 400),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: _workout.withValues(alpha: 0.09),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _workout.withValues(alpha: 0.22),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          'Next milestone: you are 5 lb from 150. We will adjust your volume next week.',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 13,
                            height: 1.55,
                            color: Colors.white.withValues(alpha: 0.82),
                          ),
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
                color: _workout,
                textColor: AppColors.canvas,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Screen 4: Weekly load ─────────────────────────────────────────────────────

class _WeeklyStatChip extends StatelessWidget {
  const _WeeklyStatChip({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}

class WorkoutScreen4 extends StatelessWidget {
  const WorkoutScreen4({super.key, required this.onContinue, required this.progress});
  final VoidCallback onContinue;
  final double progress;

  static const Color _workout = AppColors.categoryActivity;

  static const List<double> _bars = [0.7, 0.0, 0.85, 0.5, 0.65, 0.0, 0.3];
  static const List<String> _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    return TourScreen(
      bg: AppColors.canvas,
      topo: true,
      topoColor: _workout,
      topoOpacity: 0.10,
      topoSeed: 'workout-4',
      child: SafeArea(
        child: Column(
          children: [
            TourProgressBar(progress: progress, color: _workout),
            TourAppHeader(title: 'Weekly load'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RevealAnimation(
                      delay: const Duration(milliseconds: 80),
                      child: Text(
                        'THIS WEEK  |  ON TRACK',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.0,
                          color: _workout,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    RevealAnimation(
                      delay: const Duration(milliseconds: 160),
                      child: const Text(
                        '4 sessions. 3 hours 18 minutes trained.',
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
                        color: _workout,
                        child: Column(
                          children: [
                            TourBarChart(
                              bars: _bars,
                              color: _workout,
                              labels: _labels,
                              height: 120,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: const [
                                _WeeklyStatChip(value: '4 sessions', label: 'This week'),
                                _WeeklyStatChip(value: '3h 18m', label: 'Total time'),
                                _WeeklyStatChip(value: '14,200 cal', label: 'Calories'),
                              ],
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
                color: _workout,
                textColor: AppColors.canvas,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
