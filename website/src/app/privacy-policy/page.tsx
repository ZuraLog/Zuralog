/**
 * Privacy Policy page — US/CCPA-focused for ZuraLog.
 *
 * Covers: general fitness & activity data, biometrics (heart rate, HRV, SpO2),
 * mental/emotional wellness data. Consumer wellness app — not a HIPAA covered entity.
 * ZuraLog does not sell or share personal data for advertising.
 *
 * Content should be reviewed by legal counsel before launch.
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
    <LegalPageLayout title="Privacy Policy" lastUpdated="2026-02-25">
      <p>
        At ZuraLog (&quot;we,&quot; &quot;us,&quot; or &quot;our&quot;), your privacy isn&apos;t
        just a policy checkbox — it&apos;s the foundation of everything we build. This Privacy
        Policy explains what information we collect, why we collect it, and how we use it when
        you access our platform, mobile applications, and related services (collectively, the
        &quot;Services&quot;). This policy is intended for users in the United States and
        incorporates your rights under the California Consumer Privacy Act (CCPA).
      </p>
      <p>
        ZuraLog is a consumer wellness application. We are <strong>not</strong> a covered
        entity or business associate under the Health Insurance Portability and Accountability
        Act (HIPAA). Health data you share with us is processed under this Privacy Policy,
        not HIPAA.
      </p>

      <h2>1. Information We Collect</h2>

      <h3>1.1 Information You Provide</h3>
      <p>
        When you create an account or join our waitlist, we collect your name, email address,
        and any preferences you share during onboarding.
      </p>

      <h3>1.2 Health &amp; Fitness Data</h3>
      <p>
        With your explicit permission, ZuraLog may access health and wellness data from
        connected third-party services (e.g., Apple Health, Google Fit, Strava, Garmin,
        Whoop, Fitbit, Oura). This includes:
      </p>
      <ul>
        <li>
          <strong>General fitness &amp; activity:</strong> steps, workouts, calories burned,
          distance, exercise minutes, and similar activity metrics
        </li>
        <li>
          <strong>Biometric data:</strong> heart rate, heart rate variability (HRV), blood
          oxygen (SpO2), resting heart rate, respiratory rate, and body temperature
        </li>
        <li>
          <strong>Mental &amp; emotional wellness:</strong> stress scores, mood logs, and
          recovery readiness indicators
        </li>
        <li>
          <strong>Sleep data:</strong> sleep duration, sleep stages (REM, deep, light),
          sleep efficiency, and sleep latency
        </li>
        <li>
          <strong>Nutrition &amp; hydration:</strong> dietary calories, macronutrients,
          water intake, and meal logs
        </li>
      </ul>
      <p>
        We collect only the data categories you explicitly authorize and use them solely to
        deliver and improve the Services.
      </p>

      <h3>1.3 Usage &amp; Device Data</h3>
      <p>
        We automatically collect certain technical information when you use the Services,
        including IP addresses, device identifiers, browser type, operating system, pages
        viewed, and interaction events. This data is used to diagnose issues and improve
        performance.
      </p>

      <h2>2. How We Use Your Information</h2>
      <p>We use the information we collect to:</p>
      <ul>
        <li>Provide, maintain, and improve the Services</li>
        <li>
          Generate personalized health and fitness insights using AI analysis across your
          connected data sources
        </li>
        <li>Communicate with you about product updates, support, and promotions</li>
        <li>Detect and prevent fraud, abuse, or security incidents</li>
        <li>Comply with applicable legal obligations</li>
      </ul>

      <h2>3. We Do Not Sell Your Data</h2>
      <p>
        ZuraLog does <strong>not</strong> sell, rent, or share your personal information —
        including your health and biometric data — with third parties for advertising,
        marketing, or any commercial purpose. This applies to all users, including California
        residents exercising rights under the CCPA.
      </p>

      <h2>4. Limited Data Sharing</h2>
      <p>We may share information only in the following limited circumstances:</p>
      <ul>
        <li>
          <strong>Service providers:</strong> trusted vendors who help us operate the
          Services (e.g., cloud hosting, analytics, email delivery) under strict
          confidentiality agreements that prohibit them from using your data for their own
          purposes.
        </li>
        <li>
          <strong>Legal obligations:</strong> when required by law, subpoena, court order,
          or to protect the rights, safety, or property of ZuraLog or its users.
        </li>
        <li>
          <strong>Business transfers:</strong> in the event of a merger, acquisition, or
          asset sale, your data may transfer to the successor entity subject to the same
          privacy protections described here.
        </li>
      </ul>

      <h2>5. Sensitive Personal Information</h2>
      <p>
        Biometric data (heart rate, HRV, SpO2, body temperature) and wellness data
        (stress scores, mood) are considered sensitive personal information. We process
        this data solely to deliver your in-app insights and do not use it for
        cross-context behavioral advertising or profiling unrelated to the Services.
        Certain US states (including Illinois, Texas, and Washington) have specific laws
        governing biometric data — we comply with applicable state requirements.
      </p>

      <h2>6. Your California Privacy Rights (CCPA)</h2>
      <p>If you are a California resident, you have the right to:</p>
      <ul>
        <li>
          <strong>Know:</strong> request disclosure of the categories and specific pieces of
          personal information we have collected about you
        </li>
        <li>
          <strong>Delete:</strong> request deletion of your personal information, subject to
          certain exceptions
        </li>
        <li>
          <strong>Correct:</strong> request correction of inaccurate personal information
        </li>
        <li>
          <strong>Opt out of sale/sharing:</strong> we do not sell or share your data, but
          you may still submit a request to confirm this
        </li>
        <li>
          <strong>Non-discrimination:</strong> we will not discriminate against you for
          exercising any of these rights
        </li>
      </ul>
      <p>
        To exercise any of these rights, contact us at{' '}
        <a href="mailto:support@zuralog.com">support@zuralog.com</a>. We will respond
        within 45 days as required by the CCPA.
      </p>

      <h2>7. Data Retention</h2>
      <p>
        We retain your personal data for as long as your account is active or as needed to
        provide the Services. You may request deletion of your account and associated data
        at any time by contacting{' '}
        <a href="mailto:support@zuralog.com">support@zuralog.com</a>. We will process your
        request within 45 days.
      </p>

      <h2>8. Security</h2>
      <p>
        We employ industry-standard security measures including encryption in transit (TLS
        1.2+) and at rest (AES-256), strict access controls, and regular security reviews.
        Given the sensitivity of health data, we apply heightened protections to biometric
        and wellness information. No system is 100% secure — if you believe your account
        has been compromised, contact us immediately at{' '}
        <a href="mailto:support@zuralog.com">support@zuralog.com</a>.
      </p>

      <h2>9. Children&apos;s Privacy</h2>
      <p>
        The Services are not directed to children under 13. We do not knowingly collect
        personal data from children under 13. If we learn we have done so, we will delete
        that data promptly. If you believe a child has provided us personal information,
        please contact us at <a href="mailto:support@zuralog.com">support@zuralog.com</a>.
      </p>

      <h2>10. Changes to This Policy</h2>
      <p>
        We may update this Privacy Policy from time to time. We will notify you of material
        changes by email or via an in-app notice at least 30 days before the changes take
        effect. Continued use of the Services after the effective date constitutes
        acceptance of the updated Policy.
      </p>

      <h2>11. Contact</h2>
      <p>
        Questions, concerns, or privacy requests? Reach us at{' '}
        <a href="mailto:support@zuralog.com">support@zuralog.com</a>. We take every
        inquiry seriously and aim to respond within 5 business days.
      </p>
    </LegalPageLayout>
  );
}
