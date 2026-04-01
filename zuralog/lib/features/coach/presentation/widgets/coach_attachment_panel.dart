library;

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';
import 'package:zuralog/shared/widgets/zuralog_app_bar.dart';

import 'package:zuralog/features/chat/domain/attachment_types.dart';

export 'package:zuralog/features/chat/domain/attachment_types.dart'
    show AttachmentType, PendingAttachment;

// ── Constants ──────────────────────────────────────────────────────────────────

const int _kCameraQuality = 85;
const int _kMaxFileSizeBytes = 10 * 1024 * 1024;

// ── Persona data ───────────────────────────────────────────────────────────────
//
// Inline records — NOT imported from coach_settings_screen.dart.
// Note: key values match CoachPersona.value strings (e.g. 'tough_love', not
// 'toughLove') so that CoachPersona.fromValue() resolves correctly.

const _personas = [
  (
    key: 'tough_love',
    label: 'Tough Love',
    description: 'Blunt, data-driven. No sugar-coating.',
    icon: Icons.fitness_center_rounded,
    color: AppColors.categoryHeart,
  ),
  (
    key: 'balanced',
    label: 'Balanced',
    description: 'Supportive and honest. Celebrates wins, addresses gaps.',
    icon: Icons.balance_rounded,
    color: AppColors.categoryWellness,
  ),
  (
    key: 'gentle',
    label: 'Gentle',
    description: 'Warm, encouraging, patient. Progress over perfection.',
    icon: Icons.spa_rounded,
    color: AppColors.categoryWellness,
  ),
];

// ── CoachAttachmentPanel ───────────────────────────────────────────────────────

/// Full-screen attachment and session-settings panel for the Coach chat.
///
/// Intended as the full-screen successor to [AttachmentPickerSheet] with a scrollable panel that includes:
/// - Three attachment pickers (Camera, Photos, Files)
/// - Inline AI Persona selector
/// - Proactivity and Response Length segmented controls
/// - Suggested Prompts and Voice Input toggles
///
/// All settings read from and write to [userPreferencesProvider], so changes
/// sync automatically with the Settings tab.
class CoachAttachmentPanel extends ConsumerStatefulWidget {
  const CoachAttachmentPanel({
    super.key,
    required this.onAttachment,
  });

  final ValueChanged<PendingAttachment> onAttachment;

  @override
  ConsumerState<CoachAttachmentPanel> createState() =>
      _CoachAttachmentPanelState();
}

class _CoachAttachmentPanelState extends ConsumerState<CoachAttachmentPanel> {
  bool _picking = false;

  // ── Helpers ──────────────────────────────────────────────────────────────────

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

  // ── Pickers ──────────────────────────────────────────────────────────────────

  Future<void> _pickCamera() => _pickImage(ImageSource.camera);
  Future<void> _pickGallery() => _pickImage(ImageSource.gallery);

