/// Emergency Health Card Screen.
///
/// Read-only view of the user's critical medical information.
/// High-contrast, large text, minimal chrome — designed to be usable
/// by first responders with zero app knowledge.
/// Works offline via locally-cached data.
///
/// Full implementation: Phase 8, Task 8.11.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';

// ── Shared data model (used by both view & edit screens) ──────────────────────

@immutable
class EmergencyContact {
  const EmergencyContact({
    required this.name,
    required this.relationship,
    required this.phone,
  });

  final String name;
  final String relationship;
  final String phone;

  EmergencyContact copyWith({
    String? name,
    String? relationship,
    String? phone,
  }) =>
      EmergencyContact(
        name: name ?? this.name,
        relationship: relationship ?? this.relationship,
        phone: phone ?? this.phone,
      );
}

@immutable
class EmergencyCardData {
  const EmergencyCardData({
    this.bloodType = 'O+',
    this.allergies = const ['Penicillin', 'Shellfish'],
    this.medications = const ['Lisinopril 10mg', 'Metformin 500mg'],
    this.conditions = const ['Type 2 Diabetes', 'Hypertension'],
    this.contacts = const [
      EmergencyContact(
        name: 'Jordan Rivera',
        relationship: 'Spouse',
        phone: '+1 (555) 234-5678',
      ),
      EmergencyContact(
        name: 'Dr. Sarah Chen',
        relationship: 'Primary Physician',
        phone: '+1 (555) 987-6543',
      ),
    ],
  });

  final String bloodType;
  final List<String> allergies;
  final List<String> medications;
  final List<String> conditions;
  final List<EmergencyContact> contacts;

  EmergencyCardData copyWith({
    String? bloodType,
    List<String>? allergies,
    List<String>? medications,
    List<String>? conditions,
    List<EmergencyContact>? contacts,
  }) =>
      EmergencyCardData(
        bloodType: bloodType ?? this.bloodType,
        allergies: allergies ?? this.allergies,
        medications: medications ?? this.medications,
        conditions: conditions ?? this.conditions,
        contacts: contacts ?? this.contacts,
      );
}

/// Global provider — shared between view and edit screens.
final emergencyCardProvider =
    StateProvider<EmergencyCardData>((_) => const EmergencyCardData());

// ── EmergencyCardScreen ────────────────────────────────────────────────────────

/// Emergency Health Card — read-only view for first responders.
/// High-contrast, large text, offline-capable.
class EmergencyCardScreen extends ConsumerWidget {
  /// Creates the [EmergencyCardScreen].
  const EmergencyCardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = ref.watch(emergencyCardProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            const Icon(
              Icons.medical_information_rounded,
              color: AppColors.categoryHeart,
              size: 22,
            ),
            const SizedBox(width: AppDimens.spaceSm),
            Text(
              'Emergency Card',
              style:
                  AppTextStyles.h3.copyWith(color: AppColors.textPrimaryDark),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.edit_rounded,
              color: AppColors.textPrimaryDark,
            ),
            tooltip: 'Edit',
            onPressed: () => context.pushNamed(RouteNames.emergencyCardEdit),
          ),
          const SizedBox(width: AppDimens.spaceXs),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        children: [
          // ── SOS header banner ───────────────────────────────────────────
          _SosBanner(),

          const SizedBox(height: AppDimens.spaceMd),

          // ── Blood type ──────────────────────────────────────────────────
          _BloodTypeCard(bloodType: card.bloodType),

          const SizedBox(height: AppDimens.spaceMd),

          // ── Allergies ───────────────────────────────────────────────────
          if (card.allergies.isNotEmpty) ...[
            _MedicalSection(
              icon: Icons.warning_amber_rounded,
              iconColor: AppColors.categoryNutrition,
              title: 'Allergies',
              items: card.allergies,
              tagColor: AppColors.categoryNutrition,
            ),
            const SizedBox(height: AppDimens.spaceMd),
          ],

          // ── Medications ─────────────────────────────────────────────────
          if (card.medications.isNotEmpty) ...[
            _MedicalSection(
              icon: Icons.medication_rounded,
              iconColor: AppColors.categoryBody,
              title: 'Current Medications',
              items: card.medications,
              tagColor: AppColors.categoryBody,
            ),
            const SizedBox(height: AppDimens.spaceMd),
          ],

          // ── Conditions ──────────────────────────────────────────────────
          if (card.conditions.isNotEmpty) ...[
            _MedicalSection(
              icon: Icons.monitor_heart_rounded,
              iconColor: AppColors.categoryHeart,
              title: 'Medical Conditions',
              items: card.conditions,
              tagColor: AppColors.categoryHeart,
            ),
            const SizedBox(height: AppDimens.spaceMd),
          ],

          // ── Emergency contacts ──────────────────────────────────────────
          if (card.contacts.isNotEmpty) ...[
            _ContactsSection(contacts: card.contacts),
            const SizedBox(height: AppDimens.spaceMd),
          ],

          // ── Last updated note ───────────────────────────────────────────
          Center(
            child: Text(
              'Last updated: March 2026',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceXl),
        ],
      ),
    );
  }
}

