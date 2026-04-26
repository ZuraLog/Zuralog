/// Zuralog — Post-Onboarding Paywall Screen.
///
/// A cinematic, conversion-focused paywall presented right after the chat
/// onboarding finishes. Anatomy borrows from the strongest fitness/wellness
/// paywalls (Strava Premium, AllTrails+, Whoop): a full-bleed hero photo
/// from the welcome library, a single bold promise, three outcome rows, an
/// annual-default plan picker, and a sticky bottom CTA.
///
/// Layout uses a conventional `Scaffold` + `ListView` + `bottomNavigationBar`
/// shape — no clever Stack overlays, no fade animations on body content —
/// so the screen paints correctly on first frame, every frame.
///
/// RevenueCat handles the real purchase via [presentPaywall]; "Maybe later"
/// skips to Today; already-Pro users skip the paywall entirely (handled at
/// the chat onboarding finale).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/subscription/data/subscription_repository.dart';
import 'package:zuralog/features/subscription/domain/subscription_providers.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

// ── Paywall constants ───────────────────────────────────────────────────────

const int _trialDays = 7;
const String _heroImage = 'assets/welcome/welcome_01.jpg';

const String _fallbackMonthlyPrice = r'$9.99';
const String _fallbackAnnualPrice = r'$59.99';
const String _fallbackAnnualPerMonth = r'$4.99';

/// Hide the social-proof line until we have honest numbers to show.
const bool _kShowSocialProof = false;

/// Default fixed hero height. Looks great on every iPhone size; on tablets
/// the photo simply fits to width.
const double _heroHeight = 380;

enum _PlanChoice { annual, monthly }

class OnboardingPaywallScreen extends ConsumerStatefulWidget {
  const OnboardingPaywallScreen({super.key});

  @override
  ConsumerState<OnboardingPaywallScreen> createState() =>
      _OnboardingPaywallScreenState();
}

