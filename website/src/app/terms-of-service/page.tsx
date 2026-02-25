/**
 * Terms of Service page — US-focused for ZuraLog.
 *
 * Governed by US law (state TBD upon incorporation). Explicitly states
 * ZuraLog does not sell user data. Consumer wellness app, not HIPAA.
 *
 * Content should be reviewed by legal counsel before launch.
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
    <LegalPageLayout title="Terms of Service" lastUpdated="2026-02-25">
      <p>
        These Terms of Service (&quot;Terms&quot;) govern your access to and use of the
        ZuraLog platform, mobile applications, and related services (collectively, the
        &quot;Services&quot;) provided by ZuraLog (&quot;we,&quot; &quot;us,&quot; or
        &quot;our&quot;). By accessing or using the Services, you agree to be bound by
        these Terms and our{' '}
        <a href="/privacy-policy">Privacy Policy</a>. If you do not agree, do not use
        the Services.
      </p>

      <h2>1. Eligibility</h2>
      <p>
        You must be at least 13 years old to use the Services. If you are under 18, you
        must have your parent or legal guardian&apos;s permission. By using the Services,
        you represent that you meet these requirements and have the legal capacity to agree
        to these Terms.
      </p>

      <h2>2. Account Registration</h2>
      <p>
        You must create an account to access most features. You are responsible for
        maintaining the confidentiality of your account credentials and for all activity
        that occurs under your account. Notify us immediately at{' '}
        <a href="mailto:support@zuralog.com">support@zuralog.com</a> if you suspect
        unauthorized access to your account.
      </p>

      <h2>3. Acceptable Use</h2>
      <p>You agree not to:</p>
      <ul>
        <li>Use the Services for any unlawful purpose or in violation of any applicable law</li>
        <li>Attempt to gain unauthorized access to any part of the Services or its infrastructure</li>
        <li>Reverse-engineer, decompile, or disassemble any part of the Services</li>
        <li>Upload or transmit viruses, malware, or any malicious code</li>
        <li>Impersonate any person, entity, or ZuraLog employee</li>
        <li>
          Systematically scrape, harvest, or extract data from the Services without our
          written permission
        </li>
        <li>
          Interfere with or disrupt the integrity or performance of the Services or related
          systems
        </li>
      </ul>

      <h2>4. Health Data &amp; Medical Disclaimer</h2>
      <p>
        ZuraLog provides health and fitness insights for <strong>informational and
        wellness purposes only</strong>. The Services are a consumer wellness tool — we
        are <strong>not</strong> a healthcare provider, medical device, or HIPAA covered
        entity. Nothing in the Services constitutes medical advice, diagnosis, or treatment.
        Always consult a qualified healthcare professional before making decisions about your
        health, fitness, medications, or medical conditions.
      </p>
      <p>
        You authorize ZuraLog to access and process health data from third-party apps you
        connect (such as Apple Health, Strava, or Garmin) solely to provide your in-app
        insights. You can revoke this access at any time through your account settings or
        the relevant third-party platform.
      </p>

      <h2>5. We Do Not Sell Your Data</h2>
      <p>
        ZuraLog does <strong>not</strong> sell, rent, or share your personal information
        — including health, biometric, or wellness data — with third parties for
        advertising, marketing, or any commercial purpose. Your data is used exclusively
        to power your experience within the Services.
      </p>

      <h2>6. Third-Party Integrations</h2>
      <p>
        The Services integrate with third-party platforms (e.g., Apple Health, Google Fit,
        Strava, Garmin, Whoop, Fitbit, Oura). Your use of those platforms is governed
        entirely by their own terms of service and privacy policies. ZuraLog is not
        responsible for third-party services, the accuracy of data they provide, or any
        changes they make to their platforms or APIs.
      </p>

      <h2>7. Intellectual Property</h2>
      <p>
        All content, trademarks, technology, and intellectual property in the Services are
        owned by ZuraLog or its licensors. You are granted a limited, personal,
        non-exclusive, non-transferable, revocable license to access and use the Services
        for your personal, non-commercial purposes. You retain ownership of any data you
        upload or generate through the Services.
      </p>

      <h2>8. Feedback</h2>
      <p>
        If you submit ideas, suggestions, or feedback about the Services, you grant
        ZuraLog a non-exclusive, royalty-free, perpetual, worldwide license to use that
        feedback without compensation or attribution to you.
      </p>

      <h2>9. Termination</h2>
      <p>
        We may suspend or terminate your access to the Services at any time, with or
        without notice, for a violation of these Terms or for any other reason at our
        reasonable discretion. You may delete your account at any time through the app
        settings or by emailing{' '}
        <a href="mailto:support@zuralog.com">support@zuralog.com</a>. Upon termination,
        your right to use the Services ceases immediately.
      </p>

      <h2>10. Disclaimers</h2>
      <p>
        The Services are provided &quot;as is&quot; and &quot;as available&quot; without
        warranties of any kind, express or implied, including warranties of
        merchantability, fitness for a particular purpose, or non-infringement. We do not
        warrant that the Services will be uninterrupted, error-free, or that health data
        insights will be accurate or complete.
      </p>

      <h2>11. Limitation of Liability</h2>
      <p>
        To the maximum extent permitted by applicable law, ZuraLog and its founders,
        officers, employees, and agents shall not be liable for any indirect, incidental,
        special, consequential, or punitive damages — including lost profits, loss of
        data, or personal injury — arising out of or related to your use of or inability
        to use the Services, even if advised of the possibility of such damages.
      </p>

      <h2>12. Indemnification</h2>
      <p>
        You agree to indemnify and hold harmless ZuraLog and its team from any claims,
        damages, losses, or expenses (including reasonable attorneys&apos; fees) arising
        from your use of the Services, your violation of these Terms, or your infringement
        of any third-party rights.
      </p>

      <h2>13. Governing Law &amp; Dispute Resolution</h2>
      <p>
        These Terms are governed by the laws of the United States (and the applicable
        state upon ZuraLog&apos;s incorporation), without regard to conflict-of-law
        principles. Any disputes arising under these Terms shall first be attempted to be
        resolved informally by contacting us at{' '}
        <a href="mailto:support@zuralog.com">support@zuralog.com</a>. If informal
        resolution fails, disputes shall be resolved by binding arbitration in accordance
        with the American Arbitration Association&apos;s Consumer Arbitration Rules.
        You waive any right to a class action lawsuit.
      </p>

      <h2>14. Changes to These Terms</h2>
      <p>
        We may revise these Terms from time to time. We will provide at least 30 days&apos;
        notice of material changes via email or in-app notification. Your continued use of
        the Services after the effective date constitutes your acceptance of the revised
        Terms. If you do not agree to the changes, you must stop using the Services before
        the effective date.
      </p>

      <h2>15. Contact</h2>
      <p>
        Questions about these Terms? We&apos;re happy to help. Email us at{' '}
        <a href="mailto:support@zuralog.com">support@zuralog.com</a> and we&apos;ll get
        back to you within 5 business days.
      </p>
    </LegalPageLayout>
  );
}
