/// Emergency Health Card Screen.
///
/// Read-only view of the user's critical medical information.
/// High-contrast, large text, minimal chrome — designed to be usable
/// by first responders with zero app knowledge.
/// Works offline via locally-cached data (FlutterSecureStorage).
///
/// Full implementation: Phase 8, Task 8.11.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:zuralog/core/router/route_names.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/features/profile/domain/emergency_card_models.dart';
import 'package:zuralog/shared/widgets/layout/zuralog_scaffold.dart';

export 'package:zuralog/features/profile/domain/emergency_card_models.dart'
    show EmergencyCardData, EmergencyContact;

// ── Persistence layer ─────────────────────────────────────────────────────────

const _kStorageKey = 'emergency_card_data';
const _storage = FlutterSecureStorage();

/// Async notifier that persists EmergencyCardData to FlutterSecureStorage.
class EmergencyCardNotifier extends AsyncNotifier<EmergencyCardData> {
  @override
  Future<EmergencyCardData> build() async {
    final raw = await _storage.read(key: _kStorageKey);
    if (raw == null) return const EmergencyCardData();
    try {
      return EmergencyCardData.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      // Corrupt data — reset to empty.
      return const EmergencyCardData();
    }
  }

  /// Persist updated card and refresh state.
  Future<void> save(EmergencyCardData data) async {
    state = const AsyncLoading();
    final withTimestamp = data.copyWith(updatedAt: DateTime.now());
    await _storage.write(
      key: _kStorageKey,
      value: jsonEncode(withTimestamp.toJson()),
    );
    state = AsyncData(withTimestamp);
  }
}

/// Global provider — shared between view and edit screens.
final emergencyCardProvider =
    AsyncNotifierProvider<EmergencyCardNotifier, EmergencyCardData>(
  EmergencyCardNotifier.new,
);

// ── _formatUpdatedAt ──────────────────────────────────────────────────────────

String _formatUpdatedAt(DateTime dt) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${months[dt.month - 1]} ${dt.year}';
}

// ── EmergencyCardScreen ────────────────────────────────────────────────────────

/// Emergency Health Card — read-only view for first responders.
/// High-contrast, large text, offline-capable via FlutterSecureStorage.
class EmergencyCardScreen extends ConsumerWidget {
  /// Creates the [EmergencyCardScreen].
  const EmergencyCardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardAsync = ref.watch(emergencyCardProvider);

    return ZuralogScaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Row(
          children: [
            Icon(
              Icons.medical_information_rounded,
              color: AppColors.categoryHeart,
              size: 22,
            ),
            SizedBox(width: AppDimens.spaceSm),
            Text('Emergency Card'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.edit_rounded,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            tooltip: 'Edit',
            onPressed: () => context.pushNamed(RouteNames.emergencyCardEdit),
          ),
          const SizedBox(width: AppDimens.spaceXs),
        ],
      ),
      body: cardAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (_, err) => Center(
          child: Text(
            'Unable to load emergency card.',
            style:
                AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary),
          ),
        ),
        data: (card) => card.isEmpty
            ? _EmptyState(
                onSetUp: () =>
                    context.pushNamed(RouteNames.emergencyCardEdit),
              )
            : _CardContent(card: card),
      ),
    );
  }
}

// ── _EmptyState ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onSetUp});

  final VoidCallback onSetUp;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.categoryHeart.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.medical_information_rounded,
                size: 36,
                color: AppColors.categoryHeart,
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Text(
              'No Emergency Card Yet',
              style:
                  AppTextStyles.displaySmall.copyWith(color: AppColors.textPrimaryDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              'Add your blood type, allergies, medications, and emergency contacts so first responders can help you faster.',
              style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimens.spaceLg),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.categoryHeart,
                foregroundColor: AppColors.textPrimaryDark,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceLg,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimens.radiusButtonMd),
                ),
              ),
              onPressed: onSetUp,
              child: Text(
                'Set Up Emergency Card',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textPrimaryDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── _CardContent ──────────────────────────────────────────────────────────────

class _CardContent extends StatelessWidget {
  const _CardContent({required this.card});

  final EmergencyCardData card;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      children: [
        // ── SOS header banner ─────────────────────────────────────────────
        _SosBanner(),

        const SizedBox(height: AppDimens.spaceMd),

        // ── Blood type ────────────────────────────────────────────────────
        if (card.bloodType.isNotEmpty) ...[
          _BloodTypeCard(bloodType: card.bloodType),
          const SizedBox(height: AppDimens.spaceMd),
        ],

        // ── Allergies ─────────────────────────────────────────────────────
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

        // ── Medications ───────────────────────────────────────────────────
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

        // ── Conditions ────────────────────────────────────────────────────
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

        // ── Emergency contacts ─────────────────────────────────────────────
        if (card.contacts.isNotEmpty) ...[
          _ContactsSection(contacts: card.contacts),
          const SizedBox(height: AppDimens.spaceMd),
        ],

        // ── Last updated note ──────────────────────────────────────────────
        if (card.updatedAt != null)
          Center(
            child: Text(
              'Last updated: ${_formatUpdatedAt(card.updatedAt!)}',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),

        const SizedBox(height: AppDimens.spaceXl),
      ],
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
              style: AppTextStyles.bodySmall.copyWith(
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
                style: AppTextStyles.displayLarge.copyWith(
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
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textTertiary,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                bloodType,
                style: AppTextStyles.displayLarge.copyWith(
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
                style: AppTextStyles.labelSmall.copyWith(
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
                  style: AppTextStyles.labelSmall.copyWith(
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

  Future<void> _call() async {
    final uri = Uri(scheme: 'tel', path: contact.phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: contact.phone.isNotEmpty ? _call : null,
      child: Padding(
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
                  contact.name.isNotEmpty ? contact.name[0] : '?',
                  style: AppTextStyles.titleMedium.copyWith(
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
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textPrimaryDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    contact.relationship,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  contact.phone,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.categoryActivity,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (contact.phone.isNotEmpty) ...[
                  const SizedBox(width: AppDimens.spaceXs),
                  const Icon(
                    Icons.phone_rounded,
                    size: 16,
                    color: AppColors.categoryActivity,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
