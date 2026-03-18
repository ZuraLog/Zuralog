/// Zuralog — Metric Picker Screen.
///
/// Full-screen wrapper around [MetricPickerSheet] that pushes over the app
/// shell (including the bottom navigation bar), matching the presentation style
/// of the other log screens (Run, Sleep, Meal, etc.).
///
/// Navigation: pushed via `context.pushNamed(RouteNames.metricPicker, extra: pinnedTypes)`.
/// On selection: calls [pinnedMetricsProvider.notifier].addMetric() then pops.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/today/providers/today_providers.dart';
import 'package:zuralog/shared/widgets/metric_grid/metric_picker_sheet.dart';

// ── MetricPickerScreen ────────────────────────────────────────────────────────

/// Full-screen metric picker — pushed over the shell so the bottom nav bar
/// is hidden, matching the Run / Sleep / Meal log screen presentation.
///
/// Accepts [pinnedTypes] via GoRouter's `extra` parameter (a `Set<String>`).
/// When the user selects a metric, it is added to [pinnedMetricsProvider]
/// and the screen pops automatically.
class MetricPickerScreen extends ConsumerWidget {
  const MetricPickerScreen({
    super.key,
    required this.pinnedTypes,
  });

  /// The set of metric type strings already pinned to the Today grid.
  /// Passed in from the caller via GoRouter `extra`.
  final Set<String> pinnedTypes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
          tooltip: 'Close',
        ),
        title: Text(
          'Add a metric',
          style: AppTextStyles.titleMedium.copyWith(
            color: colors.textPrimary,
          ),
        ),
      ),
      body: MetricPickerSheet(
        pinnedTypes: pinnedTypes,
        onSelect: (type) {
          ref.read(pinnedMetricsProvider.notifier).addMetric(type);
          context.pop();
        },
      ),
    );
  }
}
