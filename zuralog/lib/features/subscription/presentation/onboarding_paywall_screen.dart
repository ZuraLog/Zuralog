/// Zuralog — Post-Onboarding Paywall Screen.
///
/// A branded, full-screen pre-paywall presented right after the chat
/// onboarding finishes. It introduces ZuraLog Pro, lists what the user
/// gets, shows a plan picker (Annual vs Monthly), and routes through
/// RevenueCat for the actual purchase. "Maybe later" skips to Today.
///
/// This is the marketing surface — the real purchase flow is handled by
/// [SubscriptionNotifier.presentPaywall], which opens the RevenueCat
/// native paywall. We refresh subscription state on return.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_assets.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/subscription/domain/subscription_providers.dart';
import 'package:zuralog/shared/widgets/animations/z_fade_slide_in.dart';
import 'package:zuralog/shared/widgets/pattern/z_pattern_overlay.dart';

/// The plan the user has selected inside the paywall.
enum _PlanChoice { annual, monthly }

/// Static price fallbacks used when RevenueCat offerings are unavailable.
const String _fallbackMonthlyPrice = r'$9.99';
const String _fallbackAnnualPrice = r'$59.99';
const String _fallbackAnnualPerMonth = r'$4.99';
const String _fallbackSavingsPct = '50';

class OnboardingPaywallScreen extends ConsumerStatefulWidget {
  const OnboardingPaywallScreen({super.key});

  @override
  ConsumerState<OnboardingPaywallScreen> createState() =>
      _OnboardingPaywallScreenState();
}

