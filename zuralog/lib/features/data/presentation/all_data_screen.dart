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
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zuralog/core/di/providers.dart';
import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/core/widgets/shimmer.dart';
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

  /// Key attached to the every-metric grid so the "All metrics ↓" link can
  /// scroll it into view.
  final GlobalKey _gridKey = GlobalKey();

  /// SharedPreferences key for the last successful sync timestamp.
  static const _kLastSyncKey = 'health_last_sync_at';

  /// SharedPreferences key for the Apple Health integration connection flag.
  /// Mirrors the key used by `health_dashboard_screen.dart` — do not change.
  static const _kAppleHealthKey = 'integration_connected_apple_health';

  /// SharedPreferences key for the Google Health Connect integration flag.
  /// Mirrors the key used by `health_dashboard_screen.dart` — do not change.
  static const _kHealthConnectKey =
      'integration_connected_google_health_connect';

  /// Optimistic "at least one source is connected" flag. Flipped by
  /// [_checkHealthSources] after the first [SharedPreferences] read. Starts
  /// `true` so the page renders normally during the first frame instead of
  /// flashing the empty-state CTA.
  bool _hasAnySource = true;

  /// `true` once the first [_checkHealthSources] call completes. The empty
  /// state renders only when this is `true` AND [_hasAnySource] is `false`.
  bool _checkedSources = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _checkHealthSources();
  }

  /// Reads the two integration flags from [SharedPreferences] and flips
  /// [_hasAnySource] / [_checkedSources]. Safe to re-run — used after
  /// pull-to-refresh in case the user connected a source via the CTA.
  Future<void> _checkHealthSources() async {
    final prefs = await SharedPreferences.getInstance();
    final apple = prefs.getBool(_kAppleHealthKey) ?? false;
    final hc = prefs.getBool(_kHealthConnectKey) ?? false;
    if (!mounted) return;
    setState(() {
      _hasAnySource = apple || hc;
      _checkedSources = true;
    });
  }

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
            SliverToBoxAdapter(
              child: _MandalaSection(
                range: _range,
                onMetricTap: _openMicroscopeById,
              ),
            ),
            SliverToBoxAdapter(
              child: _Legend(
                onCategoryTap: (cat) => _openMicroscopeById(
                  _primaryMetricFor(cat),
                  hint: cat,
                ),
              ),
            ),
            if (_checkedSources && !_hasAnySource)
              _buildEmptyStateSliver(context)
            else ...[
              SliverToBoxAdapter(
                child: _AiSummarySection(
                  range: _range,
                  onMetricTap: _openMicroscopeById,
                  onSectionTap: (section) => _openMicroscopeById(
                    section.primaryMetricId,
                    hint: section.category,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _ShardsSection(
                  range: _range,
                  onShardTap: (cat) => _openMicroscopeById(
                    _primaryMetricFor(cat),
                    hint: cat,
                  ),
                  onAllMetricsTap: _jumpToGrid,
                ),
              ),
              SliverToBoxAdapter(
                child: _EveryMetricSection(
                  range: _range,
                  gridKey: _gridKey,
                  onTileTap: (loc) => _openMicroscope(context, loc),
                ),
              ),
            ],
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

  /// Single-sliver "Connect a source" feature card shown in place of the AI
  /// summary / shards / every-metric grid when the user has no health
  /// integration connected. The wheel above stays visible as an outline so
  /// the user still sees how the data would be laid out.
  Widget _buildEmptyStateSliver(BuildContext context) {
    final colors = AppColorsOf(context);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppDimens.spaceMd, AppDimens.spaceMd, AppDimens.spaceMd, 0),
        child: ZuralogCard(
          variant: ZCardVariant.feature,
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Connect a source',
                style: AppTextStyles.titleMedium.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppDimens.spaceXs),
              Text(
                'Link Apple Health, Health Connect, or a wearable so we can '
                'fill in your picture — every category, every day.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              ZPatternPillButton(
                icon: Icons.add_rounded,
                label: 'Connect a source',
                onPressed: () =>
                    context.push(RouteNames.settingsIntegrationsPath),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pull-to-refresh handler. Mirrors the pattern used by
  /// `_HealthDashboardScreenState._onRefresh` in `health_dashboard_screen.dart`
  /// so both screens stay in lock-step: syncs connected sources, priming the
  /// server cache, then invalidates every provider the screen reads. Also
  /// re-checks the integration flags so the empty-state CTA can unlock if
  /// the user connected a source mid-session.
  Future<void> _onRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    final appleConnected = prefs.getBool(_kAppleHealthKey) ?? false;
    final hcConnected = prefs.getBool(_kHealthConnectKey) ?? false;

    if (appleConnected || hcConnected) {
      final syncService = ref.read(healthSyncServiceProvider);
      final synced = await syncService.syncToCloud(days: 7);
      if (synced) {
        await prefs.setInt(
            _kLastSyncKey, DateTime.now().millisecondsSinceEpoch);
      }
      if (!synced && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't refresh — pull down to try again."),
            duration: Duration(seconds: 3),
          ),
        );
      }
      // Prime the server cache with fresh data before invalidating the
      // providers so the next read sees post-sync data.
      await ref.read(dataRepositoryProvider).getDashboard(forceRefresh: true);
    }

    ref.invalidate(dashboardProvider);
    ref.invalidate(healthScoreProvider);
    for (final cat in kMandalaCategoryOrder) {
      ref.invalidate(categoryDetailProvider(CategoryDetailParams(
        categoryId: cat.name,
        timeRange: _range.providerRange,
      )));
    }

    // Re-check the integration flags so the empty-state CTA can clear
    // itself if the user just connected a source from the CTA button.
    if (mounted) {
      await _checkHealthSources();
    }
  }

  /// Scrolls the every-metric grid into view. No-op if the grid has not
  /// been laid out yet (for example, on the very first frame before any
  /// category provider has resolved).
  void _jumpToGrid() {
    final ctx = _gridKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  /// Resolves a metric by id from the currently-watched category providers
  /// and opens the universal microscope sheet. If [hint] is supplied we
  /// check that category first; otherwise we scan the full mandala order.
  void _openMicroscopeById(String metricId, {HealthCategory? hint}) {
    final loc = _locateMetric(ref, _range, metricId, hintCategory: hint);
    if (loc == null) return;
    _openMicroscope(context, loc);
  }

  /// Opens the [ZMetricMicroscopeSheet] for a located metric.
  Future<void> _openMicroscope(
    BuildContext context,
    _MetricLocator loc,
  ) async {
    final values = loc.metric.dataPoints
        .map((p) => p.value)
        .where((v) => v.isFinite)
        .toList();
    final todayValue = values.isEmpty ? null : values.last;
    final baseline = values.isEmpty
        ? null
        : values.reduce((a, b) => a + b) / values.length;
    final lastTimestamp = loc.metric.dataPoints.isEmpty
        ? null
        : DateTime.tryParse(loc.metric.dataPoints.last.timestamp);
    await showZMetricMicroscopeSheet(
      context,
      metricId: loc.metricId,
      category: loc.category,
      displayName: loc.metric.displayName,
      unit: loc.metric.unit,
      todayValue: todayValue,
      baseline30d: baseline,
      inverted: kInvertedMetricIds.contains(loc.metricId),
      dataPoints: loc.metric.dataPoints,
      lastReadingTime: lastTimestamp,
      onAskCoach: () {
        Navigator.of(context).pop();
        // Coach navigation: push the Coach route. Pre-fill is a follow-up.
        context.push(RouteNames.coachPath);
      },
    );
  }
}

