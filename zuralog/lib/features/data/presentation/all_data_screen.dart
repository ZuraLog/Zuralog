/// All Data — wheel + AI summary + chart shards + every-metric grid.
///
/// Phase 1 of the rewrite: scaffold + app bar + time toggle + mandala + legend.
/// The AI summary, chart shards, every-metric grid, and states land in
/// follow-up commits. See:
/// docs/superpowers/specs/2026-04-21-all-data-redesign-design.md
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/data/domain/all_data_summary.dart';
import 'package:zuralog/features/data/domain/category_color.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/mandala_data.dart';
import 'package:zuralog/features/data/providers/data_providers.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

/// Time-range toggle states for the All Data screen.
///
/// [providerRange] is the string that the existing `categoryDetailProvider`
/// expects for its `timeRange` argument — we keep the provider contract
/// unchanged.
enum _AllDataRange {
  today('Today', '7D'),
  week('Week', '7D'),
  month('Month', '30D');

  const _AllDataRange(this.label, this.providerRange);
  final String label;
  final String providerRange;
}

/// All Data screen — scrollable picture of every metric the user tracks.
///
/// Hero: radial mandala ([ZHealthMandala]) where each spoke is one metric,
/// length encoded vs the user's 30-day baseline. Keeps the route
/// `/data/all` and the class name `AllDataScreen` — the router resolves it.
class AllDataScreen extends ConsumerStatefulWidget {
  const AllDataScreen({super.key});

  @override
  ConsumerState<AllDataScreen> createState() => _AllDataScreenState();
}

