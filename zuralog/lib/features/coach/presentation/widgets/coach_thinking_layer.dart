/// Coach Tab — Collapsible Thinking Strip (Layer 0 of AI response anatomy).
///
/// Shows "Zura is thinking..." while the AI is generating but no tokens have
/// arrived yet (or a tool is running). Tapping expands to show reasoning steps.
/// The entire layer is hidden once the response stream completes.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_blob.dart';

/// Collapsible strip shown while Zura is thinking (before first streaming token).
///
/// [steps] contains any reasoning step strings to show when expanded.
/// When [steps] is empty, the expanded section shows a loading indicator.
class CoachThinkingLayer extends StatefulWidget {
  const CoachThinkingLayer({super.key, this.steps = const []});

  final List<String> steps;

  @override
  State<CoachThinkingLayer> createState() => _CoachThinkingLayerState();
}

class _CoachThinkingLayerState extends State<CoachThinkingLayer> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppDimens.spaceSm),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          border: Border(
            left: BorderSide(color: colors.primary, width: 4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Collapsed header ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
                vertical: AppDimens.spaceSm,
              ),
              child: Row(
                children: [
                  const CoachBlob(state: BlobState.thinking, size: 16),
                  const SizedBox(width: AppDimens.spaceSm),
                  Expanded(
                    child: Text(
                      'Zura is thinking...',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: AppDimens.iconSm,
                    color: colors.textSecondary,
                  ),
                ],
              ),
            ),
            // ── Expanded steps ────────────────────────────────────────────
            if (_expanded)
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.spaceMd,
                  0,
                  AppDimens.spaceMd,
                  AppDimens.spaceSm,
                ),
                child: widget.steps.isEmpty
                    ? SizedBox(
                        height: 32,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: colors.primary,
                            strokeWidth: 1.5,
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: widget.steps
                              .map(
                                (step) => Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppDimens.spaceXs,
                                  ),
                                  child: Text(
                                    step,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
