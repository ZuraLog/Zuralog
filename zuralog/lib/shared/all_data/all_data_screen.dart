library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/features/subscription/domain/subscription_providers.dart';
import 'package:zuralog/shared/all_data/all_data_models.dart';
import 'package:zuralog/shared/widgets/cards/zuralog_card.dart';
import 'package:zuralog/shared/widgets/charts/chart_mode.dart';
import 'package:zuralog/shared/widgets/charts/chart_render_context.dart';
import 'package:zuralog/shared/widgets/charts/renderers/bar_renderer.dart';
import 'package:zuralog/shared/widgets/charts/renderers/line_renderer.dart';

class AllDataScreen extends ConsumerStatefulWidget {
  const AllDataScreen({super.key, required this.config});

  final AllDataSectionConfig config;

  @override
  ConsumerState<AllDataScreen> createState() => _AllDataScreenState();
}

class _AllDataScreenState extends ConsumerState<AllDataScreen> {
  static final _renderCtx = ChartRenderContext.fromMode(ChartMode.tall).copyWith(
    showAxes: true,
    showGrid: true,
    animationProgress: 1.0,
  );

  int _selectedTab = 0;
  String _range = '7d';
  late Future<List<AllDataDay>> _dataFuture;
  bool _showUpgradePrompt = false;

  static const _freeRange = '7d';

  @override
  void initState() {
    super.initState();
    _dataFuture = widget.config.fetchData(_range);
  }

  void _selectTab(int index) => setState(() => _selectedTab = index);