  Future<void> _pickImage(ImageSource source) async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final picker = ImagePicker();
      final xFile = await picker.pickImage(
        source: source,
        imageQuality: _kCameraQuality,
      );
      if (xFile == null) {
        if (context.mounted) Navigator.of(context).pop();
        return;
      }
      if (!await _checkSize(xFile.path)) return;
      if (!context.mounted) return;
      Navigator.of(context).pop();
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
  }

  Future<void> _pickFile() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'csv'],
        withData: false,
      );
      if (result == null || result.files.isEmpty) {
        if (context.mounted) Navigator.of(context).pop();
        return;
      }
      final pf = result.files.first;
      if (pf.path == null) {
        if (context.mounted) Navigator.of(context).pop();
        return;
      }
      if (!await _checkSize(pf.path!)) return;
      if (!context.mounted) return;
      final type = (pf.extension ?? '').toLowerCase() == 'pdf'
          ? AttachmentType.pdf
          : AttachmentType.document;
      Navigator.of(context).pop();
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
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final prefs = ref.watch(userPreferencesProvider).valueOrNull;

    final selectedPersona =
        prefs?.coachPersona.value ?? CoachPersona.balanced.value;
    final selectedProactivity =
        prefs?.proactivityLevel.value ?? ProactivityLevel.medium.value;
    final selectedResponseLength =
        prefs?.responseLength.value ?? ResponseLength.concise.value;
    final suggestedPromptsEnabled = prefs?.suggestedPromptsEnabled ?? true;
    final voiceInputEnabled = prefs?.voiceInputEnabled ?? true;

    return ZuralogScaffold(
      appBar: ZuralogAppBar(
        title: 'Add Attachment',
        showProfileAvatar: false,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Close',
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppDimens.spaceMd,
          0,
          AppDimens.spaceMd,
          MediaQuery.of(context).padding.bottom + AppDimens.spaceMd,
        ),
        children: [
          const _OverlineLabel('ATTACH FROM'),
          const SizedBox(height: AppDimens.spaceMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _PickerOption(
                icon: Icons.camera_alt_rounded,
                label: 'Camera',
                onTap: _picking ? null : _pickCamera,
              ),
              _PickerOption(
                icon: Icons.photo_library_rounded,
                label: 'Photos',
                onTap: _picking ? null : _pickGallery,
              ),
              _PickerOption(
                icon: Icons.attach_file_rounded,
                label: 'Files',
                onTap: _picking ? null : _pickFile,
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceXl),

          const _OverlineLabel('SESSION SETTINGS'),
          const SizedBox(height: AppDimens.spaceMd),

          // AI Persona
          Text(
            'AI Persona',
            style: AppTextStyles.labelLarge
                .copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          for (int i = 0; i < _personas.length; i++) ...[
            _PersonaCard(
              persona: _personas[i],
              isActive: _personas[i].key == selectedPersona,
              onTap: () =>
                  ref.read(userPreferencesProvider.notifier).mutate(
                    (p) => p.copyWith(
                      coachPersona: CoachPersona.fromValue(
                        _personas[i].key,
                      ),
                    ),
                  ),
            ),
            if (i < _personas.length - 1)
              const SizedBox(height: AppDimens.spaceSm),
          ],
          const SizedBox(height: AppDimens.spaceMd),

          // Proactivity
          Text(
            'Proactivity',
            style: AppTextStyles.labelLarge
                .copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          ZSegmentedControl(
            selectedIndex: ['low', 'medium', 'high']
                .indexOf(selectedProactivity)
                .clamp(0, 2),
            segments: const ['Low', 'Medium', 'High'],
            onChanged: (i) =>
                ref.read(userPreferencesProvider.notifier).mutate(
                  (p) => p.copyWith(
                    proactivityLevel: ProactivityLevel.fromValue(
                      ['low', 'medium', 'high'][i],
                    ),
                  ),
                ),
          ),
          const SizedBox(height: AppDimens.spaceMd),

          // Response Length
          Text(
            'Response Length',
            style: AppTextStyles.labelLarge
                .copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          ZSegmentedControl(
            selectedIndex: ['concise', 'detailed']
                .indexOf(selectedResponseLength)
                .clamp(0, 1),
            segments: const ['Concise', 'Detailed'],
            onChanged: (i) =>
                ref.read(userPreferencesProvider.notifier).mutate(
                  (p) => p.copyWith(
                    responseLength: ResponseLength.fromValue(
                      ['concise', 'detailed'][i],
                    ),
                  ),
                ),
          ),
          const SizedBox(height: AppDimens.spaceMd),

          const ZDivider(),
          const SizedBox(height: AppDimens.spaceSm),

          // Toggle settings card
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius:
                  BorderRadius.circular(AppDimens.radiusCard),
            ),
            child: Column(
              children: [
                ZSettingsTile(
                  icon: Icons.lightbulb_outline_rounded,
                  iconColor: AppColors.categoryWellness,
                  title: 'Suggested Prompts',
                  subtitle: 'Show prompt chips in new conversations',
                  showChevron: false,
                  trailing: ZToggle(
                    value: suggestedPromptsEnabled,
                    onChanged: (v) =>
                        ref
                            .read(userPreferencesProvider.notifier)
                            .mutate(
                              (p) => p.copyWith(
                                suggestedPromptsEnabled: v,
                              ),
                            ),
                  ),
                  onTap: () =>
                      ref
                          .read(userPreferencesProvider.notifier)
                          .mutate(
                            (p) => p.copyWith(
                              suggestedPromptsEnabled:
                                  !suggestedPromptsEnabled,
                            ),
                          ),
                ),
                const ZDivider(indent: 68),
                ZSettingsTile(
                  icon: Icons.mic_rounded,
                  iconColor: AppColors.categoryActivity,
                  title: 'Voice Input',
                  subtitle:
                      'Enable hold-to-talk microphone button',
                  showChevron: false,
                  trailing: ZToggle(
                    value: voiceInputEnabled,
                    onChanged: (v) =>
                        ref
                            .read(userPreferencesProvider.notifier)
                            .mutate(
                              (p) => p.copyWith(voiceInputEnabled: v),
                            ),
                  ),
                  onTap: () =>
                      ref
                          .read(userPreferencesProvider.notifier)
                          .mutate(
                            (p) => p.copyWith(
                              voiceInputEnabled: !voiceInputEnabled,
                            ),
                          ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
        ],
      ),
    );
  }
}

// ── Private widgets ────────────────────────────────────────────────────────────

class _OverlineLabel extends StatelessWidget {
  const _OverlineLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppDimens.spaceSm),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(
          color: AppColorsOf(context).textSecondary,
          letterSpacing: 1.2,
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Opacity(
      opacity: onTap == null ? 0.4 : 1.0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: colors.primary, size: 28),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
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

class _PersonaCard extends StatelessWidget {
  const _PersonaCard({
    required this.persona,
    required this.isActive,
    required this.onTap,
  });

  final ({
    String key,
    String label,
    String description,
    IconData icon,
    Color color,
  }) persona;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border: isActive
            ? Border.all(color: colors.primary, width: 1.5)
            : Border.all(color: colors.border, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimens.radiusCard),
          splashColor: colors.primary.withValues(alpha: 0.08),
          highlightColor: colors.primary.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            child: Row(
              children: [
                ZIconBadge(
                  icon: persona.icon,
                  color: persona.color,
                  size: 44,
                  iconSize: AppDimens.iconMd,
                ),
                const SizedBox(width: AppDimens.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        persona.label,
                        style: AppTextStyles.titleMedium
                            .copyWith(color: colors.textPrimary),
                      ),
                      const SizedBox(height: AppDimens.spaceXs),
                      Text(
                        persona.description,
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimens.spaceSm),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: isActive
                      ? Icon(
                          Icons.check_circle_rounded,
                          key: const ValueKey(true),
                          color: colors.primary,
                          size: AppDimens.iconMd,
                        )
                      : Icon(
                          Icons.radio_button_unchecked_rounded,
                          key: const ValueKey(false),
                          color: colors.textTertiary,
                          size: AppDimens.iconMd,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
