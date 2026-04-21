/// Expanded AI breakdown card. Shown inline below the compact
/// [ZAiSummaryCard] when the user taps "Read the full breakdown ›".
///
/// Renders a Lora-serif headline and up to 5 section rows, each with
/// a category color stripe, a name, a plain-English elaboration, and
/// the headline delta number on the right. Each row is tappable.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/data/domain/all_data_summary.dart';
import 'package:zuralog/features/data/domain/category_color.dart';
import 'package:zuralog/shared/widgets/cards/zuralog_card.dart';

class ZAiBreakdownCard extends StatelessWidget {
  const ZAiBreakdownCard({
    super.key,
    required this.summary,
    required this.onSectionTap,
    required this.onClose,
  });

  final AllDataSummary summary;
  final ValueChanged<AllDataSummarySection> onSectionTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return ZuralogCard(
      variant: ZCardVariant.feature,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SparkleIcon(size: 11, color: colors.primary),
              const SizedBox(width: 6),
              Text(
                'HOW I READ TODAY',
                style: AppTextStyles.labelSmall.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.3,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onClose,
                behavior: HitTestBehavior.opaque,
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            summary.headline,
            style: AppTextStyles.titleLarge.copyWith(
              fontFamily: 'Lora',
              fontWeight: FontWeight.w600,
              fontSize: 18,
              height: 1.25,
              color: colors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < summary.sections.length; i++)
            _SectionRow(
              section: summary.sections[i],
              isFirst: i == 0,
              onTap: () => onSectionTap(summary.sections[i]),
              colors: colors,
            ),
        ],
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.section,
    required this.isFirst,
    required this.onTap,
    required this.colors,
  });

  final AllDataSummarySection section;
  final bool isFirst;
  final VoidCallback onTap;
  final AppColorsOf colors;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(section.category);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            top: isFirst
                ? BorderSide.none
                : BorderSide(
                    color: colors.textPrimary.withValues(alpha: 0.05),
                    width: 1,
                  ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              constraints: const BoxConstraints(minHeight: 30),
              margin: const EdgeInsets.only(top: 2, right: 10),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.name,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    section.elaboration,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: colors.textSecondary,
                      fontSize: 10.5,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                section.deltaLabel,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontFamily: 'Lora',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: colors.textPrimary,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SparkleIcon extends StatelessWidget {
  const _SparkleIcon({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _SparklePainter(color: color)),
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
