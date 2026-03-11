/// Privacy Policy Screen.
///
/// Full GDPR/CCPA-compliant privacy policy text.
/// Accessible from Privacy & Data Settings and About screen.
///
/// Full implementation: Phase 8, Task 8.12.
library;

import 'package:flutter/material.dart';
import 'package:zuralog/core/theme/app_colors.dart';
import 'package:zuralog/core/theme/app_dimens.dart';
import 'package:zuralog/core/theme/app_text_styles.dart';
import 'package:zuralog/shared/widgets/layout/zuralog_scaffold.dart';
import 'package:zuralog/shared/widgets/zuralog_app_bar.dart';

// ── PrivacyPolicyScreen ────────────────────────────────────────────────────────

/// Privacy Policy screen — full legal text for GDPR/CCPA compliance.
class PrivacyPolicyScreen extends StatelessWidget {
  /// Creates the [PrivacyPolicyScreen].
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ZuralogScaffold(
      appBar: ZuralogAppBar(title: 'Privacy Policy'),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceLg,
        ),
        children: const [
          _PolicyHeader(
            title: 'Zuralog Privacy Policy',
            subtitle: 'Effective Date: March 1, 2026',
          ),
          SizedBox(height: AppDimens.spaceLg),
          _PolicySection(
            title: '1. Introduction',
            body:
                'Zuralog ("we," "our," or "us") respects your privacy and is '
                'committed to protecting your personal health information. This '
                'Privacy Policy explains how we collect, use, disclose, and '
                'safeguard your information when you use our mobile application '
                'and services (collectively, the "Service").\n\n'
                'By using the Service, you agree to the collection and use of '
                'information in accordance with this policy. If you do not agree, '
                'please do not use our Service.',
          ),
          _PolicySection(
            title: '2. Information We Collect',
            body:
                'We collect information you provide directly to us, such as:\n\n'
                '• Account information (name, email, password)\n'
                '• Health and fitness data (steps, heart rate, sleep, workouts)\n'
                '• User preferences and settings\n'
                '• Emergency health card data (stored locally and optionally synced)\n'
                '• Communications with our AI coach\n\n'
                'We also collect information automatically when you use our Service, '
                'including device identifiers, usage analytics (if opted in), and '
                'integration data from connected third-party apps (Strava, Fitbit, '
                'Apple Health, Google Health Connect).',
          ),
          _PolicySection(
            title: '3. How We Use Your Information',
            body:
                'We use the information we collect to:\n\n'
                '• Provide, maintain, and improve our Service\n'
                '• Personalize your AI health coach experience\n'
                '• Generate health insights, trends, and recommendations\n'
                '• Send notifications and reminders (with your consent)\n'
                '• Respond to your inquiries and support requests\n'
                '• Comply with legal obligations\n\n'
                'We do not sell your personal health information to third parties.',
          ),
          _PolicySection(
            title: '4. Data Sharing and Disclosure',
            body:
                'We may share your information with:\n\n'
                '• Service providers who assist in operating our Service\n'
                '• Third-party integrations you authorize (e.g., Strava, Fitbit)\n'
                '• Law enforcement or regulatory authorities when required by law\n'
                '• Successor entities in the event of a merger or acquisition\n\n'
                'All service providers are contractually obligated to protect your '
                'data and may only use it for the purposes we specify.',
          ),
          _PolicySection(
            title: '5. Data Retention',
            body:
                'We retain your personal data for as long as your account is '
                'active or as needed to provide the Service. You may request '
                'deletion of your data at any time through the Privacy & Data '
                'settings screen. We will delete your data within 30 days of '
                'receiving a verified deletion request.',
          ),
          _PolicySection(
            title: '6. Your Rights (GDPR / CCPA)',
            body:
                'Depending on your location, you may have the following rights:\n\n'
                '• Access: Request a copy of the personal data we hold about you\n'
                '• Rectification: Request correction of inaccurate data\n'
                '• Erasure: Request deletion of your personal data\n'
                '• Portability: Receive your data in a machine-readable format\n'
                '• Opt-out: Opt out of analytics data collection\n'
                '• Restriction: Request restriction of data processing\n\n'
                'To exercise these rights, contact us at privacy@zuralog.com.',
          ),
          _PolicySection(
            title: '7. Health Data Security',
            body:
                'We implement industry-standard security measures including '
                'encryption at rest and in transit, access controls, and regular '
                'security audits. Health data is stored in Supabase PostgreSQL with '
                'row-level security policies.\n\n'
                'Emergency Health Card data is stored locally on your device by '
                'default and is only synced to our servers if you explicitly '
                'enable cloud backup.',
          ),
          _PolicySection(
            title: '8. Children\'s Privacy',
            body:
                'Our Service is not directed to individuals under the age of 13 '
                '(or 16 in the EU). We do not knowingly collect personal information '
                'from children. If you believe we have collected information from a '
                'child, please contact us immediately.',
          ),
          _PolicySection(
            title: '9. Changes to This Policy',
            body:
                'We may update this Privacy Policy from time to time. We will '
                'notify you of any material changes by updating the effective date '
                'at the top of this policy and, where appropriate, sending you a '
                'notification. Your continued use of the Service after any changes '
                'constitutes your acceptance of the updated policy.',
          ),
          _PolicySection(
            title: '10. Contact Us',
            body:
                'If you have any questions about this Privacy Policy or our '
                'privacy practices, please contact us at:\n\n'
                'Zuralog, Inc.\n'
                'privacy@zuralog.com\n'
                'https://zuralog.com/privacy',
          ),
          SizedBox(height: AppDimens.spaceXxl),
          _PolicyFooter(),
        ],
      ),
    );
  }
}

// ── _PolicyHeader ──────────────────────────────────────────────────────────────

class _PolicyHeader extends StatelessWidget {
  const _PolicyHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.displaySmall.copyWith(color: AppColors.textPrimaryDark),
        ),
        const SizedBox(height: AppDimens.spaceXs),
        Text(
          subtitle,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ── _PolicySection ─────────────────────────────────────────────────────────────

class _PolicySection extends StatelessWidget {
  const _PolicySection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimaryDark),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            body,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _PolicyFooter ──────────────────────────────────────────────────────────────

class _PolicyFooter extends StatelessWidget {
  const _PolicyFooter();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '© 2026 Zuralog, Inc. All rights reserved.',
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
        textAlign: TextAlign.center,
      ),
    );
  }
}