class _OnboardingPaywallScreenState
    extends ConsumerState<OnboardingPaywallScreen> {
  bool _isWorking = false;
  _PlanChoice _selectedPlan = _PlanChoice.annual;

  Future<void> _startTrial() async {
    if (_isWorking) return;
    setState(() => _isWorking = true);
    try {
      // Source of truth: which card the user picked on _our_ paywall.
      final offeringsAsync = ref.read(offeringsProvider);
      final prices = _resolvePrices(offeringsAsync.valueOrNull);
      final selectedPackage = _selectedPlan == _PlanChoice.annual
          ? prices.annualPackage
          : prices.monthlyPackage;

      if (selectedPackage == null) {
        // No RevenueCat package available (offerings not loaded or RC not
        // configured yet). In debug builds, surface a clear preview-mode
        // message so the team can keep iterating on the UI; in release,
        // log to Sentry and show a friendly retry hint.
        if (kDebugMode) {
          await _showPreviewDialog(
            title: 'Preview mode',
            message:
                "RevenueCat hasn't loaded an offering for this build, so we "
                "can't open the real purchase sheet. Once your RC API key + "
                "products are wired up, this CTA will start the trial.",
          );
        } else {
          Sentry.captureMessage(
            'Paywall CTA pressed without RC offering available',
            level: SentryLevel.warning,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    "We couldn't reach the App Store. Please try again."),
              ),
            );
          }
        }
        return;
      }

      // Direct StoreKit purchase — no RevenueCat paywall UI involved.
      // Apple shows the native trial confirmation sheet automatically.
      final repo = ref.read(subscriptionRepositoryProvider);
      final info = await repo.purchasePackage(selectedPackage);
      if (!mounted) return;

      // Refresh local state from the latest CustomerInfo.
      await ref.read(subscriptionProvider.notifier).refresh();
      if (!mounted) return;

      final isNowPro =
          info.entitlements.active.containsKey(kProEntitlementId) ||
              ref.read(isPremiumProvider);
      if (isNowPro) {
        _close();
      }
    } on PlatformException catch (e, stack) {
      // Common cases:
      //   1 = userCancelled — silent, that's a normal outcome.
      //   23 = configurationError — RC dashboard / API key isn't set up.
      //   Anything else — surface a friendly retry message.
      final code = e.details is Map
          ? (e.details as Map)['readable_error_code']?.toString()
          : null;
      if (e.code == '1' || code == 'PURCHASE_CANCELLED') {
        // User tapped Cancel on the StoreKit sheet — no error UI needed.
      } else {
        Sentry.captureException(e, stackTrace: stack);
        debugPrint('[OnboardingPaywallScreen] purchase error: $e');
        if (mounted) {
          if (kDebugMode && (e.code == '23' || code == 'CONFIGURATION_ERROR')) {
            await _showPreviewDialog(
              title: 'RevenueCat not configured',
              message:
                  'Your build is missing a valid RevenueCat API key or the '
                  'products in App Store Connect / RC dashboard are not '
                  "linked yet. The paywall UI is fine — this dialog only "
                  'appears in debug builds so you can keep iterating.',
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Purchase failed: ${e.message ?? 'please try again'}'),
              ),
            );
          }
        }
      }
    } catch (e, stack) {
      Sentry.captureException(e, stackTrace: stack);
      debugPrint('[OnboardingPaywallScreen] unexpected error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _showPreviewDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceRaised,
        title: Text(
          title,
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.textPrimaryDark,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          message,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondaryDark,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'OK',
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _restore() async {
    if (_isWorking) return;
    setState(() => _isWorking = true);
    try {
      await ref.read(subscriptionProvider.notifier).refresh();
      if (!mounted) return;
      if (ref.read(isPremiumProvider)) {
        _close();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active subscription found')),
      );
    } catch (e, stack) {
      Sentry.captureException(e, stackTrace: stack);
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  /// Pop back to the previous route if possible (e.g. Settings → Paywall
  /// preview), otherwise navigate to Today (post-onboarding flow).
  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RouteNames.todayPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Force dark mode locally so the paywall always reads as cinematic
    // regardless of the user's system theme.
    return Theme(
      data: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: AppColors.canvas,
        textTheme: ThemeData.dark(useMaterial3: true).textTheme,
      ),
      child: Builder(
        builder: (ctx) {
          final offeringsAsync = ref.watch(offeringsProvider);
          final prices = _resolvePrices(offeringsAsync.valueOrNull);

          return Scaffold(
            backgroundColor: AppColors.canvas,
            extendBodyBehindAppBar: true,
            body: Stack(
              children: [
                // Body content scrolls under the top bar.
                Positioned.fill(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      const _Hero(),
                      const SizedBox(height: AppDimens.spaceLg),
                      const _HeroLockup(),
                      const SizedBox(height: AppDimens.spaceXl),
                      const _OutcomeList(),
                      if (_kShowSocialProof) ...[
                        const SizedBox(height: AppDimens.spaceLg),
                        const _SocialProof(),
                      ],
                      const SizedBox(height: AppDimens.spaceLg),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.spaceLg,
                        ),
                        child: _PlanPicker(
                          selected: _selectedPlan,
                          prices: prices,
                          onChanged: (p) =>
                              setState(() => _selectedPlan = p),
                        ),
                      ),
                      const SizedBox(height: AppDimens.spaceLg),
                    ],
                  ),
                ),
                // Top bar (Restore + X) overlaid on the hero photo.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: _TopBar(
                      onClose: _isWorking ? null : _close,
                      onRestore: _isWorking ? null : _restore,
                    ),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: _BottomCta(
              isLoading: _isWorking,
              selectedPlan: _selectedPlan,
              prices: prices,
              onStart: _startTrial,
              onSkip: _isWorking ? null : _close,
            ),
          );
        },
      ),
    );
  }
}

// ── Hero photo ──────────────────────────────────────────────────────────────

