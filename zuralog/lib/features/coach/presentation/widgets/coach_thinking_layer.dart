/// Coach Tab — Thinking Layer (Layer 0 of AI response anatomy).
///
/// Shown while the AI is generating but no response tokens have arrived yet
/// (or a tool is running). Displays a large animated blob centrepiece with a
/// streaming status line beneath it. Hidden once the response stream completes.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/coach/presentation/widgets/coach_blob.dart';

/// Centered thinking indicator shown while Zura is reasoning or running a tool.
///
/// [thinkingContent] is the accumulated reasoning text streamed from the AI,
/// or null if no thinking tokens have arrived yet.
/// [activeToolName] is the raw name of the tool currently executing, or null.
class CoachThinkingLayer extends StatelessWidget {
  const CoachThinkingLayer({
    super.key,
    this.thinkingContent,
    this.activeToolName,
  });

  /// Accumulated reasoning text from the AI, or null if no thinking tokens
  /// have arrived yet.
  final String? thinkingContent;

  /// Name of the tool currently executing, or null.
  final String? activeToolName;

  /// Converts raw tool names like "apple_health_read_metrics" into
  /// user-friendly labels like "Apple Health".
  static String _friendlyToolName(String raw) {
    const prefixes = {
      'apple_health_': 'Apple Health',
      'health_connect_': 'Health Connect',
      'fitbit_': 'Fitbit',
      'strava_': 'Strava',
      'garmin_': 'Garmin',
      'oura_': 'Oura',
      'whoop_': 'Whoop',
    };
    for (final entry in prefixes.entries) {
      if (raw.startsWith(entry.key)) return entry.value;
    }
    // Fallback: strip underscores and title-case.
    return raw
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);

    // Decide the status line text.
    final String statusText;
    if (activeToolName != null) {
      statusText = 'Checking ${_friendlyToolName(activeToolName!)}…';
    } else if (thinkingContent != null && thinkingContent!.isNotEmpty) {
      // Show the last ~160 characters so the user sees the most recent
      // reasoning, not the beginning.
      final text = thinkingContent!;
      statusText = text.length > 160 ? text.substring(text.length - 160) : text;
    } else {
      statusText = 'Thinking…';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceMd,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        border: Border(
          left: BorderSide(color: colors.primary, width: 4),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Blob centrepiece
          const CoachBlob(state: BlobState.thinking, size: 48),
          const SizedBox(height: AppDimens.spaceSm),

          // Status line
          Text(
            statusText,
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