// ── _SosBanner ─────────────────────────────────────────────────────────────────

class _SosBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceSm,
      ),
      decoration: BoxDecoration(
        color: AppColors.categoryHeart.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
        border:
            Border.all(color: AppColors.categoryHeart.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.emergency_rounded,
            color: AppColors.categoryHeart,
            size: 20,
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: Text(
              'FOR EMERGENCY USE — Show this screen to first responders',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.categoryHeart,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── _BloodTypeCard ─────────────────────────────────────────────────────────────

class _BloodTypeCard extends StatelessWidget {
  const _BloodTypeCard({required this.bloodType});

  final String bloodType;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.cardBackgroundDark,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.categoryHeart.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                bloodType,
                style: AppTextStyles.h1.copyWith(
                  color: AppColors.categoryHeart,
                  fontSize: 26,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppDimens.spaceMd),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Blood Type',
                style: AppTextStyles.labelXs.copyWith(
                  color: AppColors.textTertiary,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                bloodType,
                style: AppTextStyles.h1.copyWith(
                  color: AppColors.textPrimaryDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── _MedicalSection ────────────────────────────────────────────────────────────

class _MedicalSection extends StatelessWidget {
  const _MedicalSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.items,
    required this.tagColor,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final List<String> items;
  final Color tagColor;

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
          // Section title
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: AppDimens.spaceSm),
              Text(
                title.toUpperCase(),
                style: AppTextStyles.labelXs.copyWith(
                  color: AppColors.textTertiary,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceSm),
          // Tag chips
          Wrap(
            spacing: AppDimens.spaceSm,
            runSpacing: AppDimens.spaceXs,
            children: items
                .map(
                  (item) => _MedTag(label: item, color: tagColor),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ── _MedTag ────────────────────────────────────────────────────────────────────

class _MedTag extends StatelessWidget {
  const _MedTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimens.radiusChip),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textPrimaryDark,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ── _ContactsSection ───────────────────────────────────────────────────────────

class _ContactsSection extends StatelessWidget {
  const _ContactsSection({required this.contacts});

  final List<EmergencyContact> contacts;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackgroundDark,
        borderRadius: BorderRadius.circular(AppDimens.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              AppDimens.spaceMd,
              AppDimens.spaceMd,
              AppDimens.spaceXs,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.phone_rounded,
                  size: 18,
                  color: AppColors.categoryActivity,
                ),
                const SizedBox(width: AppDimens.spaceSm),
                Text(
                  'EMERGENCY CONTACTS',
                  style: AppTextStyles.labelXs.copyWith(
                    color: AppColors.textTertiary,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ...List.generate(contacts.length, (index) {
            final contact = contacts[index];
            final isLast = index == contacts.length - 1;
            return Column(
              children: [
                _ContactRow(contact: contact),
                if (!isLast)
                  Padding(
                    padding: const EdgeInsets.only(left: 68),
                    child: Container(
                      height: 1,
                      color: AppColors.borderDark.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ── _ContactRow ────────────────────────────────────────────────────────────────

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.contact});

  final EmergencyContact contact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: 12,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.categoryActivity.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                contact.name[0],
                style: AppTextStyles.h3.copyWith(
                  color: AppColors.categoryActivity,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppDimens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textPrimaryDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  contact.relationship,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            contact.phone,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.categoryActivity,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
