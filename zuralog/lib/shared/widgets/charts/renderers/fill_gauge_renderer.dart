library;

import 'package:flutter/material.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';
import 'package:zuralog/shared/widgets/charts/chart_render_context.dart';

/// Renders a vertical fill-level tank visual with animated fill rise.
///
/// This widget owns only the tank graphic — no value text, unit icons,
/// or labels. The mode shell provides those.
class FillGaugeRenderer extends StatelessWidget {
  const FillGaugeRenderer({
    super.key,
    required this.config,
    required this.color,
    required this.renderCtx,
    required this.tankWidth,
    required this.tankHeight,
  });

  final FillGaugeConfig config;
  final Color color;
  final ChartRenderContext renderCtx;
  final double tankWidth;
  final double tankHeight;

  double get _fillRatio {
    if (config.maxValue == 0) return 0.0;
    return (config.value / config.maxValue).clamp(0.0, 1.0) *
        renderCtx.animationProgress;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: tankWidth,
      height: tankHeight,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 1.5),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 1.5,
            right: 1.5,
            height: (tankHeight - 3) * _fillRatio,
            child: Container(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.7),
                borderRadius: BorderRadius.only(
                  bottomLeft: const Radius.circular(3),
                  bottomRight: const Radius.circular(3),
                  topLeft: _fillRatio > 0.95
                      ? const Radius.circular(3)
                      : Radius.zero,
                  topRight: _fillRatio > 0.95
                      ? const Radius.circular(3)
                      : Radius.zero,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
