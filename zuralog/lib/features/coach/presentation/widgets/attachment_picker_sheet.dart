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
import 'package:zuralog/features/chat/domain/attachment_types.dart';

export 'package:zuralog/features/chat/domain/attachment_types.dart'
    show AttachmentType, PendingAttachment;

// Fix L5: camera quality constant to avoid magic number duplication.
const int _kCameraQuality = 85;

// Fix M15: max file size (10 MB).
const int _kMaxFileSizeBytes = 10 * 1024 * 1024;

// ── AttachmentPickerSheet ─────────────────────────────────────────────────────

/// Bottom sheet with 3 attachment options: Camera, Gallery, File.
///
/// Fix L6: converted to StatefulWidget to prevent double-tap races.
class AttachmentPickerSheet extends StatefulWidget {
  const AttachmentPickerSheet({super.key, required this.onAttachment});

  final ValueChanged<PendingAttachment> onAttachment;

  @override
  State<AttachmentPickerSheet> createState() => _AttachmentPickerSheetState();
}

class _AttachmentPickerSheetState extends State<AttachmentPickerSheet> {
  // Fix L6: double-tap guard.
  bool _picking = false;

  /// Helper: check file size; show snackbar and pop if too large.
  Future<bool> _checkSize(String path) async {
    final fileSize = await File(path).length();
    if (fileSize > _kMaxFileSizeBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File too large (max 10 MB)')),
        );
        Navigator.of(context).pop();
      }
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                color: colors.elevatedSurface,
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
                  // Fix L6: double-tap guard.
                  if (_picking) return;
                  setState(() => _picking = true);
                  try {
                    final picker = ImagePicker();
                    final xFile = await picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: _kCameraQuality,
                    );
                    // Fix H35: pop sheet on null result (cancelled/denied).
                    if (xFile == null) {
                      if (context.mounted) Navigator.of(context).pop();
                      return;
                    }
                    // Fix M15: size check.
                    if (!await _checkSize(xFile.path)) return;
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                    // Fix H36: wrap onAttachment in try/catch.
                    try {
                      widget.onAttachment(PendingAttachment(
                        file: File(xFile.path),
                        type: AttachmentType.image,
                        name: xFile.name,
                      ));
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to add attachment: $e')),
                        );
                      }
                    }
                  } finally {
                    if (mounted) setState(() => _picking = false);
                  }
                },
              ),
              _PickerOption(
                icon: Icons.photo_library_rounded,
                label: 'Gallery',
                onTap: () async {
                  // Fix L6: double-tap guard.
                  if (_picking) return;
                  setState(() => _picking = true);
                  try {
                    final picker = ImagePicker();
                    final xFile = await picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: _kCameraQuality,
                    );
                    // Fix H35: pop sheet on null result (cancelled/denied).
                    if (xFile == null) {
                      if (context.mounted) Navigator.of(context).pop();
                      return;
                    }
                    // Fix M15: size check.
                    if (!await _checkSize(xFile.path)) return;
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                    // Fix H36: wrap onAttachment in try/catch.
                    try {
                      widget.onAttachment(PendingAttachment(
                        file: File(xFile.path),
                        type: AttachmentType.image,
                        name: xFile.name,
                      ));
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to add attachment: $e')),
                        );
                      }
                    }
                  } finally {
                    if (mounted) setState(() => _picking = false);
                  }
                },
              ),
              _PickerOption(
                icon: Icons.attach_file_rounded,
                label: 'File',
                onTap: () async {
                  // Fix L6: double-tap guard.
                  if (_picking) return;
                  setState(() => _picking = true);
                  try {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['pdf', 'txt', 'csv'],
                      withData: false,
                    );
                    // Fix H37/H35: guard against null result or empty files.
                    if (result == null || result.files.isEmpty) {
                      if (context.mounted) Navigator.of(context).pop();
                      return;
                    }
                    final pf = result.files.first;
                    if (pf.path == null) {
                      if (context.mounted) Navigator.of(context).pop();
                      return;
                    }
                    // Fix M15: size check.
                    if (!await _checkSize(pf.path!)) return;
                    if (!context.mounted) return;
                    final type = pf.extension == 'pdf'
                        ? AttachmentType.pdf
                        : AttachmentType.document;
                    Navigator.of(context).pop();
                    // Fix H36: wrap onAttachment in try/catch.
                    try {
                      widget.onAttachment(PendingAttachment(
                        file: File(pf.path!),
                        type: type,
                        name: pf.name,
                      ));
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to add attachment: $e')),
                        );
                      }
                    }
                  } finally {
                    if (mounted) setState(() => _picking = false);
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
    final colors = AppColorsOf(context);
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
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
