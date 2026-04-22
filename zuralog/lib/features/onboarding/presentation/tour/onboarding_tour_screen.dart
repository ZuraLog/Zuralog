/// Zuralog — Phase 1 Product Tour (v2.0).
///
/// Assembles all tour screens into a single PageView flow.
///
/// Page structure:
///   0     TourIntroScreen
///   1-3   TourPromiseScreen  (3 promise slides)
///   4     TourIntentScreen   (pillar selection — locks in chapters)
///   5+    TourChapterHero + 4 content screens per selected pillar
///   last6 ExtrasHeroScreen, JournalScreen, WaterScreen,
///         ComingSoonScreen, SummaryScreen, ClosingScreen
///
/// Total pages: 5 + N×5 + 6  (N = number of selected pillars, 1-4).
///
/// On ClosingScreen CTA: marks tour seen → navigates to WelcomeScreen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/onboarding/providers/onboarding_tour_providers.dart';

import 'package:zuralog/features/onboarding/presentation/tour/phase1_intro.dart';
import 'package:zuralog/features/onboarding/presentation/tour/phase1_heart.dart';
import 'package:zuralog/features/onboarding/presentation/tour/phase1_sleep.dart';
import 'package:zuralog/features/onboarding/presentation/tour/phase1_workout.dart';
import 'package:zuralog/features/onboarding/presentation/tour/phase1_nutrients.dart';
import 'package:zuralog/features/onboarding/presentation/tour/phase1_extras.dart';

// ── Chapter metadata ──────────────────────────────────────────────────────────

class _ChapterMeta {
  const _ChapterMeta({
    required this.pillar,
    required this.title,
    required this.subtitle,
  });

  final String pillar;
  final String title;
  final String subtitle;
}

const _kChapterMeta = <String, _ChapterMeta>{
  'heart': _ChapterMeta(
    pillar: 'heart',
    title: 'Heart',
    subtitle: 'Every beat, in context.',
  ),
  'sleep': _ChapterMeta(
    pillar: 'sleep',
    title: 'Sleep',
    subtitle: 'Know what actually happened at night.',
  ),
  'workout': _ChapterMeta(
    pillar: 'workout',
    title: 'Training',
    subtitle: 'Progress you can see.',
  ),
  'nutrients': _ChapterMeta(
    pillar: 'nutrients',
    title: 'Nutrients',
    subtitle: 'AI that reads your plate.',
  ),
};

// Always show pillars in this canonical order.
const _kPillarOrder = ['heart', 'sleep', 'workout', 'nutrients'];

// ═══════════════════════════════════════════════════════════════════════════════
// Screen
// ═══════════════════════════════════════════════════════════════════════════════

/// Full Phase 1 product tour. Replaces [OnboardingPageView].
class OnboardingTourScreen extends ConsumerStatefulWidget {
  const OnboardingTourScreen({super.key});

  @override
  ConsumerState<OnboardingTourScreen> createState() =>
      _OnboardingTourScreenState();
}

