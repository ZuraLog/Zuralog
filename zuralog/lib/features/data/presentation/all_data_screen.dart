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
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/data/domain/all_data_summary.dart';
import 'package:zuralog/features/data/domain/category_color.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/mandala_data.dart';
import 'package:zuralog/features/data/providers/data_providers.dart';
import 'package:zuralog/features/nutrition/providers/nutrition_providers.dart';
import 'package:zuralog/features/sleep/providers/sleep_providers.dart';
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
            SliverToBoxAdapter(child: _ShardsSection(range: _range)),
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

// ── Shards grid (TODAY'S SPOTLIGHT) ─────────────────────────────────────────

/// 3×2 grid of compact per-category chart cards.
///
/// Each shard uses a different chart shape so the eye reads each category
/// as itself — Sleep donut, Move bars, Heart zones, Food macro ring, Body
/// BMI gauge, Mind dots. Data pulls from the same providers the mandala
/// uses, plus the per-category day-summary providers for the subtler
/// metrics (stages, macros, zones).
class _ShardsSection extends ConsumerWidget {
  const _ShardsSection({required this.range});
  final _AllDataRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppDimens.spaceMd, AppDimens.spaceMd, AppDimens.spaceMd, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SpotlightHeader(),
          const SizedBox(height: AppDimens.spaceXs),
          GridView.count(
            crossAxisCount: 3,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            childAspectRatio: 1 / 1.2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              const _SleepShard(),
              _MoveShard(range: range),
              const _HeartShard(),
              const _FoodShard(),
              const _BodyShard(),
              _MindShard(range: range),
            ],
          ),
        ],
      ),
    );
  }
}

