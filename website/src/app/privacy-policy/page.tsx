/**
 * Privacy Policy page — comprehensive US multi-state privacy law compliance for ZuraLog.
 *
 * Covers: general fitness & activity data, biometrics (heart rate, HRV, SpO2),
 * mental/emotional wellness data, AI processing transparency, third-party integrations,
 * analytics, and subscription data. Consumer wellness app — not a HIPAA covered entity.
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
    <LegalPageLayout title="Privacy Policy" lastUpdated="2026-03-14">
      <p>
        At ZuraLog (&quot;we,&quot; &quot;us,&quot; or &quot;our&quot;), your privacy isn&apos;t
        just a policy checkbox — it&apos;s the foundation of everything we build. This Privacy
        Policy explains what information we collect, why we collect it, and how we use it when
        you access our platform, mobile applications, and related services (collectively, the
        &quot;Services&quot;).
      </p>
      <p>
        This policy applies to users in the United States and incorporates your rights under the
        California Consumer Privacy Act (CCPA/CPRA) and other applicable state privacy laws,
        including those in Virginia (VCDPA), Colorado (CPA), Connecticut (CTDPA), Utah (UCPA),
        Oregon (OCPA), Texas (TDPSA), and Montana (MCDPA). If you are located outside the
        United States, please see Section 13 (&quot;International Users&quot;) for additional
        information.
      </p>
      <p>
        ZuraLog is a consumer wellness application. We are <strong>not</strong> a covered
        entity or business associate under the Health Insurance Portability and Accountability
        Act (HIPAA). Health data you share with us is processed under this Privacy Policy,
        not HIPAA.
      </p>

      <h2>1. Information We Collect</h2>

      <h3>1.1 Account &amp; Profile Information</h3>
      <p>
        When you create an account, join our waitlist, or complete onboarding, we collect:
      </p>
      <ul>
        <li>Name, email address, and display name</li>
        <li>Date of birth (optional, used for age-based personalization)</li>
        <li>Gender (optional, self-identified)</li>
        <li>Fitness level (e.g., beginner, active, athletic)</li>
        <li>AI coach persona preference (e.g., tough love, balanced, gentle)</li>
        <li>Health and wellness goals you select</li>
      </ul>

      <h3>1.2 Health &amp; Fitness Data</h3>
      <p>
        With your explicit permission, ZuraLog may access health and wellness data from
        connected third-party services (e.g., Apple Health, Google Health Connect, Strava,
        Fitbit, Oura, Polar, Withings, Garmin, Whoop). This includes:
      </p>
      <ul>
        <li>
          <strong>General fitness &amp; activity:</strong> steps, workouts, calories burned,
          distance, exercise minutes, activity type, and similar activity metrics
        </li>
        <li>
          <strong>Biometric data:</strong> heart rate, heart rate variability (HRV), blood
          oxygen (SpO2), resting heart rate, respiratory rate, body temperature, and blood
          pressure
        </li>
        <li>
          <strong>Body composition:</strong> weight measurements and related metrics
        </li>
        <li>
          <strong>Mental &amp; emotional wellness:</strong> stress scores, mood logs, and
          recovery readiness indicators
        </li>
        <li>
          <strong>Sleep data:</strong> sleep duration, sleep stages (REM, deep, light),
          sleep quality scores, sleep efficiency, and sleep latency
        </li>
        <li>
          <strong>Nutrition &amp; hydration:</strong> dietary calories, macronutrients
          (protein, carbs, fat), water intake, and meal logs
        </li>
      </ul>
      <p>
        We collect only the data categories you explicitly authorize and use them solely to
        deliver and improve the Services.
      </p>

      <h3>1.3 User-Generated Wellness Data</h3>
      <p>
        You may voluntarily provide additional health data through the Services, including:
      </p>
      <ul>
        <li>
          <strong>Journal entries:</strong> daily subjective wellness ratings (mood, energy,
          stress, sleep quality) and free-text notes
        </li>
        <li>
          <strong>Quick logs:</strong> rapid metric snapshots such as water intake, mood,
          energy, stress, pain levels, and notes
        </li>
        <li>
          <strong>Tags:</strong> user-created categories for wellness tracking (e.g.,
          &quot;headache,&quot; &quot;travel&quot;)
        </li>
        <li>
          <strong>Emergency health card:</strong> blood type, allergies, medications, medical
          conditions, and emergency contact information. This data is stored locally on your
          device by default and is only synced to our servers if you explicitly enable cloud
          backup.
        </li>
      </ul>

      <h3>1.4 AI Coach Interactions</h3>
      <p>
        When you interact with our AI health coach, we collect and store:
      </p>
      <ul>
        <li>Conversation histories (your messages and AI responses)</li>
        <li>
          Attachments you share in chat (e.g., meal photos for nutritional analysis)
        </li>
        <li>
          AI-generated context and memory (personalization data the AI uses to
          provide relevant coaching, such as &quot;prefers morning workouts&quot;)
        </li>
      </ul>
      <p>
        You can view and delete your AI memory items at any time from the Settings screen.
      </p>

      <h3>1.5 Subscription &amp; Payment Data</h3>
      <p>
        If you subscribe to ZuraLog Pro, we collect your subscription tier and expiration
        date. Payment processing is handled entirely by RevenueCat through the Apple App
        Store or Google Play Store — we do <strong>not</strong> collect or store your
        credit card number, billing address, or other payment instrument details.
      </p>

      <h3>1.6 Usage &amp; Device Data</h3>
      <p>
        We automatically collect certain technical information when you use the Services,
        including:
      </p>
      <ul>
        <li>IP addresses and approximate location derived from IP</li>
        <li>Device identifiers, platform (iOS/Android), and operating system version</li>
        <li>App version and build number</li>
        <li>Pages viewed, screen navigation, and interaction events</li>
        <li>App lifecycle events (launch, foreground, background) and session duration</li>
        <li>Push notification delivery and read status</li>
        <li>Error logs and crash reports</li>
      </ul>
      <p>
        You can opt out of analytics data collection at any time from Settings → Privacy
        &amp; Data → Analytics.
      </p>

      <h2>2. How We Use Your Information</h2>
      <p>We use the information we collect to:</p>
      <ul>
        <li>Provide, maintain, and improve the Services</li>
        <li>
          Generate personalized health and fitness insights using AI analysis across your
          connected data sources
        </li>
        <li>
          Power your AI health coach with relevant context from your health data, journal
          entries, and past conversations
        </li>
        <li>
          Send push notifications including health insights, anomaly alerts, streak
          milestones, achievement notifications, daily briefings, and reminders (subject
          to your notification preferences and quiet hours settings)
        </li>
        <li>Track your engagement streaks and unlock achievements</li>
        <li>Communicate with you about product updates, support, and promotions</li>
        <li>Detect and prevent fraud, abuse, or security incidents</li>
        <li>Monitor application performance and diagnose errors</li>
        <li>Comply with applicable legal obligations</li>
      </ul>

      <h2>3. AI &amp; Automated Processing</h2>
      <p>
        ZuraLog uses artificial intelligence to provide personalized health coaching and
        insights. Here is how your data is processed by AI systems:
      </p>
      <ul>
        <li>
          <strong>AI coaching:</strong> When you send a message to the AI coach, your
          message — along with relevant health context (recent metrics, journal entries,
          goals, and preferences) — is sent to a third-party large language model (LLM)
          provider for response generation. The AI may also retrieve data from your
          connected integrations in real time to answer your questions.
        </li>
        <li>
          <strong>Personalization memory:</strong> To provide more relevant coaching over
          time, the AI generates short contextual summaries (e.g., &quot;user is training
          for a marathon&quot;) that are stored as vector embeddings in a secure database.
          These embeddings are isolated per user and cannot be accessed by other users.
        </li>
        <li>
          <strong>Insights generation:</strong> We analyze your health data to surface
          trends, anomalies, and actionable insights. This processing is automated but is
          not used to make decisions that produce legal or similarly significant effects.
        </li>
      </ul>
      <p>
        You can delete your AI memory at any time from Settings. AI-generated insights are
        provided for informational and wellness purposes only and do not constitute medical
        advice.
      </p>

      <h2>4. We Do Not Sell Your Data</h2>
      <p>
        ZuraLog does <strong>not</strong> sell, rent, or share your personal information —
        including your health and biometric data — with third parties for advertising,
        marketing, or any commercial purpose. We do <strong>not</strong> engage in
        cross-context behavioral advertising. This applies to all users, including residents
        of California and all other US states with consumer privacy laws.
      </p>

      <h2>5. Limited Data Sharing</h2>
      <p>We may share information only in the following limited circumstances:</p>
      <ul>
        <li>
          <strong>Service providers:</strong> trusted vendors who help us operate the
          Services under strict confidentiality agreements that prohibit them from using
          your data for their own purposes. These include:
          <ul>
            <li>
              <strong>Cloud infrastructure:</strong> Supabase (database and
              authentication), Railway (application hosting), Redis (caching)
            </li>
            <li>
              <strong>AI processing:</strong> OpenRouter (LLM inference), OpenAI (text
              embeddings), Pinecone (vector search)
            </li>
            <li>
              <strong>Analytics &amp; monitoring:</strong> PostHog (product analytics,
              subject to your opt-out preference), Sentry (error monitoring and crash
              reporting)
            </li>
            <li>
              <strong>Push notifications:</strong> Firebase Cloud Messaging (notification
              delivery)
            </li>
            <li>
              <strong>Payments:</strong> RevenueCat (subscription management via App Store
              and Google Play)
            </li>
          </ul>
        </li>
        <li>
          <strong>Health platform integrations:</strong> when you connect a third-party
          health platform (e.g., Strava, Fitbit, Oura, Polar, Withings), we exchange data
          with that platform using OAuth 2.0 authorization that you explicitly grant. We
          access only the data scopes you authorize, and you can disconnect any integration
          at any time from Settings.
        </li>
        <li>
          <strong>Legal obligations:</strong> when required by law, subpoena, court order,
          or to protect the rights, safety, or property of ZuraLog or its users.
        </li>
        <li>
          <strong>Business transfers:</strong> in the event of a merger, acquisition, or
          asset sale, your data may transfer to the successor entity subject to the same
          privacy protections described here. We will notify you before your data is
          transferred and becomes subject to a different privacy policy.
        </li>
      </ul>

      <h2>6. Sensitive Personal Information</h2>
      <p>
        The following categories of data we collect are considered sensitive personal
        information under applicable state laws:
      </p>
      <ul>
        <li>
          <strong>Biometric data:</strong> heart rate, HRV, SpO2, body temperature, blood
          pressure, and respiratory rate
        </li>
        <li>
          <strong>Health data:</strong> sleep metrics, nutrition data, weight, stress
          scores, mood, recovery indicators, and medical information from your emergency
          health card
        </li>
      </ul>
      <p>
        We process this data <strong>solely</strong> to deliver your in-app health insights
        and AI coaching. We do not use it for cross-context behavioral advertising,
        profiling unrelated to the Services, or any purpose beyond what is described in this
        policy. We collect sensitive data only with your explicit consent and you may
        withdraw that consent at any time by disconnecting integrations or deleting your
        account.
      </p>
      <p>
        We comply with applicable state biometric privacy laws, including the Illinois
        Biometric Information Privacy Act (BIPA), the Texas Capture or Use of Biometric
        Identifier Act, and the Washington Biometric Identifier law. We do not sell
        biometric data, and we retain biometric data only for as long as your account is
        active or as required to fulfill the purpose for which it was collected.
      </p>

      <h2>7. Your Privacy Rights</h2>

      <h3>7.1 Rights for All Users</h3>
      <p>Regardless of where you live, you can:</p>
      <ul>
        <li>
          Access and review the personal data we hold about you through the Settings screen
        </li>
        <li>Delete your AI memory items (individually or all at once)</li>
        <li>Disconnect any third-party health integration at any time</li>
        <li>Opt out of analytics data collection</li>
        <li>Customize your notification preferences and set quiet hours</li>
        <li>Request deletion of your account and all associated data</li>
      </ul>

      <h3>7.2 California Privacy Rights (CCPA/CPRA)</h3>
      <p>If you are a California resident, you additionally have the right to:</p>
      <ul>
        <li>
          <strong>Know:</strong> request disclosure of the categories and specific pieces of
          personal information we have collected, the sources, the purposes, and the
          categories of third parties with whom we share it
        </li>
        <li>
          <strong>Delete:</strong> request deletion of your personal information, subject to
          certain exceptions
        </li>
        <li>
          <strong>Correct:</strong> request correction of inaccurate personal information
        </li>
        <li>
          <strong>Data portability:</strong> receive your personal information in a
          structured, commonly used, machine-readable format
        </li>
        <li>
          <strong>Limit use of sensitive personal information:</strong> direct us to use
          your sensitive personal information only as necessary to provide the Services
          (this is already our default practice)
        </li>
        <li>
          <strong>Opt out of sale/sharing:</strong> we do not sell or share your data for
          cross-context behavioral advertising, but you may submit a request to confirm this
        </li>
        <li>
          <strong>Non-discrimination:</strong> we will not discriminate against you for
          exercising any of these rights
        </li>
      </ul>
      <p>
        California residents under age 16: we do not knowingly sell or share the personal
        information of consumers under 16 years of age.
      </p>

      <h3>7.3 Additional State Privacy Rights</h3>
      <p>
        If you reside in Virginia, Colorado, Connecticut, Utah, Oregon, Texas, Montana, or
        another state with a comprehensive consumer privacy law, you may have similar rights,
        including the rights to access, correct, delete, and obtain a portable copy of your
        personal data, as well as the right to opt out of targeted advertising (which we do
        not engage in), the sale of personal data (which we do not do), and profiling in
        furtherance of decisions producing legal or similarly significant effects (which we
        do not perform).
      </p>

      <h3>7.4 How to Exercise Your Rights</h3>
      <p>
        To exercise any of these rights, contact us at{' '}
        <a href="mailto:support@zuralog.com">support@zuralog.com</a>. We will verify your
        identity before processing your request and will respond within 45 days as required
        by applicable law. If we need additional time, we will notify you of the extension
        and the reason.
      </p>

      <h3>7.5 Appeal Process</h3>
      <p>
        If we decline to take action on your privacy request, you may appeal our decision
        by emailing <a href="mailto:support@zuralog.com">support@zuralog.com</a> with the
        subject line &quot;Privacy Rights Appeal.&quot; We will respond to your appeal
        within 60 days. If you are not satisfied with our response to your appeal, you may
        contact your state&apos;s attorney general.
      </p>

      <h2>8. Global Privacy Control &amp; Do Not Track</h2>
      <p>
        ZuraLog honors the Global Privacy Control (GPC) signal. If your browser or device
        sends a GPC signal, we will treat it as a valid opt-out request under applicable
        state privacy laws. We do not currently respond to &quot;Do Not Track&quot; (DNT)
        browser signals, as there is no uniform industry standard for DNT compliance.
      </p>

      <h2>9. Data Retention</h2>
      <p>
        We retain your personal data for as long as your account is active or as needed to
        provide the Services. Specific retention practices include:
      </p>
      <ul>
        <li>
          <strong>Account and profile data:</strong> retained until you delete your account
        </li>
        <li>
          <strong>Health and fitness data:</strong> retained until you delete your account
          or disconnect the relevant integration
        </li>
        <li>
          <strong>AI conversation history:</strong> retained until you delete individual
          conversations or your account
        </li>
        <li>
          <strong>AI memory and personalization:</strong> retained until you manually clear
          your AI memory or delete your account
        </li>
        <li>
          <strong>Usage analytics:</strong> retained in aggregated, de-identified form;
          individual-level analytics data is retained for up to 24 months
        </li>
        <li>
          <strong>Error and crash logs:</strong> retained for up to 90 days
        </li>
      </ul>
      <p>
        You may request deletion of your account and all associated data at any time by
        contacting <a href="mailto:support@zuralog.com">support@zuralog.com</a> or through
        the Privacy &amp; Data screen in Settings. We will process your request within
        45 days.
      </p>

      <h2>10. De-Identified &amp; Aggregated Data</h2>
      <p>
        We may create de-identified or aggregated data from the information we collect. This
        data cannot reasonably be used to identify you. We may use de-identified and
        aggregated data for research, product improvement, and analytics purposes. We
        commit to maintaining and using such data only in de-identified form and will not
        attempt to re-identify it.
      </p>

      <h2>11. Security</h2>
      <p>
        We employ industry-standard security measures to protect your data, including:
      </p>
      <ul>
        <li>Encryption in transit (TLS 1.2+) and at rest (AES-256)</li>
        <li>Row-level security policies isolating each user&apos;s data in our database</li>
        <li>Per-user namespace isolation for AI memory and vector data</li>
        <li>
          OAuth 2.0 token management with automatic token refresh and secure storage for
          all third-party integrations
        </li>
        <li>
          Sensitive credentials (API tokens, authentication tokens) stored in encrypted
          secure storage on your device
        </li>
        <li>Strict access controls and regular security reviews</li>
      </ul>
      <p>
        Given the sensitivity of health data, we apply heightened protections to biometric
        and wellness information. No system is 100% secure — if you believe your account
        has been compromised, contact us immediately at{' '}
        <a href="mailto:support@zuralog.com">support@zuralog.com</a>.
      </p>

      <h2>12. Cookies &amp; Tracking Technologies</h2>
      <p>
        Our website uses cookies and similar technologies as described in our{' '}
        <a href="/cookie-policy">Cookie Policy</a>. Our mobile application uses the
        following tracking technologies:
      </p>
      <ul>
        <li>
          <strong>PostHog SDK:</strong> product analytics (subject to your opt-out
          preference in Settings → Privacy &amp; Data)
        </li>
        <li>
          <strong>Sentry SDK:</strong> error monitoring and crash reporting
        </li>
        <li>
          <strong>Firebase SDK:</strong> push notification delivery and device token
          management
        </li>
      </ul>
      <p>
        We do not use tracking technologies for targeted advertising or cross-context
        behavioral profiling.
      </p>

      <h2>13. International Users</h2>
      <p>
        The Services are primarily designed for and directed to users in the United States.
        If you access the Services from outside the United States, please be aware that your
        data will be transferred to and processed in the United States, where data protection
        laws may differ from those in your jurisdiction. By using the Services, you consent
        to this transfer. We do not specifically target users in the European Economic Area
        (EEA), the United Kingdom, or other jurisdictions with comprehensive data protection
        frameworks (such as the GDPR), and we do not currently appoint an EU representative
        or conduct data protection impact assessments under the GDPR.
      </p>

      <h2>14. Children&apos;s Privacy</h2>
      <p>
        The Services are not directed to children under 13 (or under 16 in jurisdictions
        where applicable). We do not knowingly collect personal data from children under 13.
        We do not knowingly sell or share the personal information of consumers under 16
        years of age. If we learn we have collected personal data from a child under 13, we
        will delete that data promptly. If you believe a child has provided us personal
        information, please contact us at{' '}
        <a href="mailto:support@zuralog.com">support@zuralog.com</a>.
      </p>

      <h2>15. Changes to This Policy</h2>
      <p>
        We may update this Privacy Policy from time to time. We will notify you of material
        changes by email or via an in-app notice at least 30 days before the changes take
        effect. The &quot;Last updated&quot; date at the top of this page indicates when the
        policy was most recently revised. Continued use of the Services after the effective
        date constitutes acceptance of the updated Policy.
      </p>

      <h2>16. Contact</h2>
      <p>
        Questions, concerns, or privacy requests? Reach us at{' '}
        <a href="mailto:support@zuralog.com">support@zuralog.com</a>. We take every
        inquiry seriously and aim to respond within 5 business days.
      </p>
    </LegalPageLayout>
  );
}