/// Locator for the microscope sheet — pairs a metric id with the enclosing
/// category and the full [MetricSeries] so the sheet has everything it
/// needs without re-querying the provider.
class _MetricLocator {
  const _MetricLocator({
    required this.metricId,
    required this.category,
    required this.metric,
  });
  final String metricId;
  final HealthCategory category;
  final MetricSeries metric;
}

/// Finds a metric by id in the currently-watched category providers. We
/// check [hintCategory] first when supplied so spoke/shard taps — which
/// already know their own category — resolve in O(1) instead of scanning
/// the whole mandala. Returns `null` if the metric is not present.
_MetricLocator? _locateMetric(
  WidgetRef ref,
  _AllDataRange range,
  String metricId, {
  HealthCategory? hintCategory,
}) {
  final categories = <HealthCategory>[
    ?hintCategory,
    ...kMandalaCategoryOrder,
  ];
  for (final cat in categories) {
    final detail = ref.read(categoryDetailProvider(CategoryDetailParams(
      categoryId: cat.name,
      timeRange: range.providerRange,
    )));
    final found = detail.maybeWhen(
      data: (d) {
        for (final m in d.metrics) {
          if (m.metricId == metricId) {
            return _MetricLocator(
              metricId: metricId,
              category: cat,
              metric: m,
            );
          }
        }
        return null;
      },
      orElse: () => null,
    );
    if (found != null) return found;
  }
  return null;
}

