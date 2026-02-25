/**
 * Community Guidelines page — ZuraLog.
 *
 * Platform-agnostic guidelines covering LinkedIn, Instagram, X/Twitter,
 * and Facebook. Warm but firm tone matching ZuraLog's brand voice.
 *
 * Content should be reviewed before launch.
 */

import { Metadata } from 'next';
import { LegalPageLayout } from '@/components/layout/LegalPageLayout';

export const metadata: Metadata = {
  title: 'Community Guidelines | ZuraLog',
  description:
    'The community guidelines that govern how people interact with ZuraLog across all social platforms.',
};

export default function CommunityGuidelinesPage() {
  return (
    <LegalPageLayout title="Community Guidelines" lastUpdated="2026-02-25">
      <p>
        We built ZuraLog because we believe health clarity should be available to everyone.
        Our community across LinkedIn, Instagram, X, Facebook, and beyond is a big part of
        that. Whether you are sharing a win, asking a question, or giving us feedback, we
        want this to be a space where everyone feels welcome and respected.
      </p>
      <p>
        These guidelines apply to all interactions on ZuraLog&apos;s official pages,
        profiles, and accounts across every platform. By engaging with our community, you
        agree to follow them.
      </p>

      <h2>1. Be Respectful</h2>
      <p>
        Treat everyone in the community the way you would want to be treated. Healthy
        debate and constructive criticism are welcome. Personal attacks, harassment,
        bullying, or targeted hostility toward any individual or group are not. This
        applies to comments directed at ZuraLog, our team, and other community members
        alike.
      </p>

      <h2>2. Keep It Relevant</h2>
      <p>
        Stay on topic. We love conversations about health, fitness, technology, wellness,
        and productivity. Unrelated spam, excessive self-promotion, or off-topic content
        may be removed to keep the community focused and useful for everyone.
      </p>

      <h2>3. No Misinformation</h2>
      <p>
        Health misinformation can cause real harm. Do not share false or misleading health
        claims, unverified medical advice, or content designed to deceive. ZuraLog is a
        wellness tool, not a medical authority, and we hold our community to the same
        standard: share what you know, be honest about what you do not, and cite sources
        when making health claims.
      </p>

      <h2>4. No Hate Speech or Discrimination</h2>
      <p>
        Content that promotes hatred, discrimination, or violence based on race, ethnicity,
        national origin, gender, gender identity, sexual orientation, religion, age,
        disability, or any other characteristic has no place in our community. We will
        remove it and may block or report the account responsible.
      </p>

      <h2>5. Protect Privacy</h2>
      <p>
        Do not share personal information about other people without their consent. This
        includes names, contact details, health data, photos, or any other identifying
        information. Respect the privacy of others the way you would want your own privacy
        respected.
      </p>

      <h2>6. No Spam or Unsolicited Promotion</h2>
      <p>
        Do not post repetitive messages, unsolicited advertisements, affiliate links, or
        promotional content for third-party products or services in our community spaces.
        If you want to collaborate or partner with ZuraLog, reach out to us directly at{' '}
        <a href="mailto:support@zuralog.com">support@zuralog.com</a>.
      </p>

      <h2>7. No Illegal Content</h2>
      <p>
        Do not post content that violates any applicable law, infringes intellectual
        property rights, or promotes illegal activity. This includes pirated content,
        fraudulent schemes, and content that violates the terms of the platform you are
        posting on.
      </p>

      <h2>8. Moderation</h2>
      <p>
        ZuraLog reserves the right to remove any content that violates these guidelines or
        that we determine, in our sole discretion, is harmful to the community. Repeat
        violations may result in being blocked or reported to the relevant platform.
      </p>
      <p>
        We do our best to moderate fairly and consistently, but we are a small team. If you
        see something that violates these guidelines, please report it through the platform
        you are on or contact us directly at{' '}
        <a href="mailto:support@zuralog.com">support@zuralog.com</a>. We take every report
        seriously.
      </p>

      <h2>9. Our Voice</h2>
      <p>
        ZuraLog team members may participate in community conversations from time to time.
        When we do, we will always be transparent about who we are. We will not use fake
        accounts or astroturfing of any kind to influence community sentiment.
      </p>

      <h2>10. Changes to These Guidelines</h2>
      <p>
        As our community grows, these guidelines may evolve. We will update this page and
        note the date of the last revision at the top. Continued engagement with our
        community after any changes means you accept the updated guidelines.
      </p>

      <h2>Questions?</h2>
      <p>
        If you have questions about these guidelines or want to flag something, email us at{' '}
        <a href="mailto:support@zuralog.com">support@zuralog.com</a>. We read everything.
      </p>
    </LegalPageLayout>
  );
}
