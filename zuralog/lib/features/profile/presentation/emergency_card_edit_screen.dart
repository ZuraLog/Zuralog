/// Emergency Health Card Edit Screen.
///
/// Form for editing all medical info: blood type selector, tag-style inputs for
/// allergies, medications, and conditions; up to 3 emergency contacts.
///
/// Full implementation: Phase 8, Task 8.11.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'emergency_card_screen.dart' show emergencyCardProvider, EmergencyCardData, EmergencyContact;

// ── EmergencyCardEditScreen ───────────────────────────────────────────────────

/// Edit screen for the Emergency Health Card.
/// Tag-style inputs, blood type picker, and up to 3 emergency contacts.
class EmergencyCardEditScreen extends ConsumerStatefulWidget {
  /// Creates the [EmergencyCardEditScreen].
  const EmergencyCardEditScreen({super.key});

  @override
  ConsumerState<EmergencyCardEditScreen> createState() =>
      _EmergencyCardEditScreenState();
}

class _EmergencyCardEditScreenState
    extends ConsumerState<EmergencyCardEditScreen> {
  late String _bloodType;
  late List<String> _allergies;
  late List<String> _medications;
  late List<String> _conditions;
  late List<EmergencyContact> _contacts;

  final _allergyController = TextEditingController();
  final _medicationController = TextEditingController();
  final _conditionController = TextEditingController();

  static const List<String> _bloodTypes = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-',
  ];

  @override
  void initState() {
    super.initState();
    final card = ref.read(emergencyCardProvider);
    _bloodType = card.bloodType;
    _allergies = List<String>.from(card.allergies);
    _medications = List<String>.from(card.medications);
    _conditions = List<String>.from(card.conditions);
    _contacts = List<EmergencyContact>.from(card.contacts);
    // Pad to 3 contact slots.
    while (_contacts.length < 3) {
      _contacts.add(
        const EmergencyContact(name: '', relationship: '', phone: ''),
      );
    }
  }

  @override
  void dispose() {
    _allergyController.dispose();
    _medicationController.dispose();
    _conditionController.dispose();
    super.dispose();
  }

  void _save() {
    final trimmed = _contacts
        .where((c) => c.name.trim().isNotEmpty)
        .toList();

    ref.read(emergencyCardProvider.notifier).state = EmergencyCardData(
      bloodType: _bloodType,
      allergies: _allergies,
      medications: _medications,
      conditions: _conditions,
      contacts: trimmed,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Emergency card saved',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textPrimaryDark,
          ),
        ),
        backgroundColor: AppColors.surfaceDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        ),
      ),
    );

    context.pop();
  }

  void _addTag(
    TextEditingController ctrl,
    List<String> list,
    StateSetter setState,
  ) {
    final val = ctrl.text.trim();
    if (val.isNotEmpty && !list.contains(val)) {
      setState(() => list.add(val));
      ctrl.clear();
    }
  }

  void _removeTag(List<String> list, int index, StateSetter setState) {
    setState(() => list.removeAt(index));
  }

  void _updateContact(int index, EmergencyContact updated) {
    setState(() => _contacts[index] = updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Edit Emergency Card',
          style: AppTextStyles.h3.copyWith(color: AppColors.textPrimaryDark),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              'Save',
              style: AppTextStyles.body.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppDimens.spaceXs),
        ],
      ),
      body: StatefulBuilder(
        builder: (context, setState) => ListView(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          children: [
            // ── Blood type ────────────────────────────────────────────────
            _SectionLabel('Blood Type'),
            _BloodTypeSelector(
              selected: _bloodType,
              options: _bloodTypes,
              onSelected: (val) => setState(() => _bloodType = val),
            ),

            // ── Allergies ─────────────────────────────────────────────────
            _SectionLabel('Allergies'),
            _TagEditor(
              items: _allergies,
              controller: _allergyController,
              placeholder: 'Add allergy (e.g., Penicillin)',
              tagColor: AppColors.categoryNutrition,
              onAdd: () => _addTag(_allergyController, _allergies, setState),
              onRemove: (i) => _removeTag(_allergies, i, setState),
            ),

            // ── Medications ───────────────────────────────────────────────
            _SectionLabel('Current Medications'),
            _TagEditor(
              items: _medications,
              controller: _medicationController,
              placeholder: 'Add medication (e.g., Lisinopril 10mg)',
              tagColor: AppColors.categoryBody,
              onAdd: () =>
                  _addTag(_medicationController, _medications, setState),
              onRemove: (i) => _removeTag(_medications, i, setState),
            ),

            // ── Conditions ────────────────────────────────────────────────
            _SectionLabel('Medical Conditions'),
            _TagEditor(
              items: _conditions,
              controller: _conditionController,
              placeholder: 'Add condition (e.g., Hypertension)',
              tagColor: AppColors.categoryHeart,
              onAdd: () =>
                  _addTag(_conditionController, _conditions, setState),
              onRemove: (i) => _removeTag(_conditions, i, setState),
            ),

            // ── Emergency contacts ────────────────────────────────────────
            _SectionLabel('Emergency Contacts (up to 3)'),
            ...List.generate(3, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
                child: _ContactEditor(
                  index: index,
                  contact: _contacts[index],
                  onChanged: (updated) => _updateContact(index, updated),
                ),
              );
            }),

            const SizedBox(height: AppDimens.spaceLg),

            // ── Save button ───────────────────────────────────────────────
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.primaryButtonText,
                padding:
                    const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimens.radiusButtonMd),
                ),
              ),
              onPressed: _save,
              child: Text(
                'Save Emergency Card',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.primaryButtonText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: AppDimens.spaceXxl),
          ],
        ),
      ),
    );
  }
}