/// Full-bleed cinematic photo with a top scrim (status-bar legibility) and
/// a bottom gradient that dissolves the photo into the canvas.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            _heroImage,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (context, error, stackTrace) =>
                const ColoredBox(color: AppColors.canvas),
          ),
          const Positioned.fill(
            child: ZPatternOverlay(
              variant: ZPatternVariant.original,
              opacity: 0.05,
            ),
          ),
          // Top scrim — keeps Restore + X readable.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Bottom dissolve into canvas.
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.45, 1.0],
                    colors: [
                      Colors.transparent,
                      AppColors.canvas,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Top bar ─────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose, required this.onRestore});

  final VoidCallback? onClose;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceSm),
        child: Row(
          children: [
            TextButton(
              onPressed: onRestore,
              child: Text(
                'Restore',
                style: AppTextStyles.labelMedium.copyWith(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: onClose,
              icon: Icon(
                Icons.close_rounded,
                color: Colors.white.withValues(alpha: 0.92),
              ),
              splashRadius: 22,
              tooltip: 'Close',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hero lockup (PRO badge + headline + sub) ───────────────────────────────

class _HeroLockup extends StatelessWidget {
  const _HeroLockup();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ProBadge(),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            'Your full health story.',
            maxLines: 1,
            overflow: TextOverflow.visible,
            style: AppTextStyles.displayLarge.copyWith(
              color: AppColors.textPrimaryDark,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.1,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            "Free for $_trialDays days. Cancel anytime, and we'll remind "
            'you before your trial ends.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondaryDark,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProBadge extends StatelessWidget {
  const _ProBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppDimens.shapePill),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.32),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        'ZURALOG · PRO',
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textOnSage,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.6,
        ),
      ),
    );
  }
}

// ── Outcome rows ────────────────────────────────────────────────────────────

class _OutcomeList extends StatelessWidget {
  const _OutcomeList();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
      child: Column(
        children: [
          _OutcomeRow(
            icon: Icons.bolt_rounded,
            tint: AppColors.categoryActivity,
            title: 'Catch what your watch misses',
            body:
                'Pro turns raw HealthKit data into the moves, sleep, and habits that actually shifted your week.',
          ),
          SizedBox(height: AppDimens.spaceLg),
          _OutcomeRow(
            icon: Icons.bedtime_rounded,
            tint: AppColors.categorySleep,
            title: 'Sleep that adapts to your week',
            body:
                'Your coach factors in last night, last workout, and tomorrow, so the plan changes when you do.',
          ),
          SizedBox(height: AppDimens.spaceLg),
          _OutcomeRow(
            icon: Icons.favorite_rounded,
            tint: AppColors.categoryHeart,
            title: 'A coach that remembers everything',
            body:
                'Every meal, lift, mood, and recovery score in one place. No re-explaining yourself.',
          ),
        ],
      ),
    );
  }
}

class _OutcomeRow extends StatelessWidget {
  const _OutcomeRow({
    required this.icon,
    required this.tint,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon square gets the brand pattern wash per the design bible
        // (list-item icon containers — 12% Original, screen blend).
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.shapeMd),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.16),
                    borderRadius:
                        BorderRadius.circular(AppDimens.shapeMd),
                    border: Border.all(
                      color: tint.withValues(alpha: 0.32),
                      width: 1,
                    ),
                  ),
                ),
                const IgnorePointer(
                  child: ZPatternOverlay(
                    variant: ZPatternVariant.original,
                    opacity: 0.12,
                  ),
                ),
                Center(child: Icon(icon, color: tint, size: 22)),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppDimens.spaceMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textPrimaryDark,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondaryDark,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Social proof (gated) ────────────────────────────────────────────────────

