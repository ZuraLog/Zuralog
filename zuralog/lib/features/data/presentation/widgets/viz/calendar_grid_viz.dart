library;

import 'package:flutter/material.dart';
import 'package:zuralog/features/data/domain/data_models.dart';
import 'package:zuralog/features/data/domain/tile_visualization_config.dart';

class CalendarGridViz extends StatelessWidget {
  const CalendarGridViz({
    super.key,
    required this.config,
    required this.color,
    required this.size,
  });

  final CalendarGridConfig config;
  final Color color;
  final TileSize size;

  CalendarDay? get _today => config.days.isNotEmpty ? config.days.last : null;

  @override
  Widget build(BuildContext context) {
    return switch (size) {
      TileSize.square => _buildSquare(),
      TileSize.wide   => _buildWide(),
      TileSize.tall   => _buildTall(),
    };
  }

  Widget _buildSquare() {
    final today = _today;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Day ${today?.dayNumber ?? 1}',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
        ),
        if (today?.phase != null)
          Text(
            today!.phase!,
            style: TextStyle(fontSize: 9, color: today.phaseColor ?? color),
          ),
      ],
    );
  }

  Widget _buildWide() {
    return Wrap(
      spacing: 3,
      runSpacing: 3,
      children: config.days.map((day) {
        final isToday = day == config.days.last;
        return Container(
          width: isToday ? 12 : 9,
          height: isToday ? 12 : 9,
          decoration: BoxDecoration(
            color: (day.phaseColor ?? color).withOpacity(day.value),
            shape: BoxShape.circle,
            boxShadow: isToday ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 3)] : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTall() {
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
      children: config.days.map((day) {
        final isToday = day == config.days.last;
        return Container(
          decoration: BoxDecoration(
            color: (day.phaseColor ?? color).withOpacity(day.value),
            shape: BoxShape.circle,
            boxShadow: isToday ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 3)] : null,
          ),
          child: Center(
            child: Text(
              '${day.dayNumber}',
              style: TextStyle(
                fontSize: 7,
                color: Colors.white.withOpacity(0.9),
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
