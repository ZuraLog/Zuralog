/// Subscription Screen.
///
/// Current plan display, Pro upgrade CTA, restore purchases, billing history.
/// Rebuild of the RevenueCat paywall. Full implementation: Phase 8, Task 8.8.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/settings/presentation/widgets/settings_section_label.dart';
import 'package:zuralog/features/subscription/domain/subscription_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── Local providers ────────────────────────────────────────────────────────────

/// Whether the user currently has a Pro subscription.
/// Mock default: free plan.
final _isProProvider = StateProvider<bool>((_) => false);

// ── SubscriptionSettingsScreen ─────────────────────────────────────────────────

/// Subscription management: current plan, Pro upgrade CTA, restore, billing.
class SubscriptionSettingsScreen extends ConsumerWidget {
  /// Creates the [SubscriptionSettingsScreen].
  const SubscriptionSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = ref.watch(_isProProvider);

    return ZuralogScaffold(
      appBar: const ZuralogAppBar(title: 'Subscription', showProfileAvatar: false),
      body: ListView(
        children: [
          const SettingsSectionLabel('Current Plan'),
          _CurrentPlanCard(isPro: isPro),

          if (!isPro) ...[
            const SettingsSectionLabel('Upgrade'),
            _UpgradeCard(
              onUpgradeTap: () => _showSnackBar(context, 'Redirecting to payment\u2026'),
            ),
          ],

          const SettingsSectionLabel('Manage'),
          ZSettingsGroup(
            tiles: [
              ZSettingsTile(
                icon: Icons.restore_rounded,
                iconColor: AppColors.categoryActivity,
                title: 'Restore Purchases',
                subtitle: 'Already purchased? Restore your subscription',
                onTap: () => _showSnackBar(context, 'Checking your purchases\u2026'),
              ),
              ZSettingsTile(
                icon: Icons.receipt_rounded,
                iconColor: AppColors.categoryVitals,
                title: 'Billing History',
                subtitle: 'View past invoices and receipts',
                onTap: () => _showSnackBar(context, 'Loading billing history\u2026'),
              ),
            ],
          ),

          const SizedBox(height: AppDimens.spaceXxl),
        ],
      ),
    );
  }
}

// ── _CurrentPlanCard ───────────────────────────────────────────────────────────

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({required this.isPro});

  final bool isPro;

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
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plan badge + name row
            Row(
              children: [
                _PlanBadge(isPro: isPro),
                const SizedBox(width: AppDimens.spaceSm),
                Text(
                  isPro ? 'ZuraLog Pro' : 'ZuraLog Free',
                  style: AppTextStyles.titleMedium
                      .copyWith(color: colors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceMd),

            // Feature list
            const _FeatureItem(
              icon: Icons.check_rounded,
              iconColor: AppColors.categoryActivity,
              label: 'Up to 3 integrations',
            ),
            const SizedBox(height: AppDimens.spaceSm),
            const _FeatureItem(
              icon: Icons.check_rounded,
              iconColor: AppColors.categoryActivity,
              label: '7-day data history',
            ),
            const SizedBox(height: AppDimens.spaceSm),
            const _FeatureItem(
              icon: Icons.close_rounded,
              iconColor: AppColors.textTertiary,
              label: 'AI Coach (limited)',
              dimmed: true,
            ),
            const SizedBox(height: AppDimens.spaceMd),

            // Renewal info
            Text(
              'Free forever \u2014 no credit card required',
              style: AppTextStyles.bodySmall
                  .copyWith(color: colors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _PlanBadge ─────────────────────────────────────────────────────────────────

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({required this.isPro});

  final bool isPro;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final backgroundColor = isPro
        ? colors.primary.withValues(alpha: 0.2)
        : colors.border.withValues(alpha: 0.6);
    final textColor = isPro ? colors.primary : colors.textTertiary;
    final label = isPro ? 'Pro' : 'Free';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceSm,
        vertical: AppDimens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodySmall.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ── _FeatureItem ───────────────────────────────────────────────────────────────

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.dimmed = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Row(
      children: [
        Icon(icon, size: AppDimens.iconSm, color: iconColor),
        const SizedBox(width: AppDimens.spaceSm),
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: dimmed
                ? colors.textTertiary
                : colors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ── _UpgradeCard ───────────────────────────────────────────────────────────────

class _UpgradeCard extends ConsumerWidget {
  const _UpgradeCard({required this.onUpgradeTap});

  final VoidCallback onUpgradeTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColorsOf(context);
    final offeringsAsync = ref.watch(offeringsProvider);
    final offerings = offeringsAsync.valueOrNull;
    final current = offerings?.current;
    final monthlyPackage = current?.monthly;
    final annualPackage = current?.annual;
    final monthlyPrice = monthlyPackage?.storeProduct.priceString ?? r'$9.99';
    final annualPrice = annualPackage?.storeProduct.priceString ?? r'$79.99';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: icon + title
            Row(
              children: [
                const ZIconBadge(
                  icon: Icons.workspace_premium_rounded,
                  color: AppColors.categoryNutrition,
                  size: 40,
                  iconSize: 22,
                ),
                const SizedBox(width: AppDimens.spaceSm),
                Text(
                  'ZuraLog Pro',
                  style: AppTextStyles.titleMedium
                      .copyWith(color: colors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceMd),

            // Price — fetched from RevenueCat at runtime; falls back to
            // locale-neutral defaults when RC is unavailable.
            Text(
              '$monthlyPrice / month',
              style:
                  AppTextStyles.displaySmall.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: AppDimens.spaceXs),
            Text(
              'or $annualPrice/year (save 33%)',
              style: AppTextStyles.bodySmall
                  .copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppDimens.spaceMd),

            // Pro features
            const _FeatureItem(
              icon: Icons.check_rounded,
              iconColor: AppColors.categoryActivity,
              label: 'Unlimited integrations',
            ),
            const SizedBox(height: AppDimens.spaceSm),
            const _FeatureItem(
              icon: Icons.check_rounded,
              iconColor: AppColors.categoryActivity,
              label: 'Full data history',
            ),
            const SizedBox(height: AppDimens.spaceSm),
            const _FeatureItem(
              icon: Icons.check_rounded,
              iconColor: AppColors.categoryActivity,
              label: 'Unlimited AI Coach',
            ),
            const SizedBox(height: AppDimens.spaceSm),
            const _FeatureItem(
              icon: Icons.check_rounded,
              iconColor: AppColors.categoryActivity,
              label: 'Priority support',
            ),
            const SizedBox(height: AppDimens.spaceLg),

            // CTA button
            ZButton(
              label: 'Upgrade to Pro',
              onPressed: onUpgradeTap,
            ),
            const SizedBox(height: AppDimens.spaceSm),

            // Cancel anytime caption
            Center(
              child: Text(
                'Cancel anytime',
                style: AppTextStyles.bodySmall
                    .copyWith(color: colors.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

void _showSnackBar(BuildContext context, String message) {
  final colors = AppColorsOf(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: AppTextStyles.bodyMedium.copyWith(
          color: colors.textPrimary,
        ),
      ),
      backgroundColor: colors.surface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      ),
      duration: const Duration(seconds: 3),
    ),
  );
}