class _SocialProof extends StatelessWidget {
  const _SocialProof();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.star_rounded,
              color: AppColors.primary, size: 18),
          const SizedBox(width: 6),
          Text(
            'Loved by early users · 4.9 on the App Store',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textSecondaryDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pricing helpers ─────────────────────────────────────────────────────────

class _ResolvedPrices {
  const _ResolvedPrices({
    required this.monthly,
    required this.annualTotal,
    required this.annualPerMonth,
    required this.savingsPercent,
    this.monthlyPackage,
    this.annualPackage,
  });

  final String monthly;
  final String annualTotal;
  final String annualPerMonth;
  final int savingsPercent;
  final Package? monthlyPackage;
  final Package? annualPackage;
}

_ResolvedPrices _resolvePrices(Offerings? offerings) {
  final current = offerings?.current;
  final monthlyPkg = current?.monthly;
  final annualPkg = current?.annual;

  String monthly = _fallbackMonthlyPrice;
  String annualTotal = _fallbackAnnualPrice;
  String annualPerMonth = _fallbackAnnualPerMonth;
  int savingsPercent = 50; // honest default: $9.99×12 vs $59.99 ≈ 50%.

  if (monthlyPkg != null) {
    monthly = monthlyPkg.storeProduct.priceString;
  }
  if (annualPkg != null) {
    annualTotal = annualPkg.storeProduct.priceString;
    final annualPrice = annualPkg.storeProduct.price;
    if (annualPrice > 0) {
      final perMonthValue = (annualPrice / 12).toStringAsFixed(2);
      annualPerMonth = '${_currencySymbol(annualPkg)}$perMonthValue';
      if (monthlyPkg != null) {
        final monthlyPrice = monthlyPkg.storeProduct.price;
        if (monthlyPrice > 0) {
          final yearlyAtMonthly = monthlyPrice * 12;
          final saved =
              ((yearlyAtMonthly - annualPrice) / yearlyAtMonthly) * 100;
          savingsPercent = saved.round().clamp(0, 99);
        }
      }
    }
  }

  return _ResolvedPrices(
    monthly: monthly,
    annualTotal: annualTotal,
    annualPerMonth: annualPerMonth,
    savingsPercent: savingsPercent,
    monthlyPackage: monthlyPkg,
    annualPackage: annualPkg,
  );
}

String _currencySymbol(Package p) {
  final priceString = p.storeProduct.priceString;
  for (final rune in priceString.runes) {
    final ch = String.fromCharCode(rune);
    if (ch != ' ' && ch != '.' && ch != ',' && int.tryParse(ch) == null) {
      return ch;
    }
  }
  return r'$';
}

// ── Plan picker ─────────────────────────────────────────────────────────────

class _PlanPicker extends StatelessWidget {
  const _PlanPicker({
    required this.selected,
    required this.onChanged,
    required this.prices,
  });

  final _PlanChoice selected;
  final ValueChanged<_PlanChoice> onChanged;
  final _ResolvedPrices prices;

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight gives the Row a bounded height equal to the tallest
    // card's natural height. Without this, `crossAxisAlignment.stretch`
    // inside a vertically-unbounded ListView throws a silent layout error
    // — the cards never render and the scroll view's content metrics get
    // corrupted (which is what makes scrolling feel "sticky").
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _PlanCard(
              isSelected: selected == _PlanChoice.annual,
              onTap: () => onChanged(_PlanChoice.annual),
              ribbon: prices.savingsPercent > 0
                  ? 'SAVE ${prices.savingsPercent}%'
                  : null,
              title: 'Annual',
              priceHeadline: '${prices.annualPerMonth}/mo',
              priceSub: 'Billed ${prices.annualTotal} yearly',
              semantic:
                  'Annual plan, ${prices.annualPerMonth} per month, billed ${prices.annualTotal} yearly'
                  '${prices.savingsPercent > 0 ? ", save ${prices.savingsPercent} percent" : ""}',
            ),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: _PlanCard(
              isSelected: selected == _PlanChoice.monthly,
              onTap: () => onChanged(_PlanChoice.monthly),
              title: 'Monthly',
              priceHeadline: '${prices.monthly}/mo',
              priceSub: 'Cancel anytime',
              semantic:
                  'Monthly plan, ${prices.monthly} per month, cancel anytime',
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.isSelected,
    required this.onTap,
    required this.title,
    required this.priceHeadline,
    required this.priceSub,
    required this.semantic,
    this.ribbon,
  });

  final bool isSelected;
  final VoidCallback onTap;
  final String title;
  final String priceHeadline;
  final String priceSub;
  final String semantic;
  final String? ribbon;

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? AppColors.primary
        : Colors.white.withValues(alpha: 0.10);
    final radius = BorderRadius.circular(AppDimens.shapeLg);

    // Brand-bible pattern rule:
    //  • Selected card → Sage tint surface, Sage.PNG at 10%, screen blend, static
    //    (matches the "active chip" treatment).
    //  • Unselected card → Surface dark, Original.PNG at 7%, screen blend,
    //    static (matches the "feature card" treatment).
    final patternVariant =
        isSelected ? ZPatternVariant.sage : ZPatternVariant.original;
    final patternOpacity = isSelected ? 0.10 : 0.07;

    return Semantics(
      label: semantic,
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.10)
                    : AppColors.surface,
                borderRadius: radius,
                border: Border.all(
                  color: borderColor,
                  width: isSelected ? 1.6 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: Stack(
                  children: [
                    // Brand topographic pattern wash — reads as "this is
                    // a Zuralog feature surface, not a generic card."
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ZPatternOverlay(
                          variant: patternVariant,
                          opacity: patternOpacity,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimens.spaceMd,
                        AppDimens.spaceMd + 6,
                        AppDimens.spaceMd,
                        AppDimens.spaceMd,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: AppTextStyles.titleMedium.copyWith(
                              color: AppColors.textPrimaryDark,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            priceHeadline,
                            style: AppTextStyles.titleLarge.copyWith(
                              color: AppColors.textPrimaryDark,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            priceSub,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondaryDark,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (ribbon != null)
              Positioned(
                top: -10,
                right: -8,
                child: _SavingsRibbon(label: ribbon!),
              ),
          ],
        ),
      ),
    );
  }
}

class _SavingsRibbon extends StatelessWidget {
  const _SavingsRibbon({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppDimens.shapePill),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.40),
            blurRadius: 14,
          ),
        ],
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textOnSage,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

