/// Zuralog Design System — Settings Group Widget.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/shared/widgets/list/z_settings_tile.dart';
import 'package:zuralog/core/theme/app_colors.dart';

/// A grouped list of [ZSettingsTile]s in a card container with dividers between items.
class ZSettingsGroup extends StatelessWidget {
  const ZSettingsGroup({super.key, required this.tiles});

  final List<ZSettingsTile> tiles;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        child: Column(
          children: [
            for (int i = 0; i < tiles.length; i++) ...[
              tiles[i],
              if (i < tiles.length - 1)
                Padding(
                  padding: const EdgeInsets.only(left: 68),
                  child: Container(
                    height: 1,
                    color: colors.border.withValues(alpha: 0.5),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
