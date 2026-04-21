/// Compact AI summary feature card.
///
/// Renders the [AllDataSummary] body as rich text with category-tinted
/// highlights on metric names. Tapping anywhere on the card fires
/// [onExpand]. Tapping a highlighted metric name fires [onMetricTap]
/// with that metric's id (used to open the microscope sheet).
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/data/domain/all_data_summary.dart';
import 'package:zuralog/features/data/domain/data_models.dart'
    show HealthCategory;
import 'package:zuralog/shared/widgets/cards/zuralog_card.dart';

class ZAiSummaryCard extends StatefulWidget {
  const ZAiSummaryCard({
    super.key,
    required this.summary,
    required this.generatedAtLabel,
    required this.onExpand,
    this.onMetricTap,
  });

  /// The AI-generated summary to render.
  final AllDataSummary summary;

  /// Right-aligned meta label like "AI · 9:41 AM".
  final String generatedAtLabel;

  /// Called when the card surface is tapped (expands the breakdown).
  final VoidCallback onExpand;

  /// Called when a highlighted metric name is tapped.
  final ValueChanged<String>? onMetricTap;

  @override
  State<ZAiSummaryCard> createState() => _ZAiSummaryCardState();
}

class _ZAiSummaryCardState extends State<ZAiSummaryCard> {
  /// Retained tap recognizers — disposed on rebuild / dispose.
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onExpand,
      child: ZuralogCard(
        variant: ZCardVariant.feature,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(
              generatedAtLabel: widget.generatedAtLabel,
              colors: colors,
            ),
            const SizedBox(height: 6),
            _Body(
              spans: widget.summary.body,
              onMetricTap: widget.onMetricTap,
              colors: colors,
              recognizers: _recognizers,
            ),
            const SizedBox(height: 10),
            Container(
              height: 1,
              color: colors.textPrimary.withValues(alpha: 0.05),
            ),
            const SizedBox(height: 8),
            _Footer(
              referenceCount: widget.summary.referenceCount,
              colors: colors,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.generatedAtLabel, required this.colors});
  final String generatedAtLabel;
  final AppColorsOf colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _SparkleIcon(size: 11),
        const SizedBox(width: 6),
        Text(
          "TODAY'S READ",
          style: AppTextStyles.labelSmall.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.3,
          ),
        ),
        const Spacer(),
        Text(
          generatedAtLabel,
          style: AppTextStyles.labelSmall.copyWith(
            color: colors.textTertiary,
            fontSize: 8,
            letterSpacing: 1.0,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.spans,
    required this.onMetricTap,
    required this.colors,
    required this.recognizers,
  });

  final List<AllDataSummarySpan> spans;
  final ValueChanged<String>? onMetricTap;
  final AppColorsOf colors;
  final List<TapGestureRecognizer> recognizers;

  @override
  Widget build(BuildContext context) {
    // Dispose previously registered recognizers before rebuilding.
    for (final r in recognizers) {
      r.dispose();
    }
    recognizers.clear();

    final baseStyle = AppTextStyles.bodyMedium.copyWith(
      color: colors.textPrimary,
      fontSize: 11.5,
      height: 1.55,
      letterSpacing: -0.1,
    );

    final children = <InlineSpan>[];
    for (final s in spans) {
      if (s.metricId == null || s.category == null) {
        children.add(TextSpan(text: s.text, style: baseStyle));
        continue;
      }
      final color = _inlineColorFor(s.category!);
      TapGestureRecognizer? recognizer;
      if (onMetricTap != null) {
        recognizer = TapGestureRecognizer()
          ..onTap = () => onMetricTap!(s.metricId!);
        recognizers.add(recognizer);
      }
      children.add(TextSpan(
        text: s.text,
        style: baseStyle.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
        recognizer: recognizer,
      ));
    }

    return Text.rich(TextSpan(children: children));
  }

  /// Returns the inline tint used inside body copy for each category.
  /// Sleep / Heart / Wellness have dedicated lighter "Inline" tokens; the
  /// rest are already mid-tone and render fine at 11.5pt.
  static Color _inlineColorFor(HealthCategory cat) {
    switch (cat) {
      case HealthCategory.sleep:
        return AppColors.categorySleepInline;
      case HealthCategory.heart:
        return AppColors.categoryHeartInline;
      case HealthCategory.wellness:
        return AppColors.categoryWellnessInline;
      case HealthCategory.activity:
        return AppColors.categoryActivity;
      case HealthCategory.nutrition:
        return AppColors.categoryNutrition;
      case HealthCategory.body:
        return AppColors.categoryBody;
      case HealthCategory.vitals:
        return AppColors.categoryVitals;
      case HealthCategory.cycle:
        return AppColors.categoryCycle;
      case HealthCategory.mobility:
        return AppColors.categoryMobility;
      case HealthCategory.environment:
        return AppColors.categoryEnvironment;
    }
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.referenceCount, required this.colors});
  final int referenceCount;
  final AppColorsOf colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Based on $referenceCount readings · 6 categories',
            style: AppTextStyles.labelSmall.copyWith(
              color: colors.textTertiary,
              fontSize: 9,
            ),
          ),
        ),
        Text(
          'Read the full breakdown ›',
          style: AppTextStyles.labelSmall.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w700,
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

class _SparkleIcon extends StatelessWidget {
  const _SparkleIcon({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _SparklePainter(color: colors.primary)),
    );
  }
}

class _SparklePainter extends CustomPainter {
  _SparklePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, h * 0.04)
      ..lineTo(w * 0.58, h * 0.38)
      ..lineTo(w * 0.92, h * 0.46)
      ..lineTo(w * 0.58, h * 0.54)
      ..lineTo(w * 0.5, h * 0.88)
      ..lineTo(w * 0.42, h * 0.54)
      ..lineTo(w * 0.08, h * 0.46)
      ..lineTo(w * 0.42, h * 0.38)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) => old.color != color;
}
