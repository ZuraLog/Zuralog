/**
 * Terms of Service page — placeholder content for ZuraLog.
 *
 * Governs use of the ZuraLog platform and services.
 * Content should be reviewed and updated by legal counsel before launch.
 */

import { Metadata } from 'next';
import { LegalPageLayout } from '@/components/layout/LegalPageLayout';

export const metadata: Metadata = {
  title: 'Terms of Service | ZuraLog',
  description:
    'Read the Terms of Service governing your use of the ZuraLog platform and applications.',
};

export default function TermsOfServicePage() {
  return (
    <LegalPageLayout title="Terms of Service" lastUpdated="2025-01-01">
      <p>
        These Terms of Service (&quot;Terms&quot;) govern your access to and use of the
        ZuraLog platform, mobile applications, and related services (collectively, the
        &quot;Services&quot;) provided by ZuraLog (&quot;we,&quot; &quot;us,&quot; or
        &quot;our&quot;). By using the Services, you agree to be bound by these Terms.
      </p>

      <h2>1. Eligibility</h2>
      <p>
        You must be at least 13 years old to use the Services. By accessing or using the
        Services, you represent and warrant that you meet this age requirement and that you
        have the legal capacity to agree to these Terms.
      </p>

      <h2>2. Account Registration</h2>
      <p>
        You must create an account to access most features. You are responsible for
        safeguarding your account credentials and for all activity that occurs under your
        account. Notify us immediately at{' '}
        <a href="mailto:support@zuralog.com">support@zuralog.com</a> if you suspect
        unauthorised access.
      </p>

      <h2>3. Acceptable Use</h2>
      <p>You agree not to:</p>
      <ul>
        <li>Use the Services for any unlawful purpose</li>
        <li>Attempt to gain unauthorised access to any part of the Services</li>
        <li>Reverse-engineer, decompile, or disassemble any part of the Services</li>
        <li>Transmit any viruses, malware, or other malicious code</li>
        <li>Impersonate any person or entity</li>
        <li>Scrape or systematically extract data without written permission</li>
      </ul>

      <h2>4. Health Data Disclaimer</h2>
      <p>
        ZuraLog provides health and fitness insights for informational purposes only. The
        Services are <strong>not</strong> a medical device, and nothing in the Services
        constitutes medical advice, diagnosis, or treatment. Always consult a qualified
        healthcare professional before making decisions about your health.
      </p>

      <h2>5. Third-Party Integrations</h2>
      <p>
        The Services may integrate with third-party platforms (e.g., Apple Health, Strava,
        Garmin). Your use of those platforms is governed by their own terms of service.
        ZuraLog is not responsible for third-party services or the accuracy of data they
        provide.
      </p>

      <h2>6. Intellectual Property</h2>
      <p>
        All content, trademarks, and technology in the Services are the property of ZuraLog
        or its licensors. You are granted a limited, non-exclusive, non-transferable licence
        to access and use the Services for personal, non-commercial purposes. You retain
        ownership of data you upload.
      </p>

      <h2>7. Termination</h2>
      <p>
        We reserve the right to suspend or terminate your account at any time, with or
        without notice, for violation of these Terms or for any other reason at our
        discretion. You may delete your account at any time via the app settings or by
        contacting <a href="mailto:support@zuralog.com">support@zuralog.com</a>.
      </p>

      <h2>8. Disclaimers &amp; Limitation of Liability</h2>
      <p>
        The Services are provided &quot;as is&quot; and &quot;as available&quot; without
        warranties of any kind. To the maximum extent permitted by law, ZuraLog shall not be
        liable for any indirect, incidental, special, consequential, or punitive damages
        arising from your use of or inability to use the Services.
      </p>

      <h2>9. Governing Law</h2>
      <p>
        These Terms are governed by the laws of the jurisdiction in which ZuraLog is
        incorporated, without regard to its conflict-of-law provisions.
      </p>

      <h2>10. Changes to These Terms</h2>
      <p>
        We may revise these Terms from time to time. We will provide reasonable notice of
        material changes. Your continued use of the Services after the effective date
        constitutes your acceptance of the revised Terms.
      </p>

      <h2>11. Contact</h2>
      <p>
        Questions about these Terms? Email us at{' '}
        <a href="mailto:support@zuralog.com">support@zuralog.com</a>.
      </p>
    </LegalPageLayout>
  );
}
