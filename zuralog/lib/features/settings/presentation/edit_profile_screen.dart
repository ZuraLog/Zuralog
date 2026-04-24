/// Edit Profile Screen — lets the user update their display name, nickname,
/// birthday, gender, height, and avatar photo.
///
/// Avatar changes are applied immediately on photo selection (separate action,
/// not gated behind the Save button). All other field changes accumulate
/// locally and are flushed to the server when the user taps Save.
library;

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/auth/domain/auth_providers.dart';
import 'package:zuralog/features/auth/domain/user_profile.dart';
import 'package:zuralog/features/settings/domain/user_preferences_model.dart';
import 'package:zuralog/features/settings/presentation/widgets/settings_section_label.dart';
import 'package:zuralog/features/settings/providers/settings_providers.dart';
import 'package:zuralog/shared/widgets/widgets.dart';

// ── EditProfileScreen ─────────────────────────────────────────────────────────

/// Screen for editing the user's profile: name, nickname, birthday, gender,
/// height, and avatar photo.
class EditProfileScreen extends ConsumerStatefulWidget {
  /// Creates [EditProfileScreen].
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  // ── Controllers ────────────────────────────────────────────────────────────
  late TextEditingController _nameController;
  late TextEditingController _nicknameController;

  // ── Editable local state ────────────────────────────────────────────────────
  DateTime? _birthday;
  String? _gender;
  double? _heightCm;
  double? _weightKg;

  // ── Upload / save state ────────────────────────────────────────────────────
  bool _avatarUploading = false;
  bool _saving = false;
  String? _error;

  // ── Original values (used to detect unsaved changes) ──────────────────────
  late String _originalName;
  late String _originalNickname;
  late DateTime? _originalBirthday;
  late String? _originalGender;
  late double? _originalHeightCm;
  late double? _originalWeightKg;