/// Primary metric id for each mandala category — used by shard card taps
/// and legend dot taps, which don't carry a metric of their own.
String _primaryMetricFor(HealthCategory cat) {
  switch (cat) {
    case HealthCategory.sleep:
      return 'sleep_duration';
    case HealthCategory.activity:
      return 'steps';
    case HealthCategory.heart:
      return 'resting_heart_rate';
    case HealthCategory.nutrition:
      return 'calories';
    case HealthCategory.body:
      return 'weight';
    case HealthCategory.wellness:
      return 'mood';
    case HealthCategory.vitals:
      return 'spo2';
    case HealthCategory.cycle:
      return 'cycle_day';
    case HealthCategory.mobility:
      return 'walking_speed';
    case HealthCategory.environment:
      return 'temperature';
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
  const _MandalaSection({
    required this.range,
    required this.onMetricTap,
  });
  final _AllDataRange range;
  final void Function(String metricId, {HealthCategory? hint}) onMetricTap;

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
        onSpokeTap: (id) => onMetricTap(id),
        onCenterTap: () {
          context.push(RouteNames.dataScoreBreakdownPath);
        },
      ),
    );
  }
}

/// Compact legend that wraps under the mandala.
///
/// Each entry is tappable — tapping opens the microscope sheet on that
/// category's primary metric via [onCategoryTap].
class _Legend extends StatelessWidget {
  const _Legend({required this.onCategoryTap});
  final ValueChanged<HealthCategory> onCategoryTap;

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
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onCategoryTap(e.$2),
              child: Row(
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
            ),
        ],
      ),
    );
  }
}

