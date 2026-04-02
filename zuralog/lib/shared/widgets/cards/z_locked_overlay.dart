/// Zuralog Design System — Locked Overlay Component.
///
/// Wraps any widget with a dim overlay and a "PRO" badge, signalling
/// that the content requires a premium subscription. Tapping the
/// overlay presents the [ZPremiumGateSheet].
library;

import 'package:flutter/material.dart';

import 'package:zuralog/shared/widgets/feedback/z_premium_gate_sheet.dart';
import 'package:zuralog/shared/widgets/indicators/z_pro_badge.dart';

/// Dims a child widget and overlays a [ZProBadge] to indicate locked
/// premium content.
///
/// When the user taps anywhere on the overlay, a [ZPremiumGateSheet] is
/// shown with the supplied [headline], [body], and optional [icon].
///
/// Example:
/// ```dart
/// ZLockedOverlay(
///   headline: 'Unlock Trends',
///   body: 'See how your health changes over time.',
///   icon: Icons.trending_up_rounded,
///   child: MyTrendsCard(),
/// )
/// ```
class ZLockedOverlay extends StatelessWidget {
  /// Creates a [ZLockedOverlay].
  const ZLockedOverlay({
    super.key,
    required this.child,
    required this.headline,
    required this.body,
    this.icon,
  });

  /// The widget to display underneath the dimming overlay.
  final Widget child;

  /// Headline text passed to [ZPremiumGateSheet] when tapped.
  final String headline;

  /// Body text passed to [ZPremiumGateSheet] when tapped.
  final String body;

  /// Optional icon passed to [ZPremiumGateSheet] when tapped.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The underlying content, dimmed to 40 % opacity.
        Opacity(
          opacity: 0.40,
          child: child,
        ),

        // Tap target — opens the premium gate sheet.
        Positioned.fill(
          child: Semantics(
            label: 'Locked premium feature. Tap to learn more.',
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => ZPremiumGateSheet.show(
                context,
                headline: headline,
                body: body,
                icon: icon,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),

        // Pro badge in the top-right corner.
        const Positioned(
          top: 8,
          right: 8,
          child: ZProBadge(showLock: true),
        ),
      ],
    );
  }
}
