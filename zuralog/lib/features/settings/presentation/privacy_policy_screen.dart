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
      appBar: const ZuralogAppBar(title: 'Privacy Policy', showProfileAvatar: false),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceLg,
        ),
        children: const [
          _PolicyHeader(
            title: 'ZuraLog Privacy Policy',
            subtitle: 'Effective Date: March 14, 2026',
          ),
          SizedBox(height: AppDimens.spaceLg),
          _PolicySection(
            title: '1. Introduction',
            body:
                'ZuraLog ("we," "our," or "us") respects your privacy and is '
                'committed to protecting your personal health information. This '
                'Privacy Policy explains how we collect, use, disclose, and '
                'safeguard your information when you use our mobile application '
                'and services (collectively, the "Service").\n\n'
                'This policy applies to users in the United States and '
                'incorporates your rights under the California Consumer Privacy '
                'Act (CCPA/CPRA) and other applicable state privacy laws, '
                'including those in Virginia, Colorado, Connecticut, Utah, Oregon, '
                'Texas, and Montana. If you are located outside the United States, '
                'please see Section 14 ("International Users").\n\n'
                'ZuraLog is a consumer wellness application. We are not a covered '
                'entity or business associate under HIPAA. Health data you share '
                'with us is processed under this Privacy Policy, not HIPAA.\n\n'
                'By using the Service, you agree to the collection and use of '
                'information in accordance with this policy. If you do not agree, '
                'please do not use our Service.',
          ),
          _PolicySection(
            title: '2. Information We Collect',
            body:
                'Account & Profile Information:\n'
                '• Name, email address, and display name\n'
                '• Date of birth (optional, for age-based personalization)\n'
                '• Gender (optional, self-identified)\n'
                '• Fitness level and health/wellness goals\n'
                '• AI coach persona preference\n\n'
                'Health & Fitness Data (with your explicit permission from '
                'connected services such as Apple Health, Google Health Connect, '
                'Strava, Fitbit, Oura, Polar, Withings, Garmin, and Whoop):\n'
                '• Activity: steps, workouts, calories, distance, exercise minutes\n'
                '• Biometrics: heart rate, HRV, SpO2, blood pressure, body '
                'temperature, respiratory rate\n'
                '• Body composition: weight measurements\n'
                '• Sleep: duration, stages, quality scores, efficiency, latency\n'
                '• Nutrition: calories, macronutrients, water intake, meal logs\n'
                '• Wellness: stress scores, mood logs, recovery readiness\n\n'
                'User-Generated Wellness Data:\n'
                '• Journal entries (mood, energy, stress, sleep ratings and notes)\n'
                '• Quick logs (water, mood, energy, stress, pain, notes)\n'
                '• Custom tags for wellness tracking\n'
                '• Emergency health card (blood type, allergies, medications, '
                'conditions, emergency contact) — stored locally by default, '
                'synced only if you enable cloud backup\n\n'
                'AI Coach Interactions:\n'
                '• Conversation histories and AI responses\n'
                '• Attachments shared in chat (e.g., meal photos)\n'
                '• AI-generated personalization memory — you can view and delete '
                'this at any time from Settings\n\n'
                'Subscription Data:\n'
                '• Subscription tier and expiration date\n'
                '• Payment processing is handled entirely by RevenueCat through '
                'the App Store or Google Play — we do not collect or store your '
                'payment details\n\n'
                'Usage & Device Data:\n'
                '• IP address and approximate location derived from IP\n'
                '• Device identifiers, platform, OS version, app version\n'
                '• Screen navigation, interaction events, session duration\n'
                '• Push notification delivery and read status\n'
                '• Error logs and crash reports\n\n'
                'You can opt out of analytics collection at any time from '
                'Settings → Privacy & Data.',
          ),
          _PolicySection(
            title: '3. How We Use Your Information',
            body:
                'We use the information we collect to:\n\n'
                '• Provide, maintain, and improve our Service\n'
                '• Personalize your AI health coach with relevant context from '
                'your health data, journals, and past conversations\n'
                '• Generate health insights, trends, and recommendations\n'
                '• Send notifications (insights, anomaly alerts, streak milestones, '
                'achievements, daily briefings, reminders) subject to your '
                'notification preferences and quiet hours\n'
                '• Track engagement streaks and unlock achievements\n'
                '• Respond to your inquiries and support requests\n'
                '• Monitor app performance and diagnose errors\n'
                '• Comply with legal obligations\n\n'
                'We do not sell your personal health information to third parties.',
          ),
          _PolicySection(
            title: '4. AI & Automated Processing',
            body:
                'ZuraLog uses AI to provide personalized health coaching and '
                'insights:\n\n'
                '• AI Coaching: When you message the AI coach, your message and '
                'relevant health context are sent to a third-party LLM provider '
                'for response generation. The AI may retrieve data from connected '
                'integrations in real time.\n\n'
                '• Personalization Memory: The AI generates short contextual '
                'summaries stored as vector embeddings in a secure, per-user '
                'isolated database. You can delete your AI memory at any time.\n\n'
                '• Insights: We analyze your health data to surface trends and '
                'anomalies. This is automated but does not produce legal or '
                'similarly significant effects.\n\n'
                'AI insights are for informational and wellness purposes only '
                'and do not constitute medical advice.',
          ),
          _PolicySection(
            title: '5. Data Sharing and Disclosure',
            body:
                'We do not sell, rent, or share your data for advertising or '
                'marketing. We may share information only as follows:\n\n'
                'Service Providers (under strict confidentiality agreements):\n'
                '• Cloud infrastructure: Supabase (database/auth), Railway '
                '(hosting), Redis (caching)\n'
                '• AI processing: OpenRouter (LLM inference), OpenAI (text '
                'embeddings), Pinecone (vector search)\n'
                '• Analytics & monitoring: PostHog (product analytics, subject '
                'to your opt-out), Sentry (error monitoring)\n'
                '• Push notifications: Firebase Cloud Messaging\n'
                '• Payments: RevenueCat (subscription management)\n\n'
                'Health Platform Integrations:\n'
                '• When you connect Strava, Fitbit, Oura, Polar, Withings, or '
                'other platforms, we exchange data via OAuth 2.0 authorization '
                'you explicitly grant. You can disconnect any integration at '
                'any time.\n\n'
                'Other Circumstances:\n'
                '• Law enforcement when required by law, subpoena, or court order\n'
                '• Successor entities in mergers or acquisitions (with prior '
                'notice to you)',
          ),
          _PolicySection(
            title: '6. Sensitive Personal Information',
            body:
                'Biometric data (heart rate, HRV, SpO2, blood pressure, body '
                'temperature) and health data (sleep, nutrition, weight, stress, '
                'mood, medical info from emergency health cards) are considered '
                'sensitive personal information.\n\n'
                'We process this data solely to deliver your in-app insights and '
                'AI coaching. We do not use it for cross-context behavioral '
                'advertising or profiling unrelated to the Service.\n\n'
                'We comply with applicable state biometric privacy laws, including '
                'the Illinois BIPA, the Texas biometric identifier law, and the '
                'Washington biometric identifier law. We do not sell biometric data.',
          ),
          _PolicySection(
            title: '7. Your Privacy Rights',
            body:
                'All Users Can:\n'
                '• Review personal data via the Settings screen\n'
                '• Delete AI memory items (individually or all at once)\n'
                '• Disconnect third-party health integrations\n'
                '• Opt out of analytics data collection\n'
                '• Customize notification preferences and quiet hours\n'
                '• Request account and data deletion\n\n'
                'California Residents (CCPA/CPRA) additionally have the right to:\n'
                '• Know what data we collect and how we use it\n'
                '• Delete your personal information\n'
                '• Correct inaccurate personal information\n'
                '• Data portability (receive data in a machine-readable format)\n'
                '• Limit use of sensitive personal information\n'
                '• Opt out of sale/sharing (we do not sell or share your data)\n'
                '• Non-discrimination for exercising your rights\n\n'
                'Residents of Virginia, Colorado, Connecticut, Utah, Oregon, '
                'Texas, Montana, and other states with privacy laws have similar '
                'rights, including access, correction, deletion, portability, and '
                'opt-out rights.\n\n'
                'To exercise your rights, contact privacy@zuralog.com. We will '
                'respond within 45 days.',
          ),
          _PolicySection(
            title: '8. Appeal Process',
            body:
                'If we decline your privacy request, you may appeal by emailing '
                'privacy@zuralog.com with the subject "Privacy Rights Appeal." '
                'We will respond within 60 days. If unsatisfied, you may contact '
                "your state's attorney general.",
          ),
          _PolicySection(
            title: '9. Global Privacy Control',
            body:
                'ZuraLog honors the Global Privacy Control (GPC) signal. If your '
                'browser or device sends a GPC signal, we treat it as a valid '
                'opt-out request under applicable state privacy laws.',
          ),
          _PolicySection(
            title: '10. Data Retention',
            body:
                'We retain your personal data for as long as your account is '
                'active or as needed to provide the Service.\n\n'
                '• Account & profile data: retained until account deletion\n'
                '• Health & fitness data: retained until account deletion or '
                'integration disconnection\n'
                '• AI conversations: retained until you delete them or your account\n'
                '• AI memory: retained until you clear it or delete your account\n'
                '• Usage analytics: individual data retained up to 24 months; '
                'aggregated data retained indefinitely\n'
                '• Error/crash logs: retained up to 90 days\n\n'
                'Request deletion via Privacy & Data in Settings or by emailing '
                'privacy@zuralog.com. We process requests within 45 days.',
          ),
          _PolicySection(
            title: '11. De-Identified & Aggregated Data',
            body:
                'We may create de-identified or aggregated data that cannot '
                'reasonably identify you. We may use this data for research, '
                'product improvement, and analytics. We will not attempt to '
                're-identify de-identified data.',
          ),
          _PolicySection(
            title: '12. Health Data Security',
            body:
                'We implement industry-standard security measures including:\n\n'
                '• Encryption in transit (TLS 1.2+) and at rest (AES-256)\n'
                '• Row-level security policies isolating each user\'s data\n'
                '• Per-user namespace isolation for AI memory and vectors\n'
                '• OAuth 2.0 token management with secure storage\n'
                '• Sensitive credentials stored in encrypted device storage\n'
                '• Strict access controls and regular security reviews\n\n'
                'Emergency Health Card data is stored locally on your device by '
                'default and is only synced to our servers if you explicitly '
                'enable cloud backup.\n\n'
                'No system is 100% secure. If you believe your account has been '
                'compromised, contact us immediately at support@zuralog.com.',
          ),
          _PolicySection(
            title: '13. Cookies & Tracking',
            body:
                'Our mobile app uses the following tracking technologies:\n\n'
                '• PostHog SDK: product analytics (subject to your opt-out '
                'preference in Settings → Privacy & Data)\n'
                '• Sentry SDK: error monitoring and crash reporting\n'
                '• Firebase SDK: push notification delivery\n\n'
                'We do not use tracking for targeted advertising or cross-context '
                'behavioral profiling. See our Cookie Policy at '
                'zuralog.com/cookie-policy for website tracking details.',
          ),
          _PolicySection(
            title: '14. International Users',
            body:
                'The Service is designed for users in the United States. If you '
                'access the Service from outside the US, your data will be '
                'transferred to and processed in the United States, where data '
                'protection laws may differ from your jurisdiction. By using the '
                'Service, you consent to this transfer.',
          ),
          _PolicySection(
            title: '15. Children\'s Privacy',
            body:
                'Our Service is not directed to individuals under the age of 13 '
                '(or 16 in jurisdictions where applicable). We do not knowingly '
                'collect personal information from children under 13 or sell/share '
                'personal information of consumers under 16. If you believe we '
                'have collected information from a child, please contact us '
                'immediately at privacy@zuralog.com.',
          ),
          _PolicySection(
            title: '16. Changes to This Policy',
            body:
                'We may update this Privacy Policy from time to time. We will '
                'notify you of material changes by email or in-app notice at least '
                '30 days before changes take effect. Your continued use of the '
                'Service after the effective date constitutes acceptance of the '
                'updated policy.',
          ),
          _PolicySection(
            title: '17. Contact Us',
            body:
                'If you have any questions about this Privacy Policy or our '
                'privacy practices, please contact us at:\n\n'
                'ZuraLog, Inc.\n'
                'support@zuralog.com\n'
                'https://zuralog.com/privacy-policy',
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

// ── _PolicySection ─────────────────────────────────────────────────────────────

class _PolicySection extends StatelessWidget {
  const _PolicySection({required this.title, required this.body});

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

// ── _PolicyFooter ──────────────────────────────────────────────────────────────

class _PolicyFooter extends StatelessWidget {
  const _PolicyFooter();

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
