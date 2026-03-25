library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';

class FillGaugeViz extends StatelessWidget {
  const FillGaugeViz({
    super.key,
    required this.config,
    required this.color,
    required this.size,
  });

  final FillGaugeConfig config;
  final Color color;
  final TileSize size;

  double get _fillRatio => (config.value / config.maxValue).clamp(0.0, 1.0);
  String get _valueLabel => '${config.value} ${config.unit}';

  @override
  Widget build(BuildContext context) {
    return switch (size) {
      TileSize.square => _buildSquare(),
      TileSize.wide   => _buildWide(),
      TileSize.tall   => _buildTall(),
    };
  }

  Widget _buildTank(double width, double height) {
    return SizedBox(
      width: width,
      height: height,
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
            height: (height - 3) * _fillRatio,
            child: Container(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.7),
                borderRadius: BorderRadius.only(
                  bottomLeft: const Radius.circular(3),
                  bottomRight: const Radius.circular(3),
                  topLeft: _fillRatio > 0.95 ? const Radius.circular(3) : Radius.zero,
                  topRight: _fillRatio > 0.95 ? const Radius.circular(3) : Radius.zero,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSquare() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTank(26, 54),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_valueLabel, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            Text('/ ${config.maxValue} ${config.unit}', style: const TextStyle(fontSize: 9, color: AppColors.textSecondaryDark)),
          ],
        ),
      ],
    );
  }

  Widget _buildWide() {
    final iconCount = config.unitSize != null ? (config.value / config.unitSize!).floor() : 0;
    final totalIcons = config.unitSize != null ? (config.maxValue / config.unitSize!).ceil() : 0;
    return Row(
      children: [
        _buildTank(26, 54),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_valueLabel, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
              if (config.unitIcon != null && config.unitSize != null) ...[
                const SizedBox(height: 4),
                Wrap(
                  children: List.generate(totalIcons, (i) =>
                    Text(config.unitIcon!, style: TextStyle(
                      fontSize: 14,
                      color: i < iconCount ? AppColors.categorySleep : AppColors.borderLight,
                    )),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTall() {
    final iconCount = config.unitSize != null ? (config.value / config.unitSize!).floor() : 0;
    final totalIcons = config.unitSize != null ? (config.maxValue / config.unitSize!).ceil() : 0;
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        _buildTank(34, 90),
        const SizedBox(height: 8),
        Text(_valueLabel, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        if (config.unitIcon != null && config.unitSize != null) ...[
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.center,
            children: List.generate(totalIcons, (i) =>
              Text(config.unitIcon!, style: TextStyle(
                fontSize: 16,
                color: i < iconCount ? Colors.blue : Colors.grey[300],
              )),
            ),
          ),
        ],
      ],
    );
  }
}
