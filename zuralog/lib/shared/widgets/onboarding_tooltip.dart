/// Zuralog — OnboardingTooltip widget.
///
/// Renders a contextual coaching bubble anchored to a target widget using
/// Flutter's Overlay system. The bubble is positioned correctly relative to
/// the target regardless of scroll position or layout nesting depth.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'onboarding_tooltip_provider.dart';

const double _kMaxWidth = 240.0;
const double _kBorderRadius = 12.0;
const double _kArrowSize = 8.0;
const EdgeInsets _kPadding = EdgeInsets.symmetric(horizontal: 14, vertical: 10);

class OnboardingTooltip extends ConsumerStatefulWidget {
  const OnboardingTooltip({
    super.key,
    required this.screenKey,
    required this.tooltipKey,
    required this.message,
    required this.child,
    this.preferBelow = false,
  });

  final String screenKey;
  final String tooltipKey;
  final String message;
  final Widget child;

  /// When false (default): bubble above child, arrow points down.
  /// When true: bubble below child, arrow points up.
  final bool preferBelow;

  String get _persistenceKey => '$screenKey.$tooltipKey';

  @override
  ConsumerState<OnboardingTooltip> createState() => _OnboardingTooltipState();
}

class _OnboardingTooltipState extends ConsumerState<OnboardingTooltip> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _shouldShow = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncVisibility());
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _syncVisibility() {
    if (!mounted) return;
    final tooltipsEnabled =
        ref.read(tooltipsEnabledProvider).valueOrNull ?? true;
    final seenMap =
        ref.read(tooltipSeenProvider).valueOrNull ?? const <String, bool>{};
    final isSeen = seenMap[widget._persistenceKey] ?? false;
    final shouldShow = tooltipsEnabled && !isSeen;
    if (shouldShow == _shouldShow) return;
    _shouldShow = shouldShow;
    if (_shouldShow) {
      _showOverlay(context);
    } else {
      _removeOverlay();
    }
  }

  void _showOverlay(BuildContext context) {
    if (_overlayEntry != null) return;

    // ── Boundary detection ─────────────────────────────────────────────────
    // Compute available space above and below the target widget and auto-flip
    // the preferred direction if there is not enough room.
    final renderBox = context.findRenderObject() as RenderBox?;
    final screenSize = MediaQuery.of(context).size;
    final viewPadding = MediaQuery.of(context).viewPadding;

    // Estimate tooltip height (~80px for typical tooltip content).
    const kTooltipHeight = 80.0;
    const kAppBarHeight = kToolbarHeight; // 56px default
    const kNavBarHeight = 80.0; // AppDimens.bottomNavHeight

    bool effectivePreferBelow = widget.preferBelow;

    if (renderBox != null) {
      final targetPos = renderBox.localToGlobal(Offset.zero);
      final targetHeight = renderBox.size.height;

      // Space available above the tooltip (between tooltip top and AppBar bottom).
      final spaceAbove =
          targetPos.dy - kTooltipHeight - kAppBarHeight - viewPadding.top;
      // Space available below the tooltip (between tooltip bottom and NavBar top).
      final spaceBelow = screenSize.height -
          (targetPos.dy + targetHeight + kTooltipHeight + kNavBarHeight + viewPadding.bottom);

      if (!widget.preferBelow && spaceAbove < 0 && spaceBelow >= 0) {
        // Not enough room above → flip to below.
        effectivePreferBelow = true;
      } else if (widget.preferBelow && spaceBelow < 0 && spaceAbove >= 0) {
        // Not enough room below → flip to above.
        effectivePreferBelow = false;
      }
    }

    final capturedContext = context;
    final capturedPreferBelow = effectivePreferBelow;

    _overlayEntry = OverlayEntry(
      builder: (_) {
        final isDark = Theme.of(capturedContext).brightness == Brightness.dark;
        final bubbleBg = isDark
            ? AppColors.surfaceDark
            : AppColors.surfaceLight;
        final textColor = isDark
            ? AppColors.textPrimaryDark
            : AppColors.textPrimaryLight;
        // The OverlayEntry's render box fills the entire overlay, so a
        // transparent Material inside it would absorb taps across the whole
        // screen — including AppBar buttons rendered below the overlay layer.
        // Fix: make the outer layer completely pass-through with
        // IgnorePointer(ignoring: true), then re-enable hit-testing ONLY for
        // the visible bubble content with a nested IgnorePointer(ignoring: false).
        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: capturedPreferBelow
                  ? Alignment.bottomCenter
                  : Alignment.topCenter,
              followerAnchor: capturedPreferBelow
                  ? Alignment.topCenter
                  : Alignment.bottomCenter,
              offset: Offset(
                0,
                capturedPreferBelow ? _kArrowSize + 4 : -(_kArrowSize + 4),
              ),
              child: SizedBox(
                width: _kMaxWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: capturedPreferBelow
                      ? [
                          _ArrowPaint(color: bubbleBg, pointingDown: false),
                          _BubbleContent(
                            message: widget.message,
                            bubbleBg: bubbleBg,
                            textColor: textColor,
                            onDismiss: _dismiss,
                          ),
                        ]
                      : [
                          _BubbleContent(
                            message: widget.message,
                            bubbleBg: bubbleBg,
                            textColor: textColor,
                            onDismiss: _dismiss,
                          ),
                          _ArrowPaint(color: bubbleBg, pointingDown: true),
                        ],
                ),
              ),
            ),
          ],
        );
      },
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _dismiss() {
    ref.read(tooltipSeenProvider.notifier).markSeen(widget._persistenceKey);
    _removeOverlay();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(tooltipsEnabledProvider, (prev, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncVisibility());
    });
    ref.listen(tooltipSeenProvider, (prev, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncVisibility());
    });
    ref.watch(tooltipsEnabledProvider);
    ref.watch(tooltipSeenProvider);
    return CompositedTransformTarget(link: _layerLink, child: widget.child);
  }
}

// ── _BubbleContent ────────────────────────────────────────────────────────────

class _BubbleContent extends StatelessWidget {
  const _BubbleContent({
    required this.message,
    required this.bubbleBg,
    required this.textColor,
    required this.onDismiss,
  });

  final String message;
  final Color bubbleBg;
  final Color textColor;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: _kPadding,
      decoration: BoxDecoration(
        color: bubbleBg,
        borderRadius: BorderRadius.circular(_kBorderRadius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: AppTextStyles.bodySmall.copyWith(color: textColor),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.opaque,
            child: Text(
              'Got it',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _ArrowPaint ───────────────────────────────────────────────────────────────

class _ArrowPaint extends StatelessWidget {
  const _ArrowPaint({required this.color, required this.pointingDown});

  final Color color;
  final bool pointingDown;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(_kArrowSize * 2, _kArrowSize),
      painter: _ArrowPainter(color: color, pointingDown: pointingDown),
    );
  }
}

// ── _ArrowPainter ─────────────────────────────────────────────────────────────

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter({required this.color, required this.pointingDown});

  final Color color;
  final bool pointingDown;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    if (pointingDown) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close();
    } else {
      path
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) =>
      old.color != color || old.pointingDown != pointingDown;
}