// ── Sticky bottom CTA ───────────────────────────────────────────────────────

class _BottomCta extends StatelessWidget {
  const _BottomCta({
    required this.isLoading,
    required this.onStart,
    required this.onSkip,
    required this.selectedPlan,
    required this.prices,
  });

  final bool isLoading;
  final VoidCallback onStart;
  final VoidCallback? onSkip;
  final _PlanChoice selectedPlan;
  final _ResolvedPrices prices;

  static const double _buttonHeight = 56;

  String get _afterTrialPrice => selectedPlan == _PlanChoice.annual
      ? '${prices.annualTotal}/year'
      : '${prices.monthly}/month';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.canvas,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.spaceLg,
            AppDimens.spaceMd,
            AppDimens.spaceLg,
            AppDimens.spaceSm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                button: true,
                enabled: !isLoading,
                label: 'Start your $_trialDays-day free trial',
                child: GestureDetector(
                  onTap: isLoading ? null : onStart,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: _buttonHeight,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius:
                          BorderRadius.circular(AppDimens.shapePill),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.32),
                          blurRadius: 32,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(AppDimens.shapePill),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Brand pattern wash — same treatment all
                          // primary buttons get per the design bible
                          // (Sage.PNG, animated drift).
                          const Positioned.fill(
                            child: IgnorePointer(
                              child: ZPatternOverlay(
                                variant: ZPatternVariant.sage,
                                opacity: 0.55,
                                animate: true,
                              ),
                            ),
                          ),
                          if (isLoading)
                            const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(
                                  AppColors.textOnSage,
                                ),
                              ),
                            )
                          else
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Start free trial',
                                  style:
                                      AppTextStyles.labelLarge.copyWith(
                                    color: AppColors.textOnSage,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.1,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 18,
                                  color: AppColors.textOnSage,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.spaceSm),
              Text(
                '$_trialDays days free, then $_afterTrialPrice. '
                'Cancel anytime in Settings.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondaryDark,
                  height: 1.4,
                ),
              ),
              TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  minimumSize:
                      const Size.fromHeight(AppDimens.touchTargetMin),
                ),
                child: Text(
                  'Maybe later',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondaryDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
