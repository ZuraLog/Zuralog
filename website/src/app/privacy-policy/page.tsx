/**
 * Privacy Policy page — placeholder content for ZuraLog.
 *
 * Outlines how ZuraLog collects, uses, and protects user data.
 * Content should be reviewed and updated by legal counsel before launch.
 */

import { Metadata } from 'next';
import { LegalPageLayout } from '@/components/layout/LegalPageLayout';

export const metadata: Metadata = {
  title: 'Privacy Policy | ZuraLog',
  description:
    'Learn how ZuraLog collects, uses, and protects your personal health and fitness data.',
};

export default function PrivacyPolicyPage() {
  return (
    <LegalPageLayout title="Privacy Policy" lastUpdated="2025-01-01">
      <p>
        At ZuraLog, your privacy is fundamental to everything we build. This Privacy Policy
        explains what information we collect, why we collect it, and how we use it when you
        use our platform, mobile applications, and related services (collectively, the
        &quot;Services&quot;).
      </p>

      <h2>1. Information We Collect</h2>
      <h3>1.1 Information You Provide</h3>
      <p>
        When you create an account or join our waitlist, we collect your name, email address,
        and any preferences you share during onboarding.
      </p>

      <h3>1.2 Health &amp; Fitness Data</h3>
      <p>
        With your explicit permission, ZuraLog may access health and fitness data from
        connected third-party services (e.g., Apple Health, Google Fit, Strava, Garmin,
        Whoop). This data includes, but is not limited to:
      </p>
      <ul>
        <li>Activity and workout records</li>
        <li>Heart rate and biometric measurements</li>
        <li>Sleep data</li>
        <li>Nutrition and hydration logs</li>
      </ul>
      <p>
        We collect only the data categories you explicitly authorise and use them solely to
        deliver and improve the Services.
      </p>

      <h3>1.3 Usage Data</h3>
      <p>
        We automatically collect certain information when you use the Services, including IP
        addresses, device identifiers, browser type, operating system, pages viewed, and
        interaction events. This data helps us diagnose issues and improve performance.
      </p>

      <h2>2. How We Use Your Information</h2>
      <p>We use the information we collect to:</p>
      <ul>
        <li>Provide, maintain, and improve the Services</li>
        <li>Personalise your health and fitness insights using AI analysis</li>
        <li>Communicate with you about product updates, support, and promotions</li>
        <li>Detect and prevent fraud or misuse</li>
        <li>Comply with legal obligations</li>
      </ul>

      <h2>3. Data Sharing</h2>
      <p>
        ZuraLog does <strong>not</strong> sell your personal data. We may share information
        with:
      </p>
      <ul>
        <li>
          <strong>Service providers</strong> who assist us in operating the Services (e.g.,
          cloud hosting, analytics), under strict confidentiality agreements.
        </li>
        <li>
          <strong>Authorities</strong> when required by law, court order, or to protect the
          rights and safety of ZuraLog and its users.
        </li>
        <li>
          <strong>Business successors</strong> in the event of a merger, acquisition, or
          asset sale, subject to appropriate privacy protections.
        </li>
      </ul>

      <h2>4. Data Retention</h2>
      <p>
        We retain your personal data for as long as your account is active or as needed to
        provide the Services. You may request deletion of your account and associated data at
        any time by contacting{' '}
        <a href="mailto:support@zuralog.com">support@zuralog.com</a>.
      </p>

      <h2>5. Security</h2>
      <p>
        We employ industry-standard security measures including encryption in transit (TLS)
        and at rest, access controls, and regular security audits. No method of transmission
        over the internet is 100% secure; we cannot guarantee absolute security.
      </p>

      <h2>6. Your Rights</h2>
      <p>
        Depending on your jurisdiction, you may have rights to access, correct, delete, or
        restrict processing of your personal data, as well as the right to data portability.
        To exercise any of these rights, contact us at{' '}
        <a href="mailto:support@zuralog.com">support@zuralog.com</a>.
      </p>

      <h2>7. Children&apos;s Privacy</h2>
      <p>
        The Services are not directed to children under 13. We do not knowingly collect
        personal data from children under 13. If we learn we have done so, we will delete
        that data promptly.
      </p>

      <h2>8. Changes to This Policy</h2>
      <p>
        We may update this Privacy Policy from time to time. We will notify you of material
        changes by email or via an in-app notice. Continued use of the Services after the
        effective date constitutes acceptance of the updated Policy.
      </p>

      <h2>9. Contact</h2>
      <p>
        If you have any questions about this Privacy Policy, please contact us at{' '}
        <a href="mailto:support@zuralog.com">support@zuralog.com</a>.
      </p>
    </LegalPageLayout>
  );
}