  // ── Has the user changed anything? ────────────────────────────────────────
  bool get _hasChanges =>
      _nameController.text != _originalName ||
      _nicknameController.text != _originalNickname ||
      _birthday != _originalBirthday ||
      _gender != _originalGender ||
      _heightCm != _originalHeightCm ||
      _weightKg != _originalWeightKg;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileProvider);
    _originalName = profile?.displayName ?? '';
    _originalNickname = profile?.nickname ?? '';
    _originalBirthday = profile?.birthday;
    _originalGender = profile?.gender;
    _originalHeightCm = profile?.heightCm;

    _nameController = TextEditingController(text: _originalName);
    _nicknameController = TextEditingController(text: _originalNickname);
    _birthday = _originalBirthday;
    _gender = _originalGender;
    _heightCm = _originalHeightCm;
    _originalWeightKg = profile?.weightKg;
    _weightKg = _originalWeightKg;

    // Rebuild the Save button whenever text changes.
    _nameController.addListener(_onTextChanged);
    _nicknameController.addListener(_onTextChanged);
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    _nameController.removeListener(_onTextChanged);
    _nicknameController.removeListener(_onTextChanged);
    _nameController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  // ── Avatar upload ──────────────────────────────────────────────────────────

  Future<void> _pickAndUploadAvatar() async {
    final colors = AppColorsOf(context);
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 800,
    );
    if (file == null) return;

    final mimeType = lookupMimeType(file.path) ?? 'image/jpeg';

    setState(() => _avatarUploading = true);
    try {
      await ref.read(userProfileProvider.notifier).uploadAvatar(
            filePath: file.path,
            contentType: mimeType,
          );
      // Clear Flutter's image cache so the new avatar loads immediately
      // instead of showing the cached old image at the same URL.
      imageCache.clear();
      imageCache.clearLiveImages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is DioException
                  ? (e.response?.data?['detail'] as String? ??
                      'Photo upload failed. Try again.')
                  : 'Photo upload failed. Try again.',
              style: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary),
            ),
            backgroundColor: colors.surface,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _avatarUploading = false);
    }
  }

  // ── Save profile ────────────────────────────────────────────────────────────

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(userProfileProvider.notifier).update(
            displayName: _nameController.text.trim().isEmpty
                ? null
                : _nameController.text.trim(),
            nickname: _nicknameController.text.trim().isEmpty
                ? null
                : _nicknameController.text.trim(),
            birthday: _birthday,
            gender: _gender,
            heightCm: _heightCm,
            weightKg: _weightKg,
          );
      if (mounted) context.pop();
    } on DioException catch (e) {
      setState(() {
        _error =
            e.response?.data?['detail'] as String? ?? 'Something went wrong. Try again.';
      });
    } catch (_) {
      setState(() => _error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Bottom sheet helpers ────────────────────────────────────────────────────

  void _showFieldSheet(
    String title,
    String hint,
    TextEditingController controller,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FieldEditSheet(
        title: title,
        hint: hint,
        initialValue: controller.text,
        onSave: (value) {
          controller.text = value;
          setState(() {});
        },
      ),
    );
  }

  void _showBirthdayPicker() {
    DateTime picked = _birthday ?? DateTime(1990, 1, 1);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final colors = AppColorsOf(context);
        return Container(
          margin: const EdgeInsets.all(AppDimens.spaceMd),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppDimens.shapeLg),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.spaceMd,
                  AppDimens.spaceMd,
                  AppDimens.spaceMd,
                  0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Birthday',
                      style: AppTextStyles.titleMedium
                          .copyWith(color: colors.textPrimary),
                    ),
                    ZButton(
                      label: 'Done',
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        setState(() => _birthday = picked);
                      },
                      variant: ZButtonVariant.text,
                      isFullWidth: false,
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 200,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: picked,
                  minimumDate: DateTime(1900),
                  maximumDate: DateTime.now(),
                  onDateTimeChanged: (date) => picked = date,
                ),
              ),
              const SizedBox(height: AppDimens.spaceMd),
            ],
          ),
        );
      },
    );
  }

  void _showGenderPicker() {
    final options = ['Male', 'Female', 'Non-binary', 'Prefer not to say'];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final colors = AppColorsOf(context);
        return Container(
          margin: const EdgeInsets.all(AppDimens.spaceMd),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppDimens.shapeLg),
          ),
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
                child: Text(
                  'Gender',
                  style: AppTextStyles.titleMedium
                      .copyWith(color: colors.textPrimary),
                ),
              ),
              ...options.map((option) {
                final isSelected = _gender == option;
                return Padding(
                  padding:
                      const EdgeInsets.only(bottom: AppDimens.spaceSm),
                  child: ZSelectableTile(
                    isSelected: isSelected,
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      setState(() => _gender = option);
                    },
                    showCheckIndicator: true,
                    child: Text(
                      option,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: AppDimens.spaceSm),
            ],
          ),
        );
      },
    );
  }

  void _showHeightPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HeightPickerSheet(
        initialHeightCm: _heightCm,
        onSave: (cm) => setState(() => _heightCm = cm),
      ),
    );
  }

  void _showWeightPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WeightPickerSheet(
        initialWeightKg: _weightKg,
        onSave: (kg) => setState(() => _weightKg = kg),
      ),
    );
  }

  // ── Formatters ──────────────────────────────────────────────────────────────

  String _formatDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return '$mm/$dd/$yyyy';
  }

  String _formatWeight() {
    if (_weightKg == null) return 'Not set';
    final units = ref.watch(unitsSystemProvider);
    if (units == UnitsSystem.metric) {
      return '${_weightKg!.toStringAsFixed(1)} kg';
    }
    final lbs = (_weightKg! / 0.453592).round();
    return '$lbs lbs';
  }

  String _formatHeight() {
    if (_heightCm == null) return 'Not set';
    final units = ref.watch(unitsSystemProvider);
    if (units == UnitsSystem.metric) {
      return '${_heightCm!.toStringAsFixed(0)} cm';
    }
    // Convert to ft + in
    final totalInches = _heightCm! / 2.54;
    final ft = (totalInches / 12).floor();
    final inches = (totalInches % 12).round();
    return "$ft' $inches\"";
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    final profile = ref.watch(userProfileProvider);

    // Avatar initials fallback — first letter of display name or email.
    final email = ref.watch(userEmailProvider);
    final nameText = _nameController.text;
    final initial = nameText.isNotEmpty
        ? nameText[0].toUpperCase()
        : email.isNotEmpty
            ? email[0].toUpperCase()
            : 'U';

    return ZuralogScaffold(
      appBar: ZuralogAppBar(
        title: 'Edit Profile',
        showProfileAvatar: false,
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: ZCircularProgress(size: 18, strokeWidth: 2.5),
            )
          else
            ZButton(
              label: 'Save',
              onPressed: _hasChanges && !_saving ? _save : null,
              variant: ZButtonVariant.text,
              isFullWidth: false,
            ),
        ],
      ),
      body: ListView(
        padding:
            const EdgeInsets.symmetric(vertical: AppDimens.spaceMd),
        children: [
          // ── Avatar ─────────────────────────────────────────────────────
          _AvatarSection(
            profile: profile,
            initial: initial,
            uploading: _avatarUploading,
            onTap: _pickAndUploadAvatar,
          ),

          // ── Identity ───────────────────────────────────────────────────
          const SettingsSectionLabel('Identity'),
          ZSettingsGroup(
            tiles: [
              ZSettingsTile(
                icon: Icons.person_outline_rounded,
                iconColor: colors.primary,
                title: 'Name',
                subtitle: _nameController.text.isEmpty
                    ? 'Not set'
                    : _nameController.text,
                onTap: () => _showFieldSheet(
                  'Name',
                  'Your full name',
                  _nameController,
                ),
              ),
              ZSettingsTile(
                icon: Icons.face_rounded,
                iconColor: AppColors.categorySleep,
                title: 'Nickname',
                subtitle: _nicknameController.text.isEmpty
                    ? 'Not set'
                    : _nicknameController.text,
                onTap: () => _showFieldSheet(
                  'Nickname',
                  'What your AI coach calls you',
                  _nicknameController,
                ),
              ),
            ],
          ),

          // ── Health Profile ─────────────────────────────────────────────
          const SettingsSectionLabel('Health Profile'),
          ZSettingsGroup(
            tiles: [
              ZSettingsTile(
                icon: Icons.cake_outlined,
                iconColor: AppColors.categoryNutrition,
                title: 'Birthday',
                subtitle: _birthday != null
                    ? _formatDate(_birthday!)
                    : 'Not set',
                onTap: _showBirthdayPicker,
              ),
              ZSettingsTile(
                icon: Icons.people_outline_rounded,
                iconColor: AppColors.categoryWellness,
                title: 'Gender',
                subtitle: _gender ?? 'Not set',
                onTap: _showGenderPicker,
              ),
              ZSettingsTile(
                icon: Icons.straighten_rounded,
                iconColor: AppColors.categoryActivity,
                title: 'Height',
                subtitle: _formatHeight(),
                onTap: _showHeightPicker,
              ),
              ZSettingsTile(
                icon: Icons.monitor_weight_outlined,
                iconColor: AppColors.categoryNutrition,
                title: 'Weight',
                subtitle: _formatWeight(),
                onTap: _showWeightPicker,
              ),
            ],
          ),

          // ── Inline error ───────────────────────────────────────────────
          if (_error != null) ...[
            const SizedBox(height: AppDimens.spaceMd),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd),
              child: Text(
                _error!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.statusError,
                ),
              ),
            ),
          ],

          const SizedBox(height: AppDimens.spaceXxl),
        ],
      ),
    );
  }
}

