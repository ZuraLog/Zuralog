/**
 * Cookie Policy page — placeholder content for ZuraLog.
 *
 * Explains what cookies and similar technologies ZuraLog uses and why.
 * Content should be reviewed and updated by legal counsel before launch.
 */

import { Metadata } from 'next';
import { LegalPageLayout } from '@/components/layout/LegalPageLayout';

export const metadata: Metadata = {
  title: 'Cookie Policy | ZuraLog',
  description:
    'Understand how ZuraLog uses cookies and similar tracking technologies on its platform.',
};

export default function CookiePolicyPage() {
  return (
    <LegalPageLayout title="Cookie Policy" lastUpdated="2026-02-25">
      <p>
        This Cookie Policy explains how ZuraLog (&quot;we,&quot; &quot;us,&quot; or
        &quot;our&quot;) uses cookies and similar technologies when you visit our website or
        use our services. By continuing to use our site, you consent to our use of cookies as
        described in this policy.
      </p>

      <h2>1. What Are Cookies?</h2>
      <p>
        Cookies are small text files placed on your device by a website when you visit it.
        They are widely used to make websites work more efficiently, to remember your
        preferences, and to provide information to site owners.
      </p>

      <h2>2. Types of Cookies We Use</h2>

      <h3>2.1 Strictly Necessary Cookies</h3>
      <p>
        These cookies are essential for the website to function. They enable core features
        such as secure login sessions and authentication. You cannot opt out of these cookies.
      </p>

      <h3>2.2 Performance &amp; Analytics Cookies</h3>
      <p>
        We use analytics cookies (e.g., via tools like Vercel Analytics or Plausible) to
        understand how visitors interact with our site — which pages are most popular, where
        traffic comes from, and how users navigate. All data collected is aggregated and
        anonymised.
      </p>

      <h3>2.3 Functional Cookies</h3>
      <p>
        Functional cookies allow us to remember your preferences (such as language or
        region) to provide a more personalised experience.
      </p>

      <h3>2.4 Marketing &amp; Targeting Cookies</h3>
      <p>
        We may use marketing cookies to measure the effectiveness of our promotional
        campaigns and to show you relevant content. These are only set with your explicit
        consent where required by law.
      </p>

      <h2>3. Third-Party Cookies</h2>
      <p>
        Some third-party services embedded in our site (e.g., analytics providers, social
        media buttons) may set their own cookies. We do not control these cookies and
        recommend reviewing the respective third parties&apos; privacy and cookie policies.
      </p>

      <h2>4. Managing Cookies</h2>
      <p>
        You can control and delete cookies through your browser settings. Most browsers
        allow you to:
      </p>
      <ul>
        <li>Block all cookies</li>
        <li>Block third-party cookies only</li>
        <li>Delete existing cookies</li>
        <li>Be notified when a cookie is set</li>
      </ul>
      <p>
        Note that disabling certain cookies may affect the functionality of our site. Refer
        to your browser&apos;s help documentation for specific instructions.
      </p>

      <h2>5. Cookie Retention</h2>
      <p>
        Session cookies are deleted when you close your browser. Persistent cookies remain
        on your device for a defined period (typically up to 12 months) or until you delete
        them manually.
      </p>

      <h2>6. Updates to This Policy</h2>
      <p>
        We may update this Cookie Policy periodically. Material changes will be communicated
        via a notice on our website or by email. Continued use of the Services after the
        effective date constitutes acceptance.
      </p>

      <h2>7. Contact</h2>
      <p>
        For any questions about our use of cookies, contact us at{' '}
        <a href="mailto:support@zuralog.com">support@zuralog.com</a>.
      </p>
    </LegalPageLayout>
  );
}