class _OnboardingPaywallScreenState
    extends ConsumerState<OnboardingPaywallScreen> {
  _PlanChoice _selectedPlan = _PlanChoice.annual;
  bool _isWorking = false;

  Future<void> _startTrial() async {
    if (_isWorking) return;
    setState(() => _isWorking = true);
    try {
      final result =
          await ref.read(subscriptionProvider.notifier).presentPaywall();
      if (!mounted) return;
      if (result == PaywallResult.purchased ||
          result == PaywallResult.restored) {
        _goToToday();
        return;
      }
    } catch (e, stack) {
      Sentry.captureException(e, stackTrace: stack);
      debugPrint('[OnboardingPaywallScreen] presentPaywall error: $e');
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _restore() async {
    if (_isWorking) return;
    setState(() => _isWorking = true);
    try {
      await ref.read(subscriptionProvider.notifier).refresh();
      if (!mounted) return;
      if (ref.read(isPremiumProvider)) {
        _goToToday();
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

  void _goToToday() {
    context.go(RouteNames.todayPath);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(brightness: Brightness.dark),
      child: Builder(
        builder: (ctx) {
          final colors = AppColorsOf(ctx);
          final offeringsAsync = ref.watch(offeringsProvider);
          final prices = _resolvePrices(offeringsAsync.valueOrNull);

          return Scaffold(
            backgroundColor: colors.canvas,
            body: Stack(
              children: [
                // Ambient canvas pattern — a very faint drift behind everything.
                const Positioned.fill(
                  child: IgnorePointer(
                    child: ZPatternOverlay(
                      variant: ZPatternVariant.original,
                      opacity: 0.03,
                      animate: true,
                    ),
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      _TopBar(
                        onClose: _isWorking ? null : _goToToday,
                        onRestore: _isWorking ? null : _restore,
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(
                            left: AppDimens.spaceLg,
                            right: AppDimens.spaceLg,
                            top: AppDimens.spaceSm,
                            bottom: AppDimens.spaceLg,
                          ),
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const ZFadeSlideIn(
                                duration: Duration(milliseconds: 520),
                                child: _Hero(),
                              ),
                              const SizedBox(height: AppDimens.spaceMd),
                              const ZFadeSlideIn(
                                delay: Duration(milliseconds: 120),
                                child: _BenefitList(),
                              ),
                              const SizedBox(height: AppDimens.spaceMd),
                              ZFadeSlideIn(
                                delay: const Duration(milliseconds: 220),
                                child: _PlanPicker(
                                  selected: _selectedPlan,
                                  onChanged: (p) =>
                                      setState(() => _selectedPlan = p),
                                  prices: prices,
                                ),
                              ),
                              const SizedBox(height: AppDimens.spaceMd),
                              _TrialFootnote(
                                prices: prices,
                                plan: _selectedPlan,
                              ),
                            ],
                          ),
                        ),
                      ),
                      _BottomCta(
                        isLoading: _isWorking,
                        onStart: _startTrial,
                        onSkip: _isWorking ? null : _goToToday,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
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
    final colors = AppColorsOf(context);
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceSm),
        child: Row(
          children: [
            IconButton(
              onPressed: onClose,
              icon: Icon(Icons.close_rounded, color: colors.textSecondary),
              splashRadius: 22,
              tooltip: 'Close',
            ),
            const Spacer(),
            TextButton(
              onPressed: onRestore,
              child: Text(
                'Restore',
                style: AppTextStyles.labelMedium.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hero ────────────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.shapeLg),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppDimens.shapeLg),
        ),
        child: Stack(
          children: [
            // Hero pattern — animated topographic drift (brand bible rule).
            const Positioned.fill(
              child: ZPatternOverlay(
                variant: ZPatternVariant.original,
                opacity: 0.10,
                animate: true,
              ),
            ),
            // Sage glow wash behind the constellation.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.25),
                      radius: 0.9,
                      colors: [
                        colors.primary.withValues(alpha: 0.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceMd,
                AppDimens.spaceLg,
                AppDimens.spaceMd,
                AppDimens.spaceLg,
              ),
              child: Column(
                children: [
                  const _ShardConstellation(),
                  const SizedBox(height: AppDimens.spaceLg),
                  const _ProChip(),
                  const SizedBox(height: AppDimens.spaceMd),
                  Text(
                    'Your whole health,\nin one place.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.displaySmall.copyWith(
                      color: colors.textPrimary,
                      height: 1.15,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: AppDimens.spaceXs),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceSm,
                    ),
                    child: Text(
                      "Unlock Zura's full coach, every integration, "
                      'and insights tuned to you.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: colors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Sage logo ringed by 6 floating health-category "shards", each
/// gently breathing with a phase-shifted pulse to give the hero a living,
/// constellation feel — signals that ZuraLog covers the full health picture.
class _ShardConstellation extends StatefulWidget {
  const _ShardConstellation();

  @override
  State<_ShardConstellation> createState() => _ShardConstellationState();
}

class _ShardConstellationState extends State<_ShardConstellation>
    with SingleTickerProviderStateMixin {
  static const double _frame = 260;
  static const double _logoSize = 92;
  static const double _shardSize = 40;
  static const double _ringRadius = 98;

  late final AnimationController _controller;

  // Monochrome shards — the six health domains are present but rendered in a
  // restrained Sage palette so the hero reads as a single, premium brand
  // statement instead of a six-color fruit salad.
  static const List<IconData> _icons = [
    Icons.nightlight_round,          // top              (Sleep)
    Icons.eco_rounded,               // upper right      (Nutrition)
    Icons.directions_run_rounded,    // lower right      (Activity)
    Icons.favorite_rounded,          // bottom           (Heart)
    Icons.accessibility_new_rounded, // lower left       (Body)
    Icons.spa_rounded,               // upper left       (Wellness)
  ];

  static const List<double> _angles = [270, 330, 30, 90, 150, 210];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return SizedBox(
      width: _frame,
      height: _frame,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              _GlowHalo(pulse: reduceMotion ? 0.5 : t),
              const _OrbitRing(radius: _ringRadius),
              _LogoChip(size: _logoSize),
              for (int i = 0; i < _icons.length; i++)
                _positionedShard(
                  icon: _icons[i],
                  angleDeg: _angles[i],
                  phase: reduceMotion ? 0 : (t + i / _icons.length) % 1,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _positionedShard({
    required IconData icon,
    required double angleDeg,
    required double phase,
  }) {
    final angle = angleDeg * math.pi / 180;
    // Very gentle breath — each shard drifts ±2 px toward/away from center.
    final breath = math.sin(phase * 2 * math.pi) * 2;
    final r = _ringRadius + breath;
    final dx = math.cos(angle) * r;
    final dy = math.sin(angle) * r;
    final scale = 1 + math.sin(phase * 2 * math.pi) * 0.03;
    return Positioned(
      left: _frame / 2 + dx - _shardSize / 2,
      top: _frame / 2 + dy - _shardSize / 2,
      child: Transform.scale(
        scale: scale,
        child: _ShardChip(icon: icon, size: _shardSize),
      ),
    );
  }
}

/// A single faint Sage stroke circle sitting at the shard-orbit radius —
/// subtle connective tissue that makes the six shards read as a deliberate
/// constellation rather than random floating pills.
class _OrbitRing extends StatelessWidget {
  const _OrbitRing({required this.radius});

  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return IgnorePointer(
      child: CustomPaint(
        size: Size(radius * 2 + 2, radius * 2 + 2),
        painter: _OrbitRingPainter(
          color: colors.primary.withValues(alpha: 0.18),
        ),
      ),
    );
  }
}

class _OrbitRingPainter extends CustomPainter {
  _OrbitRingPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2 - 0.5,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _OrbitRingPainter old) => old.color != color;
}

class _GlowHalo extends StatelessWidget {
  const _GlowHalo({required this.pulse});

  /// 0.0 – 1.0 — a full breathing cycle.
  final double pulse;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final breath = 0.5 + math.sin(pulse * 2 * math.pi) * 0.5;
    final alpha = 0.10 + breath * 0.10; // 0.10 – 0.20
    final size = 150 + breath * 14; // gentle 150–164
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              colors.primary.withValues(alpha: alpha),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoChip extends StatelessWidget {
  const _LogoChip({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final radius = size * 0.30;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.22),
            blurRadius: 36,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Faint topographic pattern inside the chip — uses Original on a
            // dark surface so the contour lines lighten gently, keeping the
            // chip branded without fighting the logo for attention.
            const Positioned.fill(
              child: IgnorePointer(
                child: ZPatternOverlay(
                  variant: ZPatternVariant.original,
                  opacity: 0.14,
                  animate: true,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(size * 0.22),
              child: Image.asset(
                AppAssets.logoSagePng,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShardChip extends StatelessWidget {
  const _ShardChip({required this.icon, required this.size});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final radius = size * 0.30;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.18),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Positioned.fill(
              child: IgnorePointer(
                child: ZPatternOverlay(
                  variant: ZPatternVariant.original,
                  opacity: 0.10,
                  animate: true,
                ),
              ),
            ),
            Icon(icon, size: size * 0.46, color: colors.primary),
          ],
        ),
      ),
    );
  }
}

class _ProChip extends StatelessWidget {
  const _ProChip();

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.shapePill),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spaceMd,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppDimens.shapePill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 14,
                  color: colors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'ZURALOG PRO',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: ZPatternOverlay(
                  variant: ZPatternVariant.sage,
                  opacity: 0.15,
                  animate: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Benefits ────────────────────────────────────────────────────────────────

class _BenefitList extends StatelessWidget {
  const _BenefitList();

  static const List<_Benefit> _items = [
    _Benefit(
      icon: Icons.hub_rounded,
      title: 'Every device, one place',
      body: 'Apple Health, Fitbit, Strava, and more.',
    ),
    _Benefit(
      icon: Icons.timeline_rounded,
      title: 'Full history & trends',
      body: 'Track how you change across months and years.',
    ),
    _Benefit(
      icon: Icons.psychology_rounded,
      title: 'A coach who remembers',
      body: 'Zura learns your goals, habits, and wins.',
    ),
    _Benefit(
      icon: Icons.insights_rounded,
      title: 'Advanced insights',
      body: 'See what actually moves your sleep and energy.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceMd,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimens.shapeLg),
      ),
      child: Column(
        children: [
          for (int i = 0; i < _items.length; i++) ...[
            _items[i].build(context),
            if (i != _items.length - 1)
              const SizedBox(height: AppDimens.spaceMd),
          ],
        ],
      ),
    );
  }
}

class _Benefit {
  const _Benefit({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppDimens.shapeSm),
          ),
          child: Icon(icon, size: 18, color: colors.primary),
        ),
        const SizedBox(width: AppDimens.spaceMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.titleMedium.copyWith(
                  color: colors.textPrimary,
                  letterSpacing: -0.15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: colors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Plan picker ─────────────────────────────────────────────────────────────

class _ResolvedPrices {
  const _ResolvedPrices({
    required this.monthly,
    required this.annualTotal,
    required this.annualPerMonth,
    required this.savingsPct,
    this.monthlyPackage,
    this.annualPackage,
  });

  final String monthly;
  final String annualTotal;
  final String annualPerMonth;
  final String savingsPct;
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
  String savingsPct = _fallbackSavingsPct;

  if (monthlyPkg != null) {
    monthly = monthlyPkg.storeProduct.priceString;
  }
  if (annualPkg != null) {
    annualTotal = annualPkg.storeProduct.priceString;
    final price = annualPkg.storeProduct.price;
    if (price > 0) {
      final perMonthValue = (price / 12).toStringAsFixed(2);
      annualPerMonth = '${_currencySymbol(annualPkg)}$perMonthValue';
      final monthlyPrice = monthlyPkg?.storeProduct.price;
      if (monthlyPrice != null && monthlyPrice > 0) {
        final yearAtMonthly = monthlyPrice * 12;
        final saved = ((yearAtMonthly - price) / yearAtMonthly) * 100;
        if (saved > 0 && saved < 100) {
          savingsPct = saved.round().toString();
        }
      }
    }
  }

  return _ResolvedPrices(
    monthly: monthly,
    annualTotal: annualTotal,
    annualPerMonth: annualPerMonth,
    savingsPct: savingsPct,
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
    return Column(
      children: [
        _PlanCard(
          selected: selected == _PlanChoice.annual,
          onTap: () => onChanged(_PlanChoice.annual),
          title: 'Annual',
          priceHeadline: '${prices.annualPerMonth} /month',
          priceSub:
              'Billed ${prices.annualTotal} yearly · Save ${prices.savingsPct}%',
          tag: 'BEST VALUE',
        ),
        const SizedBox(height: AppDimens.spaceSm),
        _PlanCard(
          selected: selected == _PlanChoice.monthly,
          onTap: () => onChanged(_PlanChoice.monthly),
          title: 'Monthly',
          priceHeadline: '${prices.monthly} /month',
          priceSub: 'Cancel anytime',
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.selected,
    required this.onTap,
    required this.title,
    required this.priceHeadline,
    required this.priceSub,
    this.tag,
  });

  final bool selected;
  final VoidCallback onTap;
  final String title;
  final String priceHeadline;
  final String priceSub;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final borderColor =
        selected ? colors.primary : colors.textSecondary.withValues(alpha: 0.14);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.shapeLg),
      child: AnimatedScale(
        scale: selected ? 1.0 : 0.99,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          decoration: BoxDecoration(
            color: selected
                ? colors.primary.withValues(alpha: 0.06)
                : colors.surface,
            borderRadius: BorderRadius.circular(AppDimens.shapeLg),
            border: Border.all(
              color: borderColor,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              _Radio(selected: selected),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.titleMedium.copyWith(
                            color: colors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (tag != null) ...[
                          const SizedBox(width: AppDimens.spaceSm),
                          _ValueTag(label: tag!),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      priceHeadline,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      priceSub,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? colors.primary : Colors.transparent,
        border: Border.all(
          color: selected
              ? colors.primary
              : colors.textSecondary.withValues(alpha: 0.40),
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: selected
          ? Icon(
              Icons.check_rounded,
              size: 14,
              color: AppColors.textOnSage,
            )
          : null,
    );
  }
}

class _ValueTag extends StatelessWidget {
  const _ValueTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.shapePill),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(AppDimens.shapePill),
            ),
            child: Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textOnSage,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: ZPatternOverlay(
                  variant: ZPatternVariant.sage,
                  opacity: 0.15,
                  animate: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Trial footnote ──────────────────────────────────────────────────────────

class _TrialFootnote extends StatelessWidget {
  const _TrialFootnote({required this.prices, required this.plan});

  final _ResolvedPrices prices;
  final _PlanChoice plan;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final after = plan == _PlanChoice.annual
        ? '${prices.annualTotal} / year'
        : '${prices.monthly} / month';
    return Text(
      '7 days free — then $after. Cancel anytime.',
      textAlign: TextAlign.center,
      style: AppTextStyles.bodySmall.copyWith(color: colors.textSecondary),
    );
  }
}

// ── Bottom CTA ──────────────────────────────────────────────────────────────

class _BottomCta extends StatelessWidget {
  const _BottomCta({
    required this.isLoading,
    required this.onStart,
    required this.onSkip,
  });

  final bool isLoading;
  final VoidCallback onStart;
  final VoidCallback? onSkip;

  static const double _buttonHeight = 56;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        AppDimens.spaceSm,
        AppDimens.spaceLg,
        (safeBottom > 0 ? safeBottom : AppDimens.spaceMd),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: isLoading ? null : onStart,
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: _buttonHeight,
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(_buttonHeight / 2),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.22),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(_buttonHeight / 2),
                      child: const IgnorePointer(
                        child: ZPatternOverlay(
                          variant: ZPatternVariant.sage,
                          opacity: 0.55,
                          animate: true,
                        ),
                      ),
                    ),
                  ),
                  if (isLoading)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.textOnSage,
                        ),
                      ),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Start 7-day free trial',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: AppColors.textOnSage,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.1,
                          ),
                        ),
                        const SizedBox(width: AppDimens.spaceSm),
                        Icon(
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
          const SizedBox(height: AppDimens.spaceSm),
          TextButton(
            onPressed: onSkip,
            child: Text(
              'Maybe later',
              style: AppTextStyles.bodyMedium.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