/// Reusable shimmer card used as a loading placeholder for the AI summary,
/// shard slots, and every-metric tiles.
///
/// Renders as an opaque rounded surface with a smaller inner rectangle
/// wrapped in [AppShimmer] so the sweep shows as a soft highlight bar
/// rather than over the full card edge. [height] controls the outer card;
/// the inner shimmer rectangle fills whatever space the card provides
/// minus `AppDimens.spaceMd` of margin.
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.height});
  final double height;
  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: AppShimmer(
        child: Container(
          margin: const EdgeInsets.all(AppDimens.spaceMd),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
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
  const _AiSummarySection({
    required this.range,
    required this.onMetricTap,
    required this.onSectionTap,
  });
  final _AllDataRange range;

  /// Fires when the user taps a highlighted metric span in the summary
  /// body. Opens the microscope on that metric.
  final void Function(String metricId, {HealthCategory? hint}) onMetricTap;

  /// Fires when the user taps a section row in the expanded breakdown.
  /// Opens the microscope on that section's primary metric.
  final ValueChanged<AllDataSummarySection> onSectionTap;

  @override
  ConsumerState<_AiSummarySection> createState() => _AiSummarySectionState();
}

class _AiSummarySectionState extends ConsumerState<_AiSummarySection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    // Loading skeleton: render a shimmer card while NONE of the six
    // mandala-category detail providers have resolved yet. Without this
    // gate, [AllDataSummaryGenerator] sees zero spokes and emits the
    // "not enough data yet — connect a tracker" copy, which is wrong on
    // first load when the provider just hasn't answered yet.
    final anyResolved = kMandalaCategoryOrder.any((cat) {
      return ref
          .watch(categoryDetailProvider(CategoryDetailParams(
            categoryId: cat.name,
            timeRange: widget.range.providerRange,
          )))
          .hasValue;
    });
    if (!anyResolved) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(
            AppDimens.spaceMd, AppDimens.spaceMd, AppDimens.spaceMd, 0),
        child: _SkeletonCard(height: 100),
      );
    }

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
            onMetricTap: (id) => widget.onMetricTap(id),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: AppDimens.spaceSm),
                    child: ZAiBreakdownCard(
                      summary: summary,
                      onSectionTap: widget.onSectionTap,
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
  const _ShardsSection({
    required this.range,
    required this.onShardTap,
    required this.onAllMetricsTap,
  });
  final _AllDataRange range;

  /// Fires when the user taps a shard card. Opens the microscope on that
  /// category's primary metric.
  final ValueChanged<HealthCategory> onShardTap;

  /// Fires when the user taps the "All metrics ↓" link. Scrolls the
  /// every-metric grid into view.
  final VoidCallback onAllMetricsTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget wrap(HealthCategory cat, Widget child) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onShardTap(cat),
        child: child,
      );
    }

    // Loading skeleton: same 3×2 grid footprint, but each tile is a
    // `_SkeletonCard` while none of the category detail providers have
    // resolved yet. Keeps the spotlight header visible so the page doesn't
    // jump when the real shards swap in.
    final anyResolved = kMandalaCategoryOrder.any((cat) {
      return ref
          .watch(categoryDetailProvider(CategoryDetailParams(
            categoryId: cat.name,
            timeRange: range.providerRange,
          )))
          .hasValue;
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppDimens.spaceMd, AppDimens.spaceMd, AppDimens.spaceMd, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SpotlightHeader(onAllMetricsTap: onAllMetricsTap),
          const SizedBox(height: AppDimens.spaceXs),
          GridView.count(
            crossAxisCount: 3,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            childAspectRatio: 1 / 1.2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: anyResolved
                ? [
                    wrap(HealthCategory.sleep, const _SleepShard()),
                    wrap(HealthCategory.activity, _MoveShard(range: range)),
                    wrap(HealthCategory.heart, const _HeartShard()),
                    wrap(HealthCategory.nutrition, const _FoodShard()),
                    wrap(HealthCategory.body, const _BodyShard()),
                    wrap(HealthCategory.wellness, _MindShard(range: range)),
                  ]
                : List<Widget>.generate(
                    6,
                    (_) => const _SkeletonCard(height: 96),
                  ),
          ),
        ],
      ),
    );
  }
}

