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
import 'package:zuralog/shared/widgets/layout/zuralog_scaffold.dart';

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
      body: CustomScrollView(
        slivers: [
          // ── Large-title app bar ─────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 100,
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(
                left: AppDimens.spaceMd,
                bottom: 14,
              ),
              collapseMode: CollapseMode.parallax,
              title: Text(
                'Subscription',
                style:
                    AppTextStyles.displaySmall.copyWith(color: AppColors.textPrimaryDark),
              ),
            ),
          ),

          SliverList(
            delegate: SliverChildListDelegate([
              // ── CURRENT PLAN section ────────────────────────────────────────
              const _SectionHeader('CURRENT PLAN'),
              _CurrentPlanCard(isPro: isPro),

              // ── UPGRADE section ─────────────────────────────────────────────
              if (!isPro) ...[
                const _SectionHeader('UPGRADE'),
                _UpgradeCard(
                  onUpgradeTap: () => _showSnackBar(
                    context,
                    'Redirecting to payment\u2026',
                  ),
                ),
              ],

              // ── MANAGE section ──────────────────────────────────────────────
              const _SectionHeader('MANAGE'),
              _SettingsGroup(
                children: [
                  _TapRow(
                    icon: Icons.restore_rounded,
                    iconColor: AppColors.categoryActivity,
                    title: 'Restore Purchases',
                    subtitle: 'Already purchased? Restore your subscription',
                    onTap: () => _showSnackBar(
                      context,
                      'Checking your purchases\u2026',
                    ),
                  ),
                  const _Divider(),
                  _TapRow(
                    icon: Icons.receipt_rounded,
                    iconColor: AppColors.categoryVitals,
                    title: 'Billing History',
                    subtitle: 'View past invoices and receipts',
                    onTap: () => _showSnackBar(
                      context,
                      'Loading billing history\u2026',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppDimens.spaceXxl),
            ]),
          ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackgroundDark,
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
                  isPro ? 'Zuralog Pro' : 'Zuralog Free',
                  style: AppTextStyles.titleMedium
                      .copyWith(color: AppColors.textPrimaryDark),
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
                  .copyWith(color: AppColors.textTertiary),
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
    final backgroundColor = isPro
        ? AppColors.primary.withValues(alpha: 0.2)
        : AppColors.borderDark.withValues(alpha: 0.6);
    final textColor = isPro ? AppColors.primary : AppColors.textTertiary;
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
    return Row(
      children: [
        Icon(icon, size: AppDimens.iconSm, color: iconColor),
        const SizedBox(width: AppDimens.spaceSm),
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: dimmed
                ? AppColors.textTertiary
                : AppColors.textPrimaryDark,
          ),
        ),
      ],
    );
  }
}

// ── _UpgradeCard ───────────────────────────────────────────────────────────────

class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard({required this.onUpgradeTap});

  final VoidCallback onUpgradeTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackgroundDark,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: icon + title
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.categoryNutrition.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    size: 22,
                    color: AppColors.categoryNutrition,
                  ),
                ),
                const SizedBox(width: AppDimens.spaceSm),
                Text(
                  'Zuralog Pro',
                  style: AppTextStyles.titleMedium
                      .copyWith(color: AppColors.textPrimaryDark),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceMd),

            // Price
            // TODO(phase9): Replace with RevenueCat product pricing fetched
            // at runtime — prices vary by locale, currency, and promotions.
            Text(
              '\$9.99 / month',
              style:
                  AppTextStyles.displaySmall.copyWith(color: AppColors.textPrimaryDark),
            ),
            const SizedBox(height: AppDimens.spaceXs),
            Text(
              'or \$79.99/year (save 33%)',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
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
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onUpgradeTap,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.primaryButtonText,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimens.radiusButtonMd),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: AppDimens.spaceMd,
                  ),
                ),
                child: Text(
                  'Upgrade to Pro',
                  style: AppTextStyles.titleMedium
                      .copyWith(color: AppColors.primaryButtonText),
                ),
              ),
            ),
            const SizedBox(height: AppDimens.spaceSm),

            // Cancel anytime caption
            Center(
              child: Text(
                'Cancel anytime',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _SettingsGroup ─────────────────────────────────────────────────────────────

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackgroundDark,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        ),
        child: Column(children: children),
      ),
    );
  }
}

// ── _Divider ───────────────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 68),
      child: Container(
        height: 1,
        color: AppColors.borderDark.withValues(alpha: 0.5),
      ),
    );
  }
}

// ── _TapRow ────────────────────────────────────────────────────────────────────

class _TapRow extends StatefulWidget {
  const _TapRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_TapRow> createState() => _TapRowState();
}

class _TapRowState extends State<_TapRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _pressed
            ? AppColors.borderDark.withValues(alpha: 0.3)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: 14,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
              child: Icon(widget.icon, size: 20, color: widget.iconColor),
            ),
            const SizedBox(width: AppDimens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: AppTextStyles.bodyLarge
                        .copyWith(color: AppColors.textPrimaryDark),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: AppDimens.iconMd,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

// ── _SectionHeader ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceLg,
        AppDimens.spaceMd,
        AppDimens.spaceXs,
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textTertiary,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

void _showSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textPrimaryDark,
        ),
      ),
      backgroundColor: AppColors.surfaceDark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      ),
      duration: const Duration(seconds: 3),
    ),
  );
}
