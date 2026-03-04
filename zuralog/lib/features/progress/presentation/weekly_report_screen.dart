/// Weekly Report Screen — story-style swipeable weekly report.
///
/// Displays a [WeeklyReport] as a horizontally-paged [PageView] where each
/// page is a full-screen gradient card ([_WeeklyReportCard]) covering one
/// health category. Supports pull-to-refresh and share.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/progress/domain/progress_models.dart';
import 'package:zuralog/features/progress/providers/progress_providers.dart';

// ── Color mapping ─────────────────────────────────────────────────────────────

Color _categoryColor(String gradientCategory) {
  switch (gradientCategory) {
    case 'activity':
      return AppColors.categoryActivity;
    case 'sleep':
      return AppColors.categorySleep;
    case 'body':
      return AppColors.categoryBody;
    case 'heart':
      return AppColors.categoryHeart;
    case 'nutrition':
      return AppColors.categoryNutrition;
    case 'wellness':
      return AppColors.categoryWellness;
    default:
      return AppColors.primary;
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

/// Story-style swipeable weekly report screen.
class WeeklyReportScreen extends ConsumerStatefulWidget {
  /// Creates the [WeeklyReportScreen].
  const WeeklyReportScreen({super.key});

  @override
  ConsumerState<WeeklyReportScreen> createState() =>
      _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends ConsumerState<WeeklyReportScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    ref.invalidate(weeklyReportProvider);
    // Wait for the new value to settle before dismissing the indicator.
    await ref.read(weeklyReportProvider.future).catchError(
          (_) => const WeeklyReport(
            id: '',
            periodStart: '',
            periodEnd: '',
            cards: [],
          ),
        );
  }

  String _formatPeriod(String start, String end) {
    if (start.isEmpty || end.isEmpty) return '';
    try {
      final s = DateTime.parse(start);
      final e = DateTime.parse(end);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      final sMonth = months[s.month - 1];
      final eMonth = months[e.month - 1];
      if (s.month == e.month && s.year == e.year) {
        return 'Week of $sMonth ${s.day} – ${e.day}';
      }
      return 'Week of $sMonth ${s.day} – $eMonth ${e.day}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(weeklyReportProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        surfaceTintColor: Colors.transparent,
        title: Text('Weekly Report', style: AppTextStyles.h2),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.share_rounded,
              color: AppColors.textPrimaryDark,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sharing coming soon')),
              );
            },
          ),
        ],
      ),
      body: reportAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.cardBackgroundDark,
          onRefresh: _onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceLg,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: AppColors.statusError,
                      ),
                      const SizedBox(height: AppDimens.spaceMd),
                      Text(
                        'Failed to load report',
                        style: AppTextStyles.h3.copyWith(
                          color: AppColors.textPrimaryDark,
                        ),
                      ),
                      const SizedBox(height: AppDimens.spaceSm),
                      Text(
                        err.toString(),
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        data: (report) {
          if (report.cards.isEmpty) {
            return RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.cardBackgroundDark,
              onRefresh: _onRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          size: 56,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(height: AppDimens.spaceMd),
                        Text(
                          'No report available yet',
                          style: AppTextStyles.h3.copyWith(
                            color: AppColors.textPrimaryDark,
                          ),
                        ),
                        const SizedBox(height: AppDimens.spaceSm),
                        Text(
                          'Complete a full week of activity to generate your first report.',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textTertiary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          final periodLabel =
              _formatPeriod(report.periodStart, report.periodEnd);

          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.cardBackgroundDark,
            onRefresh: _onRefresh,
            child: Column(
              children: [
                // ── Period header ─────────────────────────────────────────
                if (periodLabel.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimens.spaceMd,
                      AppDimens.spaceSm,
                      AppDimens.spaceMd,
                      AppDimens.spaceMd,
                    ),
                    child: Text(
                      periodLabel,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textTertiary,
                        letterSpacing: 0.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // ── PageView ──────────────────────────────────────────────
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: report.cards.length,
                    onPageChanged: (page) =>
                        setState(() => _currentPage = page),
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.spaceMd,
                      ),
                      child: _WeeklyReportCard(card: report.cards[index]),
                    ),
                  ),
                ),

                // ── Dot indicator ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppDimens.spaceMd,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(report.cards.length, (i) {
                      final isActive = i == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(
                          horizontal: AppDimens.spaceXs,
                        ),
                        width: isActive ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.primary
                              : AppColors.textTertiary.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Weekly Report Card ────────────────────────────────────────────────────────

class _WeeklyReportCard extends StatelessWidget {
  const _WeeklyReportCard({required this.card});

  final WeeklyReportCard card;

  @override
  Widget build(BuildContext context) {
    final categoryColor = _categoryColor(card.gradientCategory);

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            categoryColor.withValues(alpha: 0.85),
            categoryColor.withValues(alpha: 0.35),
            AppColors.backgroundDark,
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Card title ────────────────────────────────────────────────
            Text(
              card.title,
              style: AppTextStyles.h1.copyWith(
                color: AppColors.backgroundLight,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppDimens.spaceLg),

            // ── Metric rows ───────────────────────────────────────────────
            Expanded(
              child: ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: card.metrics.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppDimens.spaceMd),
                itemBuilder: (context, index) =>
                    _MetricRow(metric: card.metrics[index]),
              ),
            ),

            // ── AI text ───────────────────────────────────────────────────
            if (card.aiText.isNotEmpty) ...[
              const SizedBox(height: AppDimens.spaceLg),
              Text(
                card.aiText,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.backgroundLight.withValues(alpha: 0.65),
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Metric Row ────────────────────────────────────────────────────────────────

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.metric});

  final ReportMetric metric;

  @override
  Widget build(BuildContext context) {
    final hasDelta = metric.delta != null && metric.delta!.isNotEmpty;
    final isPositive =
        hasDelta && (metric.delta!.startsWith('+'));
    final isNegative =
        hasDelta && (metric.delta!.startsWith('-'));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Label + value ─────────────────────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                metric.label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.backgroundLight.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 2),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: metric.value,
                      style: AppTextStyles.h2.copyWith(color: AppColors.backgroundLight),
                    ),
                    if (metric.unit.isNotEmpty)
                      TextSpan(
                        text: '  ${metric.unit}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.backgroundLight.withValues(alpha: 0.65),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Delta chip ────────────────────────────────────────────────────
        if (hasDelta)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceSm,
              vertical: AppDimens.spaceXs,
            ),
            decoration: BoxDecoration(
              color: isPositive
                  ? AppColors.categoryActivity.withValues(alpha: 0.25)
                  : isNegative
                      ? AppColors.statusError.withValues(alpha: 0.25)
                      : AppColors.backgroundLight.withValues(alpha: 0.12),
              borderRadius:
                  BorderRadius.circular(AppDimens.radiusChip),
            ),
            child: Text(
              metric.delta!,
              style: AppTextStyles.labelXs.copyWith(
                color: isPositive
                    ? AppColors.categoryActivity
                    : isNegative
                        ? AppColors.statusError
                        : AppColors.backgroundLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
