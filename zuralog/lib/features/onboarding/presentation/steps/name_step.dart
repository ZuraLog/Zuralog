/// Zuralog — Onboarding Step 2: Name / Nickname.
///
/// Collects the user's preferred name for AI greeting personalization.
/// Includes a live preview card that updates as the user types.
///
/// Backend field: `nickname` in `PATCH /api/v1/preferences`.
/// Skippable — empty value sends no name to the backend (AI defaults to "Hey").
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── Step Widget ────────────────────────────────────────────────────────────────

/// Step 2 of the onboarding flow — name/nickname input with live preview.
///
/// The live preview card shows an example AI greeting using the current
/// input, making the benefit of entering a name immediately tangible.
class NameStep extends StatefulWidget {
  /// Creates a [NameStep].
  const NameStep({
    super.key,
    required this.nickname,
    required this.onNicknameChanged,
  });

  /// Current nickname value (from parent state).
  final String nickname;

  /// Called whenever the input changes.
  final ValueChanged<String> onNicknameChanged;

  @override
  State<NameStep> createState() => _NameStepState();
}

class _NameStepState extends State<NameStep> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.nickname);
  }

  @override
  void didUpdateWidget(NameStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync controller if parent resets the value (e.g., skip/back nav).
    if (widget.nickname != _controller.text) {
      _controller.text = widget.nickname;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceLg,
        AppDimens.spaceLg,
        AppDimens.spaceLg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Heading ───────────────────────────────────────────────────
          Text(
            'What should we\ncall you?',
            style: AppTextStyles.displayLarge.copyWith(
              color: AppColors.primary,
              height: 1.1,
            ),
          ),
          const SizedBox(height: AppDimens.spaceXs),
          Text(
            'Your AI coach will use this name.',
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),

          const SizedBox(height: AppDimens.spaceXl),

          // ── Name input — autofocus, large text ─────────────────────────
          TextFormField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.done,
            style: AppTextStyles.titleLarge.copyWith(
              color: AppColors.textPrimaryDark,
            ),
            decoration: InputDecoration(
              hintText: 'Your name or nickname...',
              hintStyle: AppTextStyles.bodyLarge.copyWith(
                fontSize: 20,
                color: AppColors.textTertiary,
              ),
            ),
            onChanged: widget.onNicknameChanged,
          ),

          const SizedBox(height: AppDimens.spaceLg),

          // ── Live preview card ─────────────────────────────────────────
          _LivePreviewCard(nickname: widget.nickname),

          const SizedBox(height: AppDimens.spaceLg),
        ],
      ),
    );
  }
}

// ── Live Preview Card ─────────────────────────────────────────────────────────

/// Shows an example AI greeting using the current nickname input.
/// Updates on every keystroke to make the benefit immediately tangible.
class _LivePreviewCard extends StatelessWidget {
  const _LivePreviewCard({required this.nickname});

  final String nickname;

  @override
  Widget build(BuildContext context) {
    final greeting = nickname.trim().isEmpty ? 'there' : nickname.trim();

    return ZuralogCard(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sage Green avatar dot
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.smart_toy_rounded,
                size: 14,
                color: AppColors.primaryButtonText,
              ),
            ),
          ),

          const SizedBox(width: AppDimens.spaceSm),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Preview',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hi $greeting, here\'s your morning briefing...',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimaryDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