// ── _AvatarSection ────────────────────────────────────────────────────────────

class _AvatarSection extends StatelessWidget {
  const _AvatarSection({
    required this.profile,
    required this.initial,
    required this.uploading,
    required this.onTap,
  });

  final UserProfile? profile;
  final String initial;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceMd),
      child: Column(
        children: [
          GestureDetector(
            onTap: uploading ? null : onTap,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                ZAvatar(
                  imageUrl: profile?.avatarUrl,
                  initials: initial,
                  size: 88,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.surface,
                        width: 2,
                      ),
                    ),
                    child: uploading
                        ? const Padding(
                            padding: EdgeInsets.all(5),
                            child: ZCircularProgress(size: 18, strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(
                            Icons.camera_alt_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            'Change Photo',
            style: AppTextStyles.bodySmall.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _FieldEditSheet ────────────────────────────────────────────────────────────

/// Bottom sheet with a single text field for editing a profile string value.
class _FieldEditSheet extends StatefulWidget {
  const _FieldEditSheet({
    required this.title,
    required this.hint,
    required this.initialValue,
    required this.onSave,
  });

  final String title;
  final String hint;
  final String initialValue;
  final ValueChanged<String> onSave;

  @override
  State<_FieldEditSheet> createState() => _FieldEditSheetState();
}

class _FieldEditSheetState extends State<_FieldEditSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        margin: const EdgeInsets.all(AppDimens.spaceMd),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppDimens.shapeLg),
        ),
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: AppTextStyles.displaySmall
                  .copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            AppTextField(
              hintText: widget.hint,
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: () {
                widget.onSave(_controller.text);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: AppDimens.spaceMd),
            ZButton(
              label: 'Save',
              onPressed: () {
                widget.onSave(_controller.text);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── _HeightPickerSheet ─────────────────────────────────────────────────────────

class _HeightPickerSheet extends StatelessWidget {
  const _HeightPickerSheet({
    required this.initialHeightCm,
    required this.onSave,
  });

  final double? initialHeightCm;
  final ValueChanged<double?> onSave;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Container(
      margin: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimens.shapeLg),
      ),
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Height',
            style: AppTextStyles.displaySmall.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          ZHeightPicker(
            initialCm: initialHeightCm,
            actionLabel: 'Save',
            onSubmit: (cm) {
              onSave(cm);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

// ── _WeightPickerSheet ─────────────────────────────────────────────────────────

class _WeightPickerSheet extends StatelessWidget {
  const _WeightPickerSheet({
    required this.initialWeightKg,
    required this.onSave,
  });

  final double? initialWeightKg;
  final ValueChanged<double?> onSave;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Container(
      margin: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimens.shapeLg),
      ),
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weight',
            style: AppTextStyles.displaySmall.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          ZWeightPicker(
            initialKg: initialWeightKg,
            actionLabel: 'Save',
            onSubmit: (kg) {
              onSave(kg);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