// ── _BloodTypeSelector ─────────────────────────────────────────────────────────

class _BloodTypeSelector extends StatelessWidget {
  const _BloodTypeSelector({
    required this.selected,
    required this.options,
    required this.onSelected,
  });

  final String selected;
  final List<String> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDimens.spaceSm,
      runSpacing: AppDimens.spaceSm,
      children: options.map((type) {
        final isSelected = type == selected;
        return GestureDetector(
          onTap: () => onSelected(type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.categoryHeart
                  : AppColors.cardBackgroundDark,
              borderRadius: BorderRadius.circular(AppDimens.radiusInput),
              border: Border.all(
                color: isSelected
                    ? AppColors.categoryHeart
                    : AppColors.borderDark,
              ),
            ),
            child: Text(
              type,
              style: AppTextStyles.body.copyWith(
                color: isSelected
                    ? AppColors.backgroundDark
                    : AppColors.textPrimaryDark,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── _TagEditor ─────────────────────────────────────────────────────────────────

class _TagEditor extends StatelessWidget {
  const _TagEditor({
    required this.items,
    required this.controller,
    required this.placeholder,
    required this.tagColor,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> items;
  final TextEditingController controller;
  final String placeholder;
  final Color tagColor;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.cardBackgroundDark,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Existing tags
          if (items.isNotEmpty) ...[
            Wrap(
              spacing: AppDimens.spaceSm,
              runSpacing: AppDimens.spaceXs,
              children: List.generate(items.length, (index) {
                return _RemovableTag(
                  label: items[index],
                  color: tagColor,
                  onRemove: () => onRemove(index),
                );
              }),
            ),
            const SizedBox(height: AppDimens.spaceSm),
          ],
          // Input row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimaryDark,
                  ),
                  cursorColor: AppColors.primary,
                  decoration: InputDecoration(
                    hintText: placeholder,
                    hintStyle: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spaceSm,
                      vertical: AppDimens.spaceSm,
                    ),
                    filled: true,
                    fillColor: AppColors.inputBackgroundDark,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimens.radiusInput),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => onAdd(),
                ),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── _RemovableTag ──────────────────────────────────────────────────────────────

class _RemovableTag extends StatelessWidget {
  const _RemovableTag({
    required this.label,
    required this.color,
    required this.onRemove,
  });

  final String label;
  final Color color;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 6, top: 5, bottom: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimaryDark,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close_rounded,
              size: 14,
              color: color.withValues(alpha: 0.70),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _ContactEditor ─────────────────────────────────────────────────────────────

class _ContactEditor extends StatefulWidget {
  const _ContactEditor({
    required this.index,
    required this.contact,
    required this.onChanged,
  });

  final int index;
  final EmergencyContact contact;
  final ValueChanged<EmergencyContact> onChanged;

  @override
  State<_ContactEditor> createState() => _ContactEditorState();
}

class _ContactEditorState extends State<_ContactEditor> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _relCtrl;
  late final TextEditingController _phoneCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.contact.name);
    _relCtrl = TextEditingController(text: widget.contact.relationship);
    _phoneCtrl = TextEditingController(text: widget.contact.phone);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _relCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _notify() {
    widget.onChanged(
      EmergencyContact(
        name: _nameCtrl.text,
        relationship: _relCtrl.text,
        phone: _phoneCtrl.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.cardBackgroundDark,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.categoryActivity.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${widget.index + 1}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.categoryActivity,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Text(
                'Contact ${widget.index + 1}',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceSm),

          // Name
          _ContactField(
            controller: _nameCtrl,
            label: 'Full Name',
            onChanged: (_) => _notify(),
          ),
          const SizedBox(height: AppDimens.spaceSm),

          // Relationship
          _ContactField(
            controller: _relCtrl,
            label: 'Relationship',
            onChanged: (_) => _notify(),
          ),
          const SizedBox(height: AppDimens.spaceSm),

          // Phone
          _ContactField(
            controller: _phoneCtrl,
            label: 'Phone Number',
            keyboardType: TextInputType.phone,
            onChanged: (_) => _notify(),
          ),
        ],
      ),
    );
  }
}

// ── _ContactField ──────────────────────────────────────────────────────────────

class _ContactField extends StatelessWidget {
  const _ContactField({
    required this.controller,
    required this.label,
    required this.onChanged,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.textPrimaryDark,
      ),
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTextStyles.caption.copyWith(
          color: AppColors.textTertiary,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceSm,
          vertical: AppDimens.spaceSm,
        ),
        filled: true,
        fillColor: AppColors.inputBackgroundDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusInput),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusInput),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

// ── _SectionLabel ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, AppDimens.spaceLg, 0, AppDimens.spaceSm),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.labelXs.copyWith(
          color: AppColors.textTertiary,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
