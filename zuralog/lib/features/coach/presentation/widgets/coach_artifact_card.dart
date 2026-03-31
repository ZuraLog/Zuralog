/// Coach Tab — Inline Artifact Card.
///
/// Shown inside the message thread when Zura performs an action (memory saved,
/// journal logged, data check). Rendered for [MessageRole.system] messages.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

/// What Zura did — determines border color and icon.
enum ArtifactType {
  /// A memory was saved. Border: Sage, icon: memory_rounded.
  memory,

  /// A journal entry was logged. Border: green, icon: edit_note_rounded.
  journal,

  /// Health data was read/checked. Border: blue, icon: analytics_rounded.
  dataCheck,
}

/// Parses [content] (a system message body) to detect the [ArtifactType].
///
/// Looks for keywords: "journal"/"diary" → [ArtifactType.journal],
/// "data"/"health"/"metric"/"step"/"sleep" → [ArtifactType.dataCheck].
/// Falls back to [ArtifactType.memory] for unrecognised content.
ArtifactType artifactTypeFromContent(String content) {
  final lower = content.toLowerCase();
  if (lower.contains('journal') || lower.contains('diary')) {
    return ArtifactType.journal;
  }
  if (lower.contains('data') ||
      lower.contains('health') ||
      lower.contains('metric') ||
      lower.contains('step') ||
      lower.contains('sleep')) {
    return ArtifactType.dataCheck;
  }
  return ArtifactType.memory;
}

/// Single artifact card rendered inline in the thread.
class CoachArtifactCard extends StatelessWidget {
  const CoachArtifactCard({
    super.key,
    required this.type,
    required this.description,
    this.onTap,
  });

  final ArtifactType type;
  final String description;

  /// Optional tap handler. Shows a snackbar stub if null.
  final VoidCallback? onTap;

  Color get _borderColor {
    return switch (type) {
      ArtifactType.memory => AppColors.primary,
      ArtifactType.journal => const Color(0xFF4CAF50),
      ArtifactType.dataCheck => const Color(0xFF2196F3),
    };
  }

  IconData get _icon {
    return switch (type) {
      ArtifactType.memory => Icons.memory_rounded,
      ArtifactType.journal => Icons.edit_note_rounded,
      ArtifactType.dataCheck => Icons.analytics_rounded,
    };
  }

  String get _label {
    return switch (type) {
      ArtifactType.memory => 'Memory saved',
      ArtifactType.journal => 'Journal entry logged',
      ArtifactType.dataCheck => 'Health data checked',
    };
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ??
          () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_label),
                  behavior: SnackBarBehavior.floating,
                ),
              ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppDimens.spaceXs),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          border: Border(
            left: BorderSide(color: _borderColor, width: 3),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceMd,
            vertical: AppDimens.spaceSm,
          ),
          child: Row(
            children: [
              Icon(_icon, color: _borderColor, size: AppDimens.iconSm),
              const SizedBox(width: AppDimens.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _label,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.warmWhite,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (description.isNotEmpty)
                      Text(
                        description,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-width "Zura did this" section divider shown above artifact card groups.
class CoachArtifactDivider extends StatelessWidget {
  const CoachArtifactDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              height: 1,
              color: AppColors.textSecondary.withValues(alpha: 0.3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceSm),
            child: Text(
              'Zura did this',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              height: 1,
              color: AppColors.textSecondary.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}