class _AllDataScreenState extends ConsumerState<AllDataScreen>
    with AutomaticKeepAliveClientMixin {
  _AllDataRange _range = _AllDataRange.today;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = AppColorsOf(context);

    return ZuralogScaffold(
      appBar: const ZuralogAppBar(
        title: 'All your data',
        showProfileAvatar: false,
      ),
      body: RefreshIndicator(
        color: colors.primary,
        onRefresh: _onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: _Eyebrow()),
            SliverToBoxAdapter(
              child: _TimeToggle(
                value: _range,
                onChanged: (r) => setState(() => _range = r),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppDimens.spaceSm)),
            SliverToBoxAdapter(child: _MandalaSection(range: _range)),
            const SliverToBoxAdapter(child: _Legend()),
            SliverToBoxAdapter(child: _AiSummarySection(range: _range)),
            SliverToBoxAdapter(
              child: SizedBox(
                height: AppDimens.bottomClearance(context) + AppDimens.spaceXl,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onRefresh() async {
    ref.invalidate(dashboardProvider);
    ref.invalidate(healthScoreProvider);
    for (final cat in kMandalaCategoryOrder) {
      ref.invalidate(categoryDetailProvider(CategoryDetailParams(
        categoryId: cat.name,
        timeRange: _range.providerRange,
      )));
    }
  }
}

/// Reads live category-detail providers for the given range and assembles the
/// [MandalaData] consumed by both the wheel and the AI summary generator.
MandalaData _readMandalaData(WidgetRef ref, _AllDataRange r) {
  final wedges = <MandalaWedge>[];
  for (final cat in kMandalaCategoryOrder) {
    final detail = ref.watch(categoryDetailProvider(CategoryDetailParams(
      categoryId: cat.name,
      timeRange: r.providerRange,
    )));
    final spokes = detail.maybeWhen(
      data: (d) => _spokesFromMetrics(d.metrics),
      orElse: () => const <MandalaSpoke>[],
    );
    wedges.add(MandalaWedge(category: cat, spokes: spokes));
  }
  return MandalaData(wedges: wedges);
}

/// Maps a list of [MetricSeries] into a spoke list. Caps density at 8 spokes
/// per wedge. Requires at least 3 finite data points to compute a baseline.
List<MandalaSpoke> _spokesFromMetrics(List<MetricSeries> metrics) {
  final spokes = <MandalaSpoke>[];
  for (final m in metrics) {
    if (spokes.length >= 8) break;
    final values = m.dataPoints
        .map((p) => p.value)
        .where((v) => v.isFinite)
        .toList();
    if (values.length < 3) continue;
    final today = values.last;
    final baseline = values.reduce((a, b) => a + b) / values.length;
    spokes.add(MandalaSpoke(
      metricId: m.metricId,
      displayName: m.displayName,
      todayValue: today,
      baseline30d: baseline,
      inverted: kInvertedMetricIds.contains(m.metricId),
    ));
  }
  return spokes;
}

/// "YOUR BODY" eyebrow, above the title.
class _Eyebrow extends StatelessWidget {
  const _Eyebrow();
  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppDimens.spaceMd, 0, AppDimens.spaceMd, 0),
      child: Text(
        'YOUR BODY',
        style: AppTextStyles.labelSmall.copyWith(
          color: colors.textSecondary,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Today / Week / Month segmented pill.
class _TimeToggle extends StatelessWidget {
  const _TimeToggle({required this.value, required this.onChanged});
  final _AllDataRange value;
  final ValueChanged<_AllDataRange> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppDimens.spaceMd, AppDimens.spaceXs, AppDimens.spaceMd, 0),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppDimens.shapePill),
        ),
        child: Row(
          children: [
            for (final r in _AllDataRange.values)
              Expanded(
                child: _ToggleSeg(
                  label: r.label,
                  active: r == value,
                  onTap: () => onChanged(r),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToggleSeg extends StatelessWidget {
  const _ToggleSeg(
      {required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: active ? colors.textPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimens.shapePill),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: active ? colors.textOnWarmWhite : colors.textSecondary,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Builds the mandala from live provider data.
class _MandalaSection extends ConsumerWidget {
  const _MandalaSection({required this.range});
  final _AllDataRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final score = ref.watch(healthScoreProvider).maybeWhen(
          data: (d) => d.score,
          orElse: () => null,
        );
    final mandala = _readMandalaData(ref, range);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppDimens.spaceMd, 0, AppDimens.spaceMd, 0),
      child: ZHealthMandala(
        data: mandala,
        healthScore: (score == null || score == 0) ? null : score,
        onSpokeTap: (id) {
          // Microscope wiring lands in a follow-up phase.
        },
        onCenterTap: () {
          context.push(RouteNames.dataScoreBreakdownPath);
        },
      ),
    );
  }
}

/// Compact legend that wraps under the mandala.
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    const entries = <(String, HealthCategory)>[
      ('Sleep', HealthCategory.sleep),
      ('Move', HealthCategory.activity),
      ('Heart', HealthCategory.heart),
      ('Food', HealthCategory.nutrition),
      ('Body', HealthCategory.body),
      ('Mind', HealthCategory.wellness),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppDimens.spaceMd, AppDimens.spaceSm, AppDimens.spaceMd, 0),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          for (final e in entries)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: categoryColor(e.$2),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  e.$1,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: colors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// AI summary card with inline expandable breakdown.
///
/// Sits below the legend and summarises the same mandala data the wheel
/// renders. Tapping the card toggles an animated reveal of the full
/// [ZAiBreakdownCard] directly below it — same sliver, same scroll.
class _AiSummarySection extends ConsumerStatefulWidget {
  const _AiSummarySection({required this.range});
  final _AllDataRange range;
  @override
  ConsumerState<_AiSummarySection> createState() => _AiSummarySectionState();
}

class _AiSummarySectionState extends ConsumerState<_AiSummarySection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final mandala = _readMandalaData(ref, widget.range);
    final summary = AllDataSummaryGenerator.generate(mandala);
    final now = TimeOfDay.now();
    final timeLabel = _formatAiTime(now);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppDimens.spaceMd, AppDimens.spaceMd, AppDimens.spaceMd, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ZAiSummaryCard(
            summary: summary,
            generatedAtLabel: timeLabel,
            onExpand: () => setState(() => _expanded = !_expanded),
            onMetricTap: (id) {
              // Microscope wiring lands in a follow-up task.
            },
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: AppDimens.spaceSm),
                    child: ZAiBreakdownCard(
                      summary: summary,
                      onSectionTap: (_) {
                        // Microscope wiring lands in a follow-up task.
                      },
                      onClose: () => setState(() => _expanded = false),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

String _formatAiTime(TimeOfDay t) {
  final hour12 = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  final minute = t.minute.toString().padLeft(2, '0');
  final amPm = t.period == DayPeriod.am ? 'AM' : 'PM';
  return 'AI · ${hour12.toString().padLeft(2, '0')}:$minute $amPm';
}
