library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zuralog/shared/widgets/charts/interactions/chart_tooltip.dart';

/// Model describing a tapped segment or zone.
class SegmentInfo {
  const SegmentInfo({
    required this.label,
    required this.value,
    required this.unit,
    required this.percentage,
    required this.tapOffset,
  });

  final String label;
  final double value;
  final String unit;

  /// 0.0–1.0 fraction of total. Pass 0.0 when not applicable (gauge zones).
  final double percentage;

  /// Local tap position within the chart widget — for tooltip placement.
  final Offset tapOffset;
}

/// Wraps a chart widget and shows a [ZChartTooltip] when the shell reports
/// a tapped segment via [notifier].
///
/// Auto-dismisses after 3 seconds. Tap on empty area also clears the tooltip.
class SegmentTapHandler extends StatefulWidget {
  const SegmentTapHandler({
    super.key,
    required this.child,
    required this.notifier,
  });

  final Widget child;

  /// Shell-owned notifier. Set to a [SegmentInfo] on tap, null to clear.
  final ValueNotifier<SegmentInfo?> notifier;

  @override
  State<SegmentTapHandler> createState() => _SegmentTapHandlerState();
}

class _SegmentTapHandlerState extends State<SegmentTapHandler> {
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    widget.notifier.addListener(_onNotifierChange);
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    widget.notifier.removeListener(_onNotifierChange);
    super.dispose();
  }

  void _onNotifierChange() {
    _dismissTimer?.cancel();
    if (widget.notifier.value != null) {
      _dismissTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) widget.notifier.value = null;
      });
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.notifier.value;

    return GestureDetector(
      onTap: info != null ? () => widget.notifier.value = null : null,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          if (info != null)
            Positioned(
              left: (info.tapOffset.dx - 56).clamp(0.0, double.infinity),
              top: (info.tapOffset.dy - 80).clamp(0.0, double.infinity),
              child: _TooltipLabel(info: info),
            ),
        ],
      ),
    );
  }
}

class _TooltipLabel extends StatelessWidget {
  const _TooltipLabel({required this.info});
  final SegmentInfo info;

  @override
  Widget build(BuildContext context) {
    final pct =
        info.percentage > 0 ? ' (${(info.percentage * 100).round()}%)' : '';
    return ZChartTooltip(
      value: info.value,
      unit: info.unit,
      label: '${info.label}$pct',
    );
  }
}

/// Reports a tapped segment: fires haptic feedback and writes [info] to [notifier].
void reportSegmentTap(
  ValueNotifier<SegmentInfo?> notifier,
  SegmentInfo info,
) {
  HapticFeedback.lightImpact();
  notifier.value = info;
}
