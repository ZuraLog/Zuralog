/// Terms of Service Screen.
///
/// Full terms of service legal text.
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

// ── TermsOfServiceScreen ───────────────────────────────────────────────────────

/// Terms of Service screen — full legal text.
class TermsOfServiceScreen extends StatelessWidget {
  /// Creates the [TermsOfServiceScreen].
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ZuralogScaffold(
      appBar: const ZuralogAppBar(title: 'Terms of Service', showProfileAvatar: false),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceLg,
        ),
        children: const [
          _TermsHeader(
            title: 'ZuraLog Terms of Service',
            subtitle: 'Last Updated: March 1, 2026',
          ),
          SizedBox(height: AppDimens.spaceLg),
          _TermsSection(
            title: '1. Acceptance of Terms',
            body:
                'By downloading, installing, or using the ZuraLog mobile application '
                'or related services (the "Service"), you agree to be bound by these '
                'Terms of Service ("Terms"). If you do not agree to these Terms, do '
                'not use the Service.\n\n'
                'These Terms constitute a legally binding agreement between you and '
                'ZuraLog, Inc. ("ZuraLog," "we," "our," or "us").',
          ),
          _TermsSection(
            title: '2. Description of Service',
            body:
                'ZuraLog is a personal health intelligence platform that aggregates '
                'health and fitness data from multiple sources, provides AI-powered '
                'coaching, trend analysis, and personalized insights to help you '
                'achieve your health goals.\n\n'
                'The Service is intended for informational and personal wellness '
                'purposes only and does not constitute medical advice.',
          ),
          _TermsSection(
            title: '3. Medical Disclaimer',
            body:
                'IMPORTANT: ZuraLog is NOT a medical device and does NOT provide '
                'medical advice, diagnosis, or treatment. The information provided '
                'through the Service, including AI-generated insights, is for '
                'informational and wellness purposes only.\n\n'
                'Always consult a qualified healthcare professional before making '
                'any decisions related to your health, medication, or medical '
                'treatment. In case of a medical emergency, call your local '
                'emergency services immediately.',
          ),
          _TermsSection(
            title: '4. Account Registration',
            body:
                'To use certain features of the Service, you must create an account. '
                'You agree to:\n\n'
                '• Provide accurate, current, and complete information\n'
                '• Maintain the security of your password\n'
                '• Accept responsibility for all activities under your account\n'
                '• Notify us immediately of any unauthorized use\n\n'
                'You must be at least 13 years of age (16 in the EU) to create an '
                'account. We reserve the right to terminate accounts that violate '
                'these Terms.',
          ),
          _TermsSection(
            title: '5. Subscriptions and Billing',
            body:
                'Certain features of the Service require a paid subscription. '
                'By subscribing, you agree to pay the applicable fees.\n\n'
                '• Subscriptions renew automatically unless cancelled before the '
                'renewal date\n'
                '• All payments are processed through the App Store (iOS) or '
                'Google Play Store (Android)\n'
                '• Refunds are subject to the respective app store\'s refund policy\n'
                '• We reserve the right to change subscription pricing with '
                '30 days\' notice',
          ),
          _TermsSection(
            title: '6. Acceptable Use',
            body:
                'You agree not to:\n\n'
                '• Use the Service for any unlawful purpose\n'
                '• Attempt to gain unauthorized access to any part of the Service\n'
                '• Reverse engineer or decompile any part of the Service\n'
                '• Use the Service to transmit harmful or offensive content\n'
                '• Share your account credentials with others\n'
                '• Use automated tools to access the Service without authorization',
          ),
          _TermsSection(
            title: '7. Third-Party Integrations',
            body:
                'The Service integrates with third-party platforms (e.g., Strava, '
                'Fitbit, Apple Health, Google Health Connect). These integrations '
                'are subject to the respective third parties\' terms of service and '
                'privacy policies.\n\n'
                'We are not responsible for the availability, accuracy, or practices '
                'of third-party services. Your use of third-party services is at '
                'your own risk.',
          ),
          _TermsSection(
            title: '8. Intellectual Property',
            body:
                'The Service and its original content, features, and functionality '
                'are owned by ZuraLog and are protected by copyright, trademark, '
                'and other intellectual property laws.\n\n'
                'You retain ownership of all health data you input into the Service. '
                'By using the Service, you grant ZuraLog a limited license to use '
                'your data solely to provide and improve the Service.',
          ),
          _TermsSection(
            title: '9. Limitation of Liability',
            body:
                'TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, ZURALOG '
                'SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, '
                'CONSEQUENTIAL, OR PUNITIVE DAMAGES ARISING OUT OF OR RELATED TO '
                'YOUR USE OF THE SERVICE.\n\n'
                'IN NO EVENT SHALL OUR TOTAL LIABILITY EXCEED THE AMOUNT PAID BY '
                'YOU TO ZURALOG IN THE TWELVE MONTHS PRECEDING THE CLAIM.',
          ),
          _TermsSection(
            title: '10. Termination',
            body:
                'We reserve the right to suspend or terminate your account at any '
                'time for violations of these Terms. You may terminate your account '
                'at any time through the Account Settings screen.\n\n'
                'Upon termination, your right to use the Service will immediately '
                'cease. Sections 3, 8, 9, and 11 survive termination.',
          ),
          _TermsSection(
            title: '11. Governing Law',
            body:
                'These Terms shall be governed by and construed in accordance with '
                'the laws of the State of California, without regard to its conflict '
                'of law provisions.\n\n'
                'Any dispute arising from these Terms or the Service shall be '
                'resolved through binding arbitration, except where prohibited by '
                'applicable law.',
          ),
          _TermsSection(
            title: '12. Changes to Terms',
            body:
                'We reserve the right to modify these Terms at any time. We will '
                'notify you of material changes with at least 14 days\' notice. '
                'Your continued use of the Service after the effective date of '
                'revised Terms constitutes your acceptance.',
          ),
          _TermsSection(
            title: '13. Contact',
            body:
                'Questions about these Terms? Contact us at:\n\n'
                'ZuraLog, Inc.\n'
                'support@zuralog.com\n'
                'https://zuralog.com/terms',
          ),
          SizedBox(height: AppDimens.spaceXxl),
          _TermsFooter(),
        ],
      ),
    );
  }
}

// ── _TermsHeader ───────────────────────────────────────────────────────────────

class _TermsHeader extends StatelessWidget {
  const _TermsHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.displaySmall.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: AppDimens.spaceXs),
        Text(
          subtitle,
          style: AppTextStyles.bodyMedium.copyWith(
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ── _TermsSection ──────────────────────────────────────────────────────────────

class _TermsSection extends StatelessWidget {
  const _TermsSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = AppColorsOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.titleMedium.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            body,
            style: AppTextStyles.bodyMedium.copyWith(
              color: colors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _TermsFooter ───────────────────────────────────────────────────────────────

class _TermsFooter extends StatelessWidget {
  const _TermsFooter();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '© 2026 ZuraLog, Inc. All rights reserved.',
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
        textAlign: TextAlign.center,
      ),
    );
  }
}
