/// Zuralog Design System — Empty Insights State Card.
///
/// Shown on the Today feed when no AI insights exist yet.
/// Provides two CTAs: one to open the log sheet and one to connect an app.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// Empty state card shown when no AI insights are available yet.
///
/// [onLogTap] — called when the user taps "Log something today".
///   The caller should open the log grid sheet.
/// [onConnectTap] — called when the user taps "Connect a health app".
///   The caller should navigate to the integrations settings screen.
class ZEmptyInsightsCard extends StatelessWidget {
  const ZEmptyInsightsCard({
    super.key,
    required this.onLogTap,
    required this.onConnectTap,
  });

  final VoidCallback onLogTap;
  final VoidCallback onConnectTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.insights_rounded,
                size: AppDimens.iconMd,
                color: colors.primary,
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Text(
                'Your insights are on the way',
                style: AppTextStyles.titleMedium.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            'Log your health data and connect your apps — '
            'your AI coach will start generating personalised '
            'insights within 24 hours.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          _ActionRow(
            icon: Icons.edit_rounded,
            label: 'Log something today',
            onTap: onLogTap,
          ),
          const SizedBox(height: AppDimens.spaceSm),
          _ActionRow(
            icon: Icons.link_rounded,
            label: 'Connect a health app',
            onTap: onConnectTap,
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: AppDimens.iconSm, color: colors.primary),
            const SizedBox(width: AppDimens.spaceXs),
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right_rounded,
              size: AppDimens.iconSm,
              color: colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