/// "TODAY'S SPOTLIGHT" eyebrow + tappable "All metrics ↓" link that scrolls
/// the every-metric grid into view.
class _SpotlightHeader extends StatelessWidget {
  const _SpotlightHeader({required this.onAllMetricsTap});
  final VoidCallback onAllMetricsTap;

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
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onAllMetricsTap,
          child: Text(
            'All metrics ↓',
            style: AppTextStyles.labelSmall.copyWith(
              color: colors.primary,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
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

// ── EVERY METRIC — full chart-only grid ─────────────────────────────────────

/// 3-column SliverGrid of chart-only tiles, one per tracked metric.
///
/// Iterates [kMandalaCategoryOrder] so tiles appear in mandala order
/// (Sleep → Move → Heart → Food → Body → Mind → …). Categories with zero
/// metrics in the current range are simply skipped — the grid keeps
/// rendering with whatever categories do have data.
class _EveryMetricSection extends ConsumerWidget {
  const _EveryMetricSection({
    required this.range,
    required this.gridKey,
    required this.onTileTap,
  });

  final _AllDataRange range;
  final GlobalKey gridKey;
  final ValueChanged<_MetricLocator> onTileTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiles = <Widget>[];
    var totalCount = 0;
    var anyResolved = false;
    for (final cat in kMandalaCategoryOrder) {
      final detail = ref.watch(categoryDetailProvider(CategoryDetailParams(
        categoryId: cat.name,
        timeRange: range.providerRange,
      )));
      if (detail.hasValue) anyResolved = true;
      final metrics = detail.maybeWhen(
        data: (d) => d.metrics,
        orElse: () => const <MetricSeries>[],
      );
      totalCount += metrics.length;
      for (final m in metrics) {
        tiles.add(_EveryMetricTile(
          metric: m,
          category: cat,
          onTap: () => onTileTap(_MetricLocator(
            metricId: m.metricId,
            category: cat,
            metric: m,
          )),
        ));
      }
    }
    // Loading skeleton: 12 shimmer tiles in the same 3-column grid while
    // none of the category detail providers have resolved. Once ANY
    // category resolves we fall through to the live grid — missing
    // categories simply contribute zero tiles.
    final showSkeleton = !anyResolved;
    return Padding(
      key: gridKey,
      padding: const EdgeInsets.fromLTRB(
          AppDimens.spaceMd, AppDimens.spaceMd, AppDimens.spaceMd, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EveryMetricHeader(count: totalCount),
          const SizedBox(height: AppDimens.spaceXs),
          GridView.count(
            crossAxisCount: 3,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            childAspectRatio: 0.85,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: showSkeleton
                ? List<Widget>.generate(
                    12,
                    (_) => const _SkeletonCard(height: 82),
                  )
                : tiles,
          ),
        ],
      ),
    );
  }
}

/// "EVERY METRIC" eyebrow + `N tracked` counter.
class _EveryMetricHeader extends StatelessWidget {
  const _EveryMetricHeader({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            'EVERY METRIC',
            style: AppTextStyles.labelSmall.copyWith(
              color: colors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Text(
          '$count tracked',
          style: AppTextStyles.labelSmall.copyWith(
            color: colors.textTertiary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

/// One tile in the every-metric grid — name, today's value, sparkline,
/// unit, and a simple today-vs-prior delta pill.
class _EveryMetricTile extends StatelessWidget {
  const _EveryMetricTile({
    required this.metric,
    required this.category,
    required this.onTap,
  });
  final MetricSeries metric;
  final HealthCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final color = categoryColor(category);
    final values = metric.dataPoints
        .map((p) => p.value)
        .where((v) => v.isFinite)
        .toList();
    final todayDouble = values.isEmpty ? null : values.last;
    final delta = _deltaPct(values);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ZuralogCard(
        variant: ZCardVariant.data,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              metric.displayName,
              style: AppTextStyles.labelSmall.copyWith(
                color: colors.textSecondary,
                fontSize: 7.5,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              todayDouble == null ? '—' : _formatTileValue(todayDouble),
              style: TextStyle(
                fontFamily: 'Lora',
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: colors.textPrimary,
                height: 1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            SizedBox(
              height: 16,
              child: values.length >= 2
                  ? ZMiniSparkline(
                      values: values,
                      todayIndex: values.length - 1,
                      color: color,
                      height: 16,
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    metric.unit,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: colors.textTertiary,
                      fontSize: 6.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _DeltaLabel(delta: delta),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Small coloured pill showing the today-vs-prior delta percent. Renders
/// a neutral dot when there isn't enough data to compute a delta.
class _DeltaLabel extends StatelessWidget {
  const _DeltaLabel({required this.delta});
  final double? delta;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    if (delta == null || !delta!.isFinite) {
      return Text(
        '·',
        style: AppTextStyles.labelSmall.copyWith(
          color: colors.textTertiary,
          fontSize: 7.5,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    final rounded = delta!.abs().round();
    if (rounded == 0) {
      return Text(
        '· 0%',
        style: AppTextStyles.labelSmall.copyWith(
          color: colors.textSecondary,
          fontSize: 7.5,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    final isUp = delta! > 0;
    final color = isUp ? colors.success : AppColors.categoryHeart;
    return Text(
      '${isUp ? "↑" : "↓"} $rounded%',
      style: AppTextStyles.labelSmall.copyWith(
        color: color,
        fontSize: 7.5,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// Computes a simple today-vs-earlier percent. Returns null when there
/// isn't enough data or the baseline is zero.
double? _deltaPct(List<double> values) {
  if (values.length < 2) return null;
  final today = values.last;
  final previous = values.sublist(0, values.length - 1);
  final baseline = previous.reduce((a, b) => a + b) / previous.length;
  if (baseline == 0 || !baseline.isFinite) return null;
  return ((today - baseline) / baseline) * 100.0;
}

/// Formats a numeric tile value — thousands-grouped for large integers,
/// one decimal for fractional values, no decimals otherwise.
String _formatTileValue(double v) {
  if (!v.isFinite) return '—';
  if (v.abs() >= 1000) return _formatThousands(v.round());
  if (v == v.truncateToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(1);
}