/// "TODAY'S SPOTLIGHT" eyebrow + "All metrics ↓" link.
///
/// The link is a no-op for now — Task 16 wires it to scroll to the
/// every-metric grid (which doesn't exist yet).
class _SpotlightHeader extends StatelessWidget {
  const _SpotlightHeader();
  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            "TODAY'S SPOTLIGHT",
            style: AppTextStyles.labelSmall.copyWith(
              color: colors.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Text(
          'All metrics ↓',
          style: AppTextStyles.labelSmall.copyWith(
            color: colors.primary,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Common card frame for a shard: label (top), chart (center), hero value
/// (bottom). Keeps every shard visually consistent regardless of which
/// chart shape fills the middle.
class _ShardFrame extends StatelessWidget {
  const _ShardFrame({
    required this.name,
    required this.chart,
    required this.value,
    this.unit,
  });
  final String name;
  final Widget chart;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return ZuralogCard(
      variant: ZCardVariant.data,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style: AppTextStyles.labelSmall.copyWith(
              color: colors.textSecondary,
              fontSize: 8,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
          Expanded(
            child: Center(child: chart),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Lora',
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    height: 1,
                    color: colors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 3),
                Text(
                  unit!,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: colors.textTertiary,
                    fontSize: 7,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── SLEEP — inline donut ────────────────────────────────────────────────────

/// Sleep stages shard. Renders a compact four-arc donut (deep / REM /
/// light / awake) inline because the full [ZSleepStageBreakdownCard] is a
/// complete card and too tall for a shard slot.
class _SleepShard extends ConsumerWidget {
  const _SleepShard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sleep = ref.watch(sleepDaySummaryProvider).maybeWhen(
          data: (d) => d,
          orElse: () => null,
        );
    final stages = sleep?.stages;
    final deep = stages?.deepMinutes ?? 0;
    final rem = stages?.remMinutes ?? 0;
    final light = stages?.lightMinutes ?? 0;
    final awake = stages?.awakeMinutes ?? 0;
    final total = deep + rem + light + awake;
    final valueText = total > 0 ? _formatHoursMinutes(total) : '—';
    return _ShardFrame(
      name: 'Sleep stages',
      chart: SizedBox(
        width: 48,
        height: 48,
        child: CustomPaint(
          painter: _SleepDonutPainter(
            deep: deep.toDouble(),
            rem: rem.toDouble(),
            light: light.toDouble(),
            awake: awake.toDouble(),
          ),
        ),
      ),
      value: valueText,
      unit: total > 0 ? 'slept' : null,
    );
  }
}

/// Paints a four-arc donut for the Sleep shard. Palette intentionally
/// inline — these are specifically sleep-stage shades, not top-level
/// tokens, and there is no matching token set in [AppColors] today.
class _SleepDonutPainter extends CustomPainter {
  _SleepDonutPainter({
    required this.deep,
    required this.rem,
    required this.light,
    required this.awake,
  });
  final double deep;
  final double rem;
  final double light;
  final double awake;

  @override
  void paint(Canvas canvas, Size size) {
    final total = deep + rem + light + awake;
    if (total <= 0) {
      // Empty ring — dim placeholder.
      canvas.drawCircle(
        size.center(Offset.zero),
        size.shortestSide / 2 - 3,
        Paint()
          ..color = const Color(0xFF272729)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6,
      );
      return;
    }
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2 - 3,
    );
    // Four arc segments — deep indigo → REM → light → awake gray.
    const colors = <int>[
      0xFF5E5CE6, // deep
      0xFF7E7CE8, // rem
      0xFFA5A4F0, // light
      0xFF3A3A3C, // awake
    ];
    final values = [deep, rem, light, awake];
    const startAngle = -3.141592653589793 / 2; // top
    double cursor = startAngle;
    for (var i = 0; i < 4; i++) {
      if (values[i] <= 0) continue;
      final sweep = (values[i] / total) * (3.141592653589793 * 2);
      canvas.drawArc(
        rect,
        cursor,
        sweep,
        false,
        Paint()
          ..color = Color(colors[i])
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6,
      );
      cursor += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _SleepDonutPainter old) =>
      old.deep != deep ||
      old.rem != rem ||
      old.light != light ||
      old.awake != awake;
}

/// Formats total minutes as `Xh YYm` (or `Zm` when under an hour).
String _formatHoursMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}

// ── MOVE — 7-day bar chart ──────────────────────────────────────────────────

/// Move shard — steps for each of the last seven days as a bar chart.
class _MoveShard extends ConsumerWidget {
  const _MoveShard({required this.range});
  final _AllDataRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(categoryDetailProvider(CategoryDetailParams(
      categoryId: HealthCategory.activity.name,
      timeRange: range.providerRange,
    )));
    final steps = detail.maybeWhen(
      data: (d) {
        for (final m in d.metrics) {
          if (m.metricId == 'steps') return m;
        }
        return null;
      },
      orElse: () => null,
    );
    final values = steps?.dataPoints
            .map((p) => p.value)
            .where((v) => v.isFinite)
            .toList() ??
        const <double>[];
    final last7 =
        values.length >= 7 ? values.sublist(values.length - 7) : values;
    final today = last7.isEmpty ? null : last7.last;
    return _ShardFrame(
      name: 'Steps · 7d',
      chart: SizedBox(
        height: 44,
        child: last7.length >= 3
            ? ZCategoryChart(
                kind: ZCategoryChartKind.bars,
                points: last7,
                color: categoryColor(HealthCategory.activity),
                dayLabels: const <String>['', '', '', '', '', '', ''],
                todayIndex: last7.length - 1,
              )
            : const SizedBox.shrink(),
      ),
      value: today == null ? '—' : _formatThousands(today.round()),
      unit: today == null ? null : 'steps',
    );
  }
}

/// Adds commas to a whole-number count (e.g. `12345` → `"12,345"`).
String _formatThousands(int n) {
  final s = n.toString();
  if (s.length <= 3) return s;
  final buf = StringBuffer();
  var count = 0;
  for (var i = s.length - 1; i >= 0; i--) {
    buf.write(s[i]);
    count++;
    if (count == 3 && i > 0) {
      buf.write(',');
      count = 0;
    }
  }
  return buf.toString().split('').reversed.join();
}

// ── HEART — stacked zones bar ───────────────────────────────────────────────

/// Heart shard — stacked zone bar. [HeartDaySummary] has no per-zone
/// minute breakdown today, so the map is always empty and the bar draws
/// its dim placeholder. When the backend adds zone minutes we just
/// populate the map here.
class _HeartShard extends ConsumerWidget {
  const _HeartShard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // HeartDaySummary does not expose per-zone minutes yet — empty map
    // intentional. ZHeartZonesBar renders a dim placeholder in that case.
    const zones = <ZHeartZone, int>{};
    return _ShardFrame(
      name: 'Heart zones',
      chart: SizedBox(
        width: double.infinity,
        child: ZHeartZonesBar(
          minutes: zones,
          categoryColor: categoryColor(HealthCategory.heart),
          height: 10,
          radius: 5,
        ),
      ),
      value: '—',
    );
  }
}

// ── FOOD — macros donut ─────────────────────────────────────────────────────

/// Food shard — concentric macros donut (protein / carbs / fat) with
/// today's total calories as the hero value.
class _FoodShard extends ConsumerWidget {
  const _FoodShard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nut = ref.watch(nutritionDaySummaryProvider).maybeWhen(
          data: (d) => d,
          orElse: () => null,
        );
    final protein = nut?.totalProteinG ?? 0.0;
    final carbs = nut?.totalCarbsG ?? 0.0;
    final fat = nut?.totalFatG ?? 0.0;
    final calories = nut?.totalCalories ?? 0;
    return _ShardFrame(
      name: 'Macros',
      chart: SizedBox(
        width: 48,
        height: 48,
        child: ZMacroDonut(
          proteinGrams: protein,
          carbsGrams: carbs,
          fatGrams: fat,
          categoryColor: categoryColor(HealthCategory.nutrition),
          size: 48,
          strokeWidth: 6,
        ),
      ),
      value: calories == 0 ? '—' : _formatThousands(calories),
      unit: calories == 0 ? null : 'kcal',
    );
  }
}

// ── BODY — BMI gauge ────────────────────────────────────────────────────────

/// Body shard — semicircle BMI gauge computed from profile height and the
/// latest weight reading. Renders an em-dash when either piece is missing.
class _BodyShard extends ConsumerWidget {
  const _BodyShard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final heightCm = profile?.heightCm;
    final bodyDetail = ref.watch(categoryDetailProvider(
      const CategoryDetailParams(categoryId: 'body', timeRange: '7D'),
    ));
    final weightKg = bodyDetail.maybeWhen(
      data: (d) {
        for (final m in d.metrics) {
          if (m.metricId == 'weight') {
            final vals = m.dataPoints
                .map((p) => p.value)
                .where((v) => v.isFinite)
                .toList();
            return vals.isEmpty ? null : vals.last;
          }
        }
        return null;
      },
      orElse: () => null,
    );
    double? bmi;
    if (heightCm != null && heightCm > 0 && weightKg != null) {
      final m = heightCm / 100.0;
      bmi = weightKg / (m * m);
    }
    return _ShardFrame(
      name: 'BMI',
      chart: SizedBox(
        width: 64,
        height: 40,
        child: bmi == null
            ? const Center(
                child: Text('—', style: TextStyle(color: Colors.white38)),
              )
            : ZBmiGauge(bmi: bmi, size: 64, strokeWidth: 5),
      ),
      value: bmi == null ? '—' : bmi.toStringAsFixed(1),
      unit: bmi == null ? null : 'healthy',
    );
  }
}

// ── MIND — mood / energy / stress dots ──────────────────────────────────────

/// Mind shard — three dots on a 1–10 strip for mood, energy, and stress.
/// Hero value is the average of whichever readings are present today.
class _MindShard extends ConsumerWidget {
  const _MindShard({required this.range});
  final _AllDataRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wellness = ref.watch(categoryDetailProvider(CategoryDetailParams(
      categoryId: HealthCategory.wellness.name,
      timeRange: range.providerRange,
    )));
    int? readLast(String id) {
      return wellness.maybeWhen(
        data: (d) {
          for (final m in d.metrics) {
            if (m.metricId == id) {
              final vals = m.dataPoints
                  .map((p) => p.value)
                  .where((v) => v.isFinite)
                  .toList();
              return vals.isEmpty ? null : vals.last.round();
            }
          }
          return null;
        },
        orElse: () => null,
      );
    }

    final mood = readLast('mood');
    final energy = readLast('energy');
    final stress = readLast('stress');
    final present = [mood, energy, stress].whereType<int>().toList();
    final avg =
        present.isEmpty ? null : present.reduce((a, b) => a + b) / present.length;
    return _ShardFrame(
      name: 'How you feel',
      chart: ZMoodEnergyStressDots(
        mood: mood,
        energy: energy,
        stress: stress,
      ),
      value: avg == null ? '—' : avg.toStringAsFixed(1),
      unit: avg == null ? null : 'avg',
    );
  }
}
