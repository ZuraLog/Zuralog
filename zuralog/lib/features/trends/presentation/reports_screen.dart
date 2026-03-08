/// Reports Screen — /trends/reports
///
/// Lists auto-generated monthly health reports. Tap a report to expand
/// its full detail: category summaries, goal adherence, top correlations,
/// trend directions, and AI recommendations.
///
/// Export actions:
///   - Share as image: captures the report detail widget via [screenshot]
///     and shares via [share_plus].
///   - PDF export: renders a plain-text PDF via [printing] / [pdf] — deferred;
///     currently shows a "coming soon" snackbar since the pdf package is
///     not yet in pubspec. The share-as-image path is fully functional.
///
/// Layout:
///   - AppBar: "Reports" title + back button
///   - List of [GeneratedReport] cards, newest first
///   - Tap to open [_ReportDetailSheet] (full-screen modal)
///   - Empty state when no reports
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import 'package:zuralog/core/haptics/haptic.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/trends/domain/trends_models.dart';
import 'package:zuralog/features/trends/providers/trends_providers.dart';

// ── ReportsScreen ─────────────────────────────────────────────────────────────

/// Monthly reports list screen.
class ReportsScreen extends ConsumerWidget {
  /// Creates the [ReportsScreen].
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(reportsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
      ),
      body: reportsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => _ReportsErrorState(
          onRetry: () => ref.invalidate(reportsProvider),
        ),
        data: (reportList) => reportList.reports.isEmpty
            ? const _EmptyReportsState()
            : _ReportsList(reports: reportList.reports),
      ),
    );
  }
}

// ── Reports List ──────────────────────────────────────────────────────────────

class _ReportsList extends ConsumerWidget {
  const _ReportsList({required this.reports});
  final List<GeneratedReport> reports;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.read(hapticServiceProvider).light();
        ref.invalidate(reportsProvider);
      },
      color: AppColors.primary,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(
          AppDimens.spaceMd,
          AppDimens.spaceMd,
          AppDimens.spaceMd,
          MediaQuery.of(context).padding.bottom,
        ),
        itemCount: reports.length,
        separatorBuilder: (_, _) =>
            const SizedBox(height: AppDimens.spaceSm),
        itemBuilder: (context, index) => _ReportCard(
          report: reports[index],
          onTap: () => _showReportDetail(context, reports[index]),
        ),
      ),
    );
  }

  void _showReportDetail(BuildContext context, GeneratedReport report) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusCard),
        ),
      ),
      builder: (_) => _ReportDetailSheet(report: report),
    );
  }
}

// ── Report Card ───────────────────────────────────────────────────────────────

