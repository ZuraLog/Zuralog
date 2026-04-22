library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import './tour_widgets.dart';

// ── ExtrasHeroScreen ──────────────────────────────────────────────────────────

class ExtrasHeroScreen extends StatelessWidget {
  const ExtrasHeroScreen({
    super.key,
    required this.chapterNum,
    required this.chapterTotal,
    required this.progress,
    required this.onNext,
  });

  final int chapterNum;
  final int chapterTotal;
  final double progress;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return TourScreen(
      bg: AppColors.primary,
      child: Stack(
        children: [
          TopoBG(
            color: const Color(0xFF2A3B1E),
            seed: 'extras-hero',
            opacity: 0.4,
            density: 22,
          ),
          TourProgressBar(
            progress: progress,
            color: AppColors.canvas,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 100),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 80),
                    child: Text(
                      'CHAPTER $chapterNum OF $chapterTotal',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.5,
                        color: AppColors.canvas.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.42 - 120),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 200),
                    child: const Text(
                      'And\na little more.',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 56,
                        fontWeight: FontWeight.w300,
                        letterSpacing: -2.5,
                        height: 1.0,
                        color: AppColors.canvas,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 400),
                    child: Text(
                      'The small rituals that round out a day: journaling, hydration, and the devices you already wear.',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 18,
                        height: 1.45,
                        color: AppColors.canvas.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                  const Spacer(),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 700),
                    child: TourPrimaryButton(
                      label: 'Explore extras',
                      onTap: onNext,
                      color: AppColors.canvas,
                      textColor: Colors.white,
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

// ── JournalScreen ─────────────────────────────────────────────────────────────

class JournalScreen extends StatelessWidget {
  const JournalScreen({
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
      topoColor: AppColors.primary,
      topoSeed: 'journal',
      topoOpacity: 0.10,
      child: Stack(
        children: [
          TourProgressBar(progress: progress, color: AppColors.primary),
          TourAppHeader(title: 'Journal'),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 116),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 80),
                    child: const Text(
                      "TODAY'S ENTRY. 8:14AM",
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.5,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 220),
                    child: const Text(
                      'A few lines, once a day.',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.9,
                        height: 1.1,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 360),
                    child: TourStatCard(
                      color: AppColors.primary,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Feeling steadier today. Slept well, ate well. Took a long walk before lunch and noticed how clear my head felt afterwards.',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 15,
                              fontStyle: FontStyle.italic,
                              height: 1.55,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              TourChip(label: 'Calm', color: AppColors.primary),
                              const SizedBox(width: 8),
                              TourChip(label: 'Energized', color: AppColors.categoryActivity),
                              const SizedBox(width: 8),
                              TourChip(label: 'Rested', color: AppColors.categorySleep),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 550),
                    child: Text(
                      'ZuraLog reads your journal over time to find patterns. No human ever sees it.',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        height: 1.5,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                  const Spacer(),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 900),
                    child: TourPrimaryButton(
                      label: 'Continue',
                      onTap: onNext,
                      color: AppColors.primary,
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

// ── WaterScreen ───────────────────────────────────────────────────────────────

class WaterScreen extends StatefulWidget {
  const WaterScreen({
    super.key,
    required this.progress,
    required this.onNext,
  });

  final double progress;
  final VoidCallback onNext;

  @override
  State<WaterScreen> createState() => _WaterScreenState();
}

class _WaterScreenState extends State<WaterScreen> {
  int _cups = 3;

  void _tapCup(int index) {
    setState(() {
      if (index < _cups) {
        _cups = index;
      } else {
        _cups = index + 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final remaining = 8 - _cups;
    final goalHit = _cups >= 8;

    return TourScreen(
      topo: true,
      topoColor: AppColors.categoryBody,
      topoSeed: 'water',
      topoOpacity: 0.10,
      child: Stack(
        children: [
          TourProgressBar(progress: widget.progress, color: AppColors.categoryBody),
          TourAppHeader(title: 'Water'),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 116),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 80),
                    child: Text(
                      'TODAY. TRY TAPPING',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.5,
                        color: AppColors.categoryBody,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 200),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: child,
                      ),
                      child: Text(
                        '$_cups of 8 glasses',
                        key: ValueKey(_cups),
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 28,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.9,
                          height: 1.1,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 320),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.7,
                      ),
                      itemCount: 8,
                      itemBuilder: (context, i) {
                        final filled = i < _cups;
                        return GestureDetector(
                          onTap: () => _tapCup(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                            decoration: BoxDecoration(
                              color: filled
                                  ? AppColors.categoryBody.withValues(alpha: 0.15)
                                  : Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: filled
                                    ? AppColors.categoryBody.withValues(alpha: 0.5)
                                    : Colors.white.withValues(alpha: 0.1),
                                width: 0.5,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Stack(
                                children: [
                                  if (filled)
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 300),
                                        height: double.infinity,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
                                            colors: [
                                              AppColors.categoryBody.withValues(alpha: 0.45),
                                              AppColors.categoryBody.withValues(alpha: 0.12),
                                            ],
                                            stops: const [0.0, 0.72],
                                          ),
                                        ),
                                      ),
                                    ),
                                  Center(
                                    child: Icon(
                                      Icons.water_drop_outlined,
                                      size: 22,
                                      color: filled
                                          ? AppColors.categoryBody
                                          : Colors.white.withValues(alpha: 0.2),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 500),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        key: ValueKey(goalHit),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.categoryBody.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.categoryBody.withValues(alpha: 0.2),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              goalHit ? Icons.check_circle_outline : Icons.water_drop_outlined,
                              color: AppColors.categoryBody,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                goalHit
                                    ? 'Goal hit. Your kidneys thank you.'
                                    : '$remaining to go. You are building a great habit.',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 800),
                    child: TourPrimaryButton(
                      label: 'Continue',
                      onTap: widget.onNext,
                      color: AppColors.categoryBody,
                      textColor: AppColors.canvas,
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

// ── ComingSoonScreen ──────────────────────────────────────────────────────────

class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({
    super.key,
    required this.progress,
    required this.onNext,
  });

  final double progress;
  final VoidCallback onNext;

  static const _integrations = [
    _IntegrationItem(
      name: 'Apple Health',
      status: 'Available at launch',
      available: true,
    ),
    _IntegrationItem(
      name: 'Health Connect (Android)',
      status: 'Available at launch',
      available: true,
    ),
    _IntegrationItem(
      name: 'Oura Ring',
      status: 'Coming this summer',
      available: false,
    ),
    _IntegrationItem(
      name: 'Whoop',
      status: 'Coming this summer',
      available: false,
    ),
    _IntegrationItem(
      name: 'Garmin',
      status: 'Later in 2026',
      available: false,
    ),
    _IntegrationItem(
      name: 'Continuous glucose (Dexcom, Libre)',
      status: 'In research',
      available: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return TourScreen(
      topo: true,
      topoColor: AppColors.primary,
      topoSeed: 'soon',
      topoOpacity: 0.08,
      child: Stack(
        children: [
          TourProgressBar(progress: progress, color: AppColors.primary),
          TourAppHeader(title: 'Connections'),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 116),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 80),
                    child: const Text(
                      'SOON',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.5,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 200),
                    child: const Text(
                      'Your devices, talking to each other.',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 26,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.9,
                        height: 1.1,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _integrations.length,
                      itemBuilder: (context, i) {
                        final item = _integrations[i];
                        return RevealAnimation(
                          delay: Duration(milliseconds: 320 + i * 70),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _IntegrationRow(item: item),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 800),
                    child: TourPrimaryButton(
                      label: 'Continue',
                      onTap: onNext,
                      color: AppColors.primary,
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

class _IntegrationItem {
  const _IntegrationItem({
    required this.name,
    required this.status,
    required this.available,
  });

  final String name;
  final String status;
  final bool available;
}

class _IntegrationRow extends StatelessWidget {
  const _IntegrationRow({required this.item});

  final _IntegrationItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.available
                  ? AppColors.primary
                  : Colors.white.withValues(alpha: 0.2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.status,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.45),
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

// ── SummaryScreen ─────────────────────────────────────────────────────────────

class SummaryScreen extends StatelessWidget {
  const SummaryScreen({
    super.key,
    required this.progress,
    required this.selectedPillars,
    required this.onNext,
  });

  final double progress;
  final List<String> selectedPillars;
  final VoidCallback onNext;

  static const _pillarOrder = [
    'heart',
    'sleep',
    'workout',
    'nutrients',
    'journal',
    'water',
  ];

  static const _pillarDescriptions = <String, String>{
    'heart':     'Resting rate, HRV, readiness',
    'sleep':     'Stages, efficiency, wind-down',
    'workout':   'Strength, cardio, progression',
    'nutrients': 'AI food parse, barcode, macros',
    'journal':   'Reflections with AI',
    'water':     'Hydration nudges',
  };

  @override
  Widget build(BuildContext context) {
    final count = selectedPillars.length;
    final subtext = count == _pillarOrder.length
        ? 'All of it, whenever you need it.'
        : '$count focused. We will surface the rest when you are ready.';

    return TourScreen(
      topo: true,
      topoColor: AppColors.primary,
      topoSeed: 'summary',
      topoOpacity: 0.15,
      topoDensity: 18,
      child: Stack(
        children: [
          TourProgressBar(progress: progress, color: AppColors.primary),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 92),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 80),
                    child: const Text(
                      'HERE IS WHAT ZURALOG DOES FOR YOU',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.0,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 200),
                    child: const Text(
                      'One app. All of it.',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 34,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -1.2,
                        height: 1.08,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _pillarOrder.length,
                      itemBuilder: (context, i) {
                        final id = _pillarOrder[i];
                        final info = kPillars[id]!;
                        final isSelected = selectedPillars.contains(id);
                        final desc = _pillarDescriptions[id]!;
                        return RevealAnimation(
                          delay: Duration(milliseconds: 320 + i * 60),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _SummaryPillarRow(
                              info: info,
                              description: desc,
                              isSelected: isSelected,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 700),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        subtext,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                  RevealAnimation(
                    delay: const Duration(milliseconds: 900),
                    child: TourPrimaryButton(
                      label: 'See the big idea',
                      onTap: onNext,
                      color: AppColors.primary,
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

class _SummaryPillarRow extends StatelessWidget {
  const _SummaryPillarRow({
    required this.info,
    required this.description,
    required this.isSelected,
  });

  final PillarInfo info;
  final String description;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? info.color.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? info.color.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.07),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isSelected
                  ? info.color.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: PillarIcon(
                pillar: info.id,
                size: 18,
                color: isSelected
                    ? info.color
                    : Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.name,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: isSelected ? 0.55 : 0.3),
                  ),
                ),
              ],
            ),
          ),
          if (isSelected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: info.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'You picked',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: info.color,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── ClosingScreen ─────────────────────────────────────────────────────────────

class ClosingScreen extends StatefulWidget {
  const ClosingScreen({
    super.key,
    required this.onNext,
  });

  final VoidCallback onNext;

  @override
  State<ClosingScreen> createState() => _ClosingScreenState();
}

class _ClosingScreenState extends State<ClosingScreen>
    with SingleTickerProviderStateMixin {
  int _stage = 0;
  late AnimationController _breatheCtrl;

  @override
  void initState() {
    super.initState();
    _breatheCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _stage = 1);
    });
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _stage = 2);
    });
    Future.delayed(const Duration(milliseconds: 2300), () {
      if (mounted) setState(() => _stage = 3);
    });
  }

  @override
  void dispose() {
    _breatheCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TourScreen(
      bg: AppColors.primary,
      child: Stack(
        children: [
          TopoBG(
            color: const Color(0xFF2A3B1E),
            seed: 'closing',
            opacity: 0.5,
            density: 24,
          ),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _breatheCtrl,
              builder: (ctx, child) => DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      Colors.transparent,
                      AppColors.primary.withValues(alpha: 0.6 * _breatheCtrl.value.clamp(0.3, 1.0)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  AnimatedOpacity(
                    opacity: _stage >= 1 ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 700),
                    child: AnimatedSlide(
                      offset: _stage >= 1 ? Offset.zero : const Offset(0, 0.08),
                      duration: const Duration(milliseconds: 700),
                      curve: const Cubic(0.22, 1, 0.36, 1),
                      child: const Text(
                        "That's\nZuraLog.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 68,
                          fontWeight: FontWeight.w200,
                          letterSpacing: -3.0,
                          height: 1.0,
                          color: AppColors.canvas,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  AnimatedOpacity(
                    opacity: _stage >= 2 ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 600),
                    child: AnimatedSlide(
                      offset: _stage >= 2 ? Offset.zero : const Offset(0, 0.08),
                      duration: const Duration(milliseconds: 600),
                      curve: const Cubic(0.22, 1, 0.36, 1),
                      child: Text(
                        'One app.\nEverything.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                          color: AppColors.canvas.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 4),
                  AnimatedOpacity(
                    opacity: _stage >= 3 ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 600),
                    child: AnimatedSlide(
                      offset: _stage >= 3 ? Offset.zero : const Offset(0, 0.08),
                      duration: const Duration(milliseconds: 600),
                      curve: const Cubic(0.22, 1, 0.36, 1),
                      child: Column(
                        children: [
                          TourPrimaryButton(
                            label: 'Create your account',
                            onTap: widget.onNext,
                            color: AppColors.canvas,
                            textColor: Colors.white,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Free to start.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 13,
                              color: AppColors.canvas.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
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