class _OnboardingTourScreenState extends ConsumerState<OnboardingTourScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Locked in when the user taps "Continue" on the intent screen (page 4).
  // Before that, reads from selectedTourPillarsProvider.
  List<String>? _confirmedPillars;

  // ── Computed properties ────────────────────────────────────────────────────

  List<String> get _activePillars {
    final List<String> confirmed =
        _confirmedPillars ?? ref.read(selectedTourPillarsProvider);
    return _kPillarOrder.where((id) => confirmed.contains(id)).toList();
  }

  // 5 intro + N×5 pillar + 6 extras (hero, journal, water, coming-soon, summary, closing)
  int get _totalPages => 5 + _activePillars.length * 5 + 6;

  double _progress(int page) {
    final total = _totalPages;
    if (total <= 1) return 1.0;
    return page / (total - 1);
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _advance() {
    // Lock in pillar selections when advancing past the intent screen.
    if (_currentPage == 4) {
      setState(() {
        _confirmedPillars = List.from(ref.read(selectedTourPillarsProvider));
      });
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _onTourComplete() async {
    await markOnboardingComplete();
    if (!mounted) return;
    ref.invalidate(hasSeenOnboardingProvider);
    if (!mounted) return;
    context.go(RouteNames.welcomePath);
  }

  // ── Page builder ───────────────────────────────────────────────────────────

  Widget _buildPage(int index) {
    // ── Intro section (pages 0-4) ──────────────────────────────────────────
    if (index == 0) {
      return TourIntroScreen(onNext: _advance);
    }

    if (index >= 1 && index <= 3) {
      const promises = [
        (
          title: 'One app.\nFor everything\nyour body does.',
          body:
              'Heart, sleep, training, nutrients. All in one place.',
        ),
        (
          title: 'An AI that listens\nbefore it speaks.',
          body:
              'ZuraLog learns from every meal, workout, and night you sleep. Then quietly gets out of your way.',
        ),
        (
          title: 'Built around you,\nnot the average person.',
          body: 'Your version of healthy. Your targets. Your pace.',
        ),
      ];
      final i = index - 1; // 0, 1, 2
      final p = promises[i];
      return TourPromiseScreen(
        index: index,
        total: 3,
        title: p.title,
        body: p.body,
        progress: _progress(index),
        accent: const Color(0xFFCFE1B9),
        onNext: _advance,
      );
    }

    if (index == 4) {
      final List<String> currentSelections =
          _confirmedPillars ?? ref.watch(selectedTourPillarsProvider);
      return TourIntentScreen(
        selected: currentSelections,
        onChanged: (updated) =>
            ref.read(selectedTourPillarsProvider.notifier).state = updated,
        progress: _progress(4),
        onNext: _advance,
      );
    }

    // ── Dynamic pillar chapters (pages 5 .. 5+N*5-1) ──────────────────────
    final pillars = _activePillars;
    final chapterTotal = pillars.length + 1; // +1 for extras
    const pillarBase = 5;
    final extrasBase = pillarBase + pillars.length * 5;

    if (index >= pillarBase && index < extrasBase) {
      final pillarIndex = (index - pillarBase) ~/ 5;
      final screenIndex = (index - pillarBase) % 5;
      final pillarId = pillars[pillarIndex];
      final chapterNum = pillarIndex + 1;
      final p = _progress(index);

      if (screenIndex == 0) {
        final meta = _kChapterMeta[pillarId]!;
        return TourChapterHero(
          pillar: pillarId,
          title: meta.title,
          subtitle: meta.subtitle,
          chapterNum: chapterNum,
          chapterTotal: chapterTotal,
          progress: p,
          onNext: _advance,
        );
      }

      return _buildPillarContent(pillarId, screenIndex, p);
    }

    // ── Extras section (last 6 pages) ──────────────────────────────────────
    final extrasOffset = index - extrasBase;
    final extrasChapterNum = pillars.length + 1;
    final chapterTotalForExtras = pillars.length + 1;

    switch (extrasOffset) {
      case 0:
        return ExtrasHeroScreen(
          chapterNum: extrasChapterNum,
          chapterTotal: chapterTotalForExtras,
          progress: _progress(index),
          onNext: _advance,
        );
      case 1:
        return JournalScreen(progress: _progress(index), onNext: _advance);
      case 2:
        return WaterScreen(progress: _progress(index), onNext: _advance);
      case 3:
        return ComingSoonScreen(
            progress: _progress(index), onNext: _advance);
      case 4:
        return SummaryScreen(
          progress: _progress(index),
          selectedPillars: [
            ...pillars,
            'journal',
            'water',
          ],
          onNext: _advance,
        );
      case 5:
        return ClosingScreen(onNext: _onTourComplete);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPillarContent(String pillar, int screenIndex, double progress) {
    switch (pillar) {
      case 'heart':
        return switch (screenIndex) {
          1 => HeartScreen1(progress: progress, onNext: _advance),
          2 => HeartScreen2(progress: progress, onNext: _advance),
          3 => HeartScreen3(progress: progress, onNext: _advance),
          4 => HeartScreen4(progress: progress, onNext: _advance),
          _ => const SizedBox.shrink(),
        };

      case 'sleep':
        return switch (screenIndex) {
          1 => SleepScreen1(progress: progress, onContinue: _advance),
          2 => SleepScreen2(progress: progress, onContinue: _advance),
          3 => SleepScreen3(progress: progress, onContinue: _advance),
          4 => SleepScreen4(progress: progress, onContinue: _advance),
          _ => const SizedBox.shrink(),
        };

      case 'workout':
        return switch (screenIndex) {
          1 => WorkoutScreen1(progress: progress, onContinue: _advance),
          2 => WorkoutScreen2(progress: progress, onContinue: _advance),
          3 => WorkoutScreen3(progress: progress, onContinue: _advance),
          4 => WorkoutScreen4(progress: progress, onContinue: _advance),
          _ => const SizedBox.shrink(),
        };

      case 'nutrients':
        return switch (screenIndex) {
          1 => NutrientsScreen1(progress: progress, onNext: _advance),
          2 => NutrientsScreen2(progress: progress, onNext: _advance),
          3 => NutrientsScreen3(progress: progress, onNext: _advance),
          4 => NutrientsScreen4(progress: progress, onNext: _advance),
          _ => const SizedBox.shrink(),
        };

      default:
        return const SizedBox.shrink();
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF161618),
      body: PageView.builder(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (page) => setState(() => _currentPage = page),
        itemCount: _totalPages,
        itemBuilder: (context, index) => _buildPage(index),
      ),
    );
  }
}