  void _selectRange(String range) {
    final isPremium = ref.read(isPremiumProvider);
    if (range != _freeRange && !isPremium) {
      setState(() => _showUpgradePrompt = true);
      return;
    }
    setState(() {
      _range = range;
      _showUpgradePrompt = false;
      _dataFuture = widget.config.fetchData(range);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(isPremiumProvider);
    if (isPremium && _showUpgradePrompt) {
      // Schedule so we don't call setState during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _showUpgradePrompt = false);
      });
    }
    final colors = AppColorsOf(context);
    final tabs = widget.config.tabs;
    final catColor = widget.config.categoryColor;
    final tab = tabs.isNotEmpty ? tabs[_selectedTab] : null;

    return Scaffold(
      backgroundColor: colors.canvas,
      body: CustomScrollView(
        slivers: [
        // ── App Bar ──────────────────────────────────────────────────────────
        SliverAppBar(
          pinned: true,
          title: Text('${widget.config.sectionTitle} — All Data'),
          backgroundColor: colors.surface,
          surfaceTintColor: Colors.transparent,
        ),

        SliverToBoxAdapter(child: SizedBox(height: AppDimens.spaceMd)),

        // ── Metric Tabs ───────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
              itemCount: tabs.length,
              itemBuilder: (context, index) {
                final t = tabs[index];
                final isSelected = index == _selectedTab;
                return GestureDetector(
                  onTap: () => _selectTab(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: AppDimens.spaceSm),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceMd,
                      vertical: AppDimens.spaceXs,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? catColor.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppDimens.shapeXs),
                      border: Border.all(
                        color: isSelected
                            ? catColor
                            : colors.textSecondary.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        t.label,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: isSelected ? catColor : colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        SliverToBoxAdapter(child: SizedBox(height: AppDimens.spaceMd)),

        // ── Chart Card ────────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            child: ZuralogCard(
              variant: ZCardVariant.data,
              child: tab == null
                  ? const SizedBox(
                      height: 120,
                      child: Center(child: Text('No metrics configured.')),
                    )
                  : FutureBuilder<List<AllDataDay>>(
                      future: _dataFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const SizedBox(
                            height: 140,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        if (snapshot.hasError) {
                          return SizedBox(
                            height: 120,
                            child: Center(
                              child: Text(
                                'Could not load data. Try again later.',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          );
                        }

                        final days = snapshot.data ?? [];
                        final hasValues =
                            days.any((d) => tab.valueExtractor(d) != null);

                        if (!hasValues) {
                          return SizedBox(
                            height: 120,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'No data for ${tab.label}',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                  if (tab.emptyStateSource != null) ...[
                                    const SizedBox(height: AppDimens.spaceXs),
                                    Text(
                                      tab.emptyStateSource!,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }

                        if (tab.chartType == AllDataChartType.bar) {
                          final bars = days
                              .map(
                                (d) => BarPoint(
                                  label: d.date.length >= 10
                                      ? d.date.substring(5)
                                      : d.date,
                                  value: tab.valueExtractor(d) ?? 0,
                                  isToday: d.isToday,
                                ),
                              )
                              .toList();
                          return SizedBox(
                            height: 200,
                            child: BarRenderer(
                              config: BarChartConfig(
                                bars: bars,
                                showAvgLine: true,
                              ),
                              color: catColor,
                              renderCtx: _renderCtx,
                              unit: tab.unit,
                            ),
                          );
                        } else {
                          final points = days
                              .where((d) => tab.valueExtractor(d) != null)
                              .map((d) {
                                return ChartPoint(
                                  date: DateTime.parse(d.date),
                                  value: tab.valueExtractor(d)!,
                                );
                              })
                              .toList();
                          return SizedBox(
                            height: 200,
                            child: LineRenderer(
                              config: LineChartConfig(points: points),
                              color: catColor,
                              renderCtx: _renderCtx,
                              unit: tab.unit,
                            ),
                          );
                        }
                      },
                    ),
            ),
          ),
        ),

        SliverToBoxAdapter(child: SizedBox(height: AppDimens.spaceMd)),

        // ── Range Selector ────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            child: _RangeSelector(
              selected: _range,
              catColor: catColor,
              onChanged: _selectRange,
            ),
          ),
        ),

        // ── Upgrade Prompt ────────────────────────────────────────────────────
        if (_showUpgradePrompt) ...[
          SliverToBoxAdapter(child: SizedBox(height: AppDimens.spaceMd)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
              child: _UpgradePromptCard(catColor: catColor),
            ),
          ),
        ],

        SliverToBoxAdapter(child: SizedBox(height: AppDimens.spaceMd)),

        // ── Personal Benchmark Placeholder ────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            child: _PlaceholderCard(
              title: 'Personal Benchmark',
              body:
                  'Building your baseline… keep logging to see your personal range.',
            ),
          ),
        ),

        SliverToBoxAdapter(child: SizedBox(height: AppDimens.spaceMd)),

        // ── Distribution Breakdown Placeholder ────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            child: _PlaceholderCard(
              title: 'Distribution',
              body:
                  'Building your baseline… keep logging to see your breakdown.',
            ),
          ),
        ),

        SliverToBoxAdapter(child: SizedBox(height: AppDimens.spaceLg)),
      ],
      ),
    );
  }
}

// ── Private widgets ────────────────────────────────────────────────────────────

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({
    required this.selected,
    required this.catColor,
    required this.onChanged,
  });

  final String selected;
  final Color catColor;
  final ValueChanged<String> onChanged;

  static const _ranges = ['7d', '30d', '3m', '6m', '1y'];

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Row(
      children: [
        for (var i = 0; i < _ranges.length; i++) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(_ranges[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceXs),
                decoration: BoxDecoration(
                  color: selected == _ranges[i]
                      ? catColor.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppDimens.shapeXs),
                  border: Border.all(
                    color: selected == _ranges[i]
                        ? catColor
                        : colors.textSecondary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    _ranges[i],
                    style: AppTextStyles.labelSmall.copyWith(
                      color: selected == _ranges[i]
                          ? catColor
                          : colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (i < _ranges.length - 1) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

class _UpgradePromptCard extends StatelessWidget {
  const _UpgradePromptCard({required this.catColor});

  final Color catColor;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return ZuralogCard(
      variant: ZCardVariant.feature,
      category: catColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unlock your full history with ZuraLog Pro',
            style: AppTextStyles.labelLarge.copyWith(
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppDimens.spaceXs),
          Text(
            'Free accounts see the last 7 days. Upgrade to explore 30 days, 3 months, 6 months, or a full year of your data.',
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return ZuralogCard(
      variant: ZCardVariant.data,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.labelLarge.copyWith(
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppDimens.spaceXs),
          Text(
            body,
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