class _ReportCard extends ConsumerWidget {
  const _ReportCard({required this.report, required this.onTap});
  final GeneratedReport report;
  final VoidCallback onTap;

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        ref.read(hapticServiceProvider).light();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        decoration: BoxDecoration(
          color: AppColors.cardBackgroundDark,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
              child: const Icon(
                Icons.summarize_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: AppDimens.spaceMd),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(report.title, style: AppTextStyles.h3),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatDate(report.periodStart)} – ${_formatDate(report.periodEnd)}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                  if (report.categorySummaries.isNotEmpty) ...[
                    const SizedBox(height: AppDimens.spaceSm),
                    _CategoryAvatarRow(
                        summaries: report.categorySummaries),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
              size: AppDimens.iconMd,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryAvatarRow extends StatelessWidget {
  const _CategoryAvatarRow({required this.summaries});
  final List<ReportCategorySummary> summaries;

  Color _categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'activity':
        return AppColors.categoryActivity;
      case 'sleep':
        return AppColors.categorySleep;
      case 'heart':
        return AppColors.categoryHeart;
      case 'nutrition':
        return AppColors.categoryNutrition;
      case 'body':
        return AppColors.categoryBody;
      case 'wellness':
        return AppColors.categoryWellness;
      case 'vitals':
        return AppColors.categoryVitals;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: summaries.take(5).map((s) {
        final color = _categoryColor(s.category);
        return Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Center(
            child: Text(
              s.categoryLabel.isNotEmpty
                  ? s.categoryLabel[0].toUpperCase()
                  : '?',
              style: AppTextStyles.labelXs.copyWith(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Report Detail Sheet ───────────────────────────────────────────────────────

class _ReportDetailSheet extends StatefulWidget {
  const _ReportDetailSheet({required this.report});
  final GeneratedReport report;

  @override
  State<_ReportDetailSheet> createState() => _ReportDetailSheetState();
}

class _ReportDetailSheetState extends State<_ReportDetailSheet> {
  final _screenshotController = ScreenshotController();
  bool _isSharing = false;

  Color _categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'activity':
        return AppColors.categoryActivity;
      case 'sleep':
        return AppColors.categorySleep;
      case 'heart':
        return AppColors.categoryHeart;
      case 'nutrition':
        return AppColors.categoryNutrition;
      case 'body':
        return AppColors.categoryBody;
      case 'wellness':
        return AppColors.categoryWellness;
      case 'vitals':
        return AppColors.categoryVitals;
      default:
        return AppColors.primary;
    }
  }

  IconData _trendIcon(String direction) {
    switch (direction) {
      case 'up':
        return Icons.trending_up_rounded;
      case 'down':
        return Icons.trending_down_rounded;
      default:
        return Icons.trending_flat_rounded;
    }
  }

  Color _trendColor(String direction) {
    switch (direction) {
      case 'up':
        return AppColors.categoryActivity;
      case 'down':
        return AppColors.accentDark;
      default:
        return AppColors.textSecondaryDark;
    }
  }

  Future<void> _shareAsImage() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final Uint8List? imageBytes =
          await _screenshotController.capture(pixelRatio: 2.0);
      if (imageBytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not capture report. Try again.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      final xFile = XFile.fromData(
        imageBytes,
        name: '${widget.report.title}.png',
        mimeType: 'image/png',
      );
      await Share.shareXFiles(
        [xFile],
        text: widget.report.title,
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: AppDimens.spaceMd),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderDark,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header row
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd),
              child: Row(
                children: [
                  Expanded(
                    child: Text(report.title, style: AppTextStyles.h2),
                  ),
                  // PDF export — deferred (pdf package not in pubspec)
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    color: AppColors.textSecondaryDark,
                    tooltip: 'Export PDF (coming soon)',
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('PDF export coming soon.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    ),
                  ),
                  // Share as image — fully functional
                  IconButton(
                    icon: _isSharing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        : const Icon(Icons.share_rounded),
                    color: AppColors.textSecondaryDark,
                    tooltip: 'Share as image',
                    onPressed: _isSharing ? null : _shareAsImage,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                // Screenshot wraps only the Column so capture() has a
                // bounded widget to render — not an unbounded ListView.
                child: Screenshot(
                  controller: _screenshotController,
                  child: ColoredBox(
                    color: AppColors.backgroundDark,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.spaceMd),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      // ── Category summaries ─────────────────────────
                      if (report.categorySummaries.isNotEmpty) ...[
                        _SheetSectionHeader(title: 'By Category'),
                        ...report.categorySummaries.map(
                          (s) => _CategorySummaryRow(
                            summary: s,
                            accentColor: _categoryColor(s.category),
                          ),
                        ),
                        const SizedBox(height: AppDimens.spaceMd),
                      ],

                      // ── Goal adherence ─────────────────────────────
                      if (report.goalAdherence.isNotEmpty) ...[
                        _SheetSectionHeader(title: 'Goal Adherence'),
                        ...report.goalAdherence.map(
                          (g) => _GoalAdherenceRow(goal: g),
                        ),
                        const SizedBox(height: AppDimens.spaceMd),
                      ],

                      // ── Trend directions ───────────────────────────
                      if (report.trendDirections.isNotEmpty) ...[
                        _SheetSectionHeader(title: 'Trends'),
                        Wrap(
                          spacing: AppDimens.spaceSm,
                          runSpacing: AppDimens.spaceSm,
                          children: report.trendDirections.map((t) {
                            final icon = _trendIcon(t.direction);
                            final color = _trendColor(t.direction);
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDimens.spaceSm,
                                vertical: AppDimens.spaceXs,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(
                                    AppDimens.radiusChip),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(icon, size: 14, color: color),
                                  const SizedBox(width: 4),
                                  Text(
                                    t.metricLabel,
                                    style: AppTextStyles.labelXs
                                        .copyWith(color: color),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: AppDimens.spaceMd),
                      ],

                      // ── Top correlations ───────────────────────────
                      if (report.topCorrelations.isNotEmpty) ...[
                        _SheetSectionHeader(title: 'Top Correlations'),
                        ...report.topCorrelations.map(
                          (c) => Padding(
                            padding: const EdgeInsets.only(
                                bottom: AppDimens.spaceSm),
                            child: Container(
                              padding:
                                  const EdgeInsets.all(AppDimens.spaceMd),
                              decoration: BoxDecoration(
                                color: AppColors.cardBackgroundDark,
                                borderRadius: BorderRadius.circular(
                                    AppDimens.radiusCard),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.headline,
                                          style: AppTextStyles.caption,
                                        ),
                                        Text(
                                          '${c.metricA} × ${c.metricB}',
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(
                                            color:
                                                AppColors.textSecondaryDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    c.coefficient.toStringAsFixed(2),
                                    style: AppTextStyles.h3.copyWith(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDimens.spaceMd),
                      ],

                      // ── AI recommendations ─────────────────────────
                      if (report.aiRecommendations.isNotEmpty) ...[
                        _SheetSectionHeader(title: 'Recommendations'),
                        ...report.aiRecommendations.asMap().entries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(
                                bottom: AppDimens.spaceSm),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${entry.key + 1}',
                                      style: AppTextStyles.labelXs.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppDimens.spaceSm),
                                Expanded(
                                  child: Text(
                                    entry.value,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.textPrimaryDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: AppDimens.spaceXxl),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Goal Adherence Row ────────────────────────────────────────────────────────

class _GoalAdherenceRow extends StatelessWidget {
  const _GoalAdherenceRow({required this.goal});
  final GoalAdherenceItem goal;

  @override
  Widget build(BuildContext context) {
    final pct = (goal.achievedPercent * 100).round();
    final color = pct >= 80
        ? AppColors.categoryActivity
        : pct >= 50
            ? AppColors.healthScoreAmber
            : AppColors.accentDark;

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.cardBackgroundDark,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(goal.goalLabel, style: AppTextStyles.caption),
              ),
              Text(
                '$pct%',
                style: AppTextStyles.h3.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceSm),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: goal.achievedPercent,
              minHeight: 4,
              backgroundColor: AppColors.borderDark,
              color: color,
            ),
          ),
          if (goal.streakDays > 0) ...[
            const SizedBox(height: AppDimens.spaceXs),
            Text(
              '${goal.streakDays}-day streak at end of period',
              style: AppTextStyles.labelXs.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategorySummaryRow extends StatelessWidget {
  const _CategorySummaryRow({
    required this.summary,
    required this.accentColor,
  });

  final ReportCategorySummary summary;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final delta = summary.deltaVsPrior;
    final isPositive = delta >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.cardBackgroundDark,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: Row(
        children: [
          // Category color dot
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summary.categoryLabel, style: AppTextStyles.caption),
                if (summary.keyMetric.isNotEmpty)
                  Text(
                    '${summary.keyMetric}: ${summary.keyMetricValue}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${summary.averageScore}',
                style: AppTextStyles.h3.copyWith(color: accentColor),
              ),
              Text(
                '${isPositive ? '+' : ''}${delta.toStringAsFixed(1)}%',
                style: AppTextStyles.labelXs.copyWith(
                  color: isPositive
                      ? AppColors.categoryActivity
                      : AppColors.accentDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SheetSectionHeader extends StatelessWidget {
  const _SheetSectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppDimens.spaceMd,
        bottom: AppDimens.spaceSm,
      ),
      child: Text(title, style: AppTextStyles.h3),
    );
  }
}

// ── Empty / Error States ──────────────────────────────────────────────────────

class _EmptyReportsState extends StatelessWidget {
  const _EmptyReportsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.summarize_rounded,
              size: 40,
              color: AppColors.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Text('No Reports Yet', style: AppTextStyles.h3),
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              'Your first monthly report will be generated after 30 days of data collection.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondaryDark,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportsErrorState extends StatelessWidget {
  const _ReportsErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 40,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Text('Could not load reports', style: AppTextStyles.h3),
            const SizedBox(height: AppDimens.spaceLg),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.primaryButtonText,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimens.radiusButtonMd),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
