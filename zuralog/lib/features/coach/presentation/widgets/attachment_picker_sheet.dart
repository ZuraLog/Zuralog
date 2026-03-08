/// Attachment picker bottom sheet for Coach chat.
///
/// Provides Camera, Gallery, and File picker options.
/// Returns a [PendingAttachment] via the [onAttachment] callback.
library;

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

// ── PendingAttachment ─────────────────────────────────────────────────────────

/// Represents a pending attachment before upload.
class PendingAttachment {
  const PendingAttachment({
    required this.file,
    required this.type,
    required this.name,
  });

  final File file;
  final AttachmentType type;
  final String name;
}

/// The type of a pending attachment.
enum AttachmentType { image, pdf, document }

// ── AttachmentPickerSheet ─────────────────────────────────────────────────────

/// Bottom sheet with 3 attachment options: Camera, Gallery, File.
class AttachmentPickerSheet extends StatelessWidget {
  const AttachmentPickerSheet({super.key, required this.onAttachment});

  final ValueChanged<PendingAttachment> onAttachment;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                // No exact token for 0xFF48484A; closest semantic is borderDark (0xFF38383A).
                // ignore: avoid_hardcoded_color_token
                color: const Color(0xFF48484A),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('Add Attachment', style: AppTextStyles.h3),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _PickerOption(
                icon: Icons.camera_alt_rounded,
                label: 'Camera',
                onTap: () async {
                  final picker = ImagePicker();
                  final xFile = await picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 85,
                  );
                  if (xFile != null && context.mounted) {
                    Navigator.of(context).pop();
                    onAttachment(PendingAttachment(
                      file: File(xFile.path),
                      type: AttachmentType.image,
                      name: xFile.name,
                    ));
                  }
                },
              ),
              _PickerOption(
                icon: Icons.photo_library_rounded,
                label: 'Gallery',
                onTap: () async {
                  final picker = ImagePicker();
                  final xFile = await picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 85,
                  );
                  if (xFile != null && context.mounted) {
                    Navigator.of(context).pop();
                    onAttachment(PendingAttachment(
                      file: File(xFile.path),
                      type: AttachmentType.image,
                      name: xFile.name,
                    ));
                  }
                },
              ),
              _PickerOption(
                icon: Icons.attach_file_rounded,
                label: 'File',
                onTap: () async {
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['pdf', 'txt', 'csv'],
                    withData: false,
                  );
                  if (result != null &&
                      result.files.single.path != null &&
                      context.mounted) {
                    final pf = result.files.single;
                    final type = pf.extension == 'pdf'
                        ? AttachmentType.pdf
                        : AttachmentType.document;
                    Navigator.of(context).pop();
                    onAttachment(PendingAttachment(
                      file: File(pf.path!),
                      type: type,
                      name: pf.name,
                    ));
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── _PickerOption ─────────────────────────────────────────────────────────────

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
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
        ],
      ),
    );
  }
}
