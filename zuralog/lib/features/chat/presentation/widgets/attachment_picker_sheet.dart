/// Zuralog Edge Agent — Attachment Picker Bottom Sheet.
///
/// A modal bottom sheet with three options for attaching files
/// to a chat message: Camera, Photo Library, and Voice Note.
library;

import 'package:flutter/material.dart';

import 'package:zuralog/core/theme/theme.dart';

/// The type of attachment the user selected from the picker.
enum AttachmentPickerResult {
  /// Take a photo with the device camera.
  camera,

  /// Pick an image from the photo library.
  gallery,

  /// Record a voice note.
  voiceNote,
}

/// Shows the attachment picker bottom sheet.
///
/// Returns the user's selection, or `null` if dismissed.
Future<AttachmentPickerResult?> showAttachmentPicker(BuildContext context) {
  return showModalBottomSheet<AttachmentPickerResult>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const _AttachmentPickerSheet(),
  );
}

class _AttachmentPickerSheet extends StatelessWidget {
  const _AttachmentPickerSheet();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppDimens.spaceMd,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Text(
              'Add Attachment',
              style: AppTextStyles.h3.copyWith(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            _PickerOption(
              icon: Icons.camera_alt_rounded,
              label: 'Camera',
              onTap: () =>
                  Navigator.pop(context, AttachmentPickerResult.camera),
            ),
            _PickerOption(
              icon: Icons.photo_library_rounded,
              label: 'Photo Library',
              onTap: () =>
                  Navigator.pop(context, AttachmentPickerResult.gallery),
            ),
            _PickerOption(
              icon: Icons.mic_rounded,
              label: 'Voice Note',
              onTap: () =>
                  Navigator.pop(context, AttachmentPickerResult.voiceNote),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerOption extends StatelessWidget {
  const _PickerOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
      title: Text(label, style: AppTextStyles.body),
      onTap: onTap,
    );
  }
}
