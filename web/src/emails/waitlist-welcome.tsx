/**
 * Waitlist welcome email sent to new signups.
 *
 * Built with @react-email/components for type-safe, cross-client email markup.
 * Preview-friendly: passes all required props with sensible defaults.
 */
import {
  Body,
  Button,
  Container,
  Head,
  Heading,
  Hr,
  Html,
  Img,
  Link,
  Preview,
  Section,
  Text,
} from '@react-email/components';
import * as React from 'react';

interface WaitlistWelcomeProps {
  /** Recipient's email address (used in personalization) */
  email: string;
  /** Their queue position number */
  position: number;
  /** Their unique referral code */
  referralCode: string;
  /** Full referral URL for sharing */
  referralUrl: string;
  /** Whether they are a founding member (top 30) */
  isFoundingMember?: boolean;
}

const baseUrl = 'https://zuralog.com';

export const WaitlistWelcome = ({
  email = 'friend@example.com',
  position = 42,
  referralCode = 'ZURA1234',
  referralUrl = 'https://zuralog.com?ref=ZURA1234',
  isFoundingMember = false,
}: WaitlistWelcomeProps) => (
  <Html>
    <Head />
    <Preview>
      {isFoundingMember
        ? "🎉 You're a Zuralog Founding Member — your spot is secured!"
        : `You're #${position} on the Zuralog waitlist — refer friends to climb!`}
    </Preview>
    <Body style={main}>
      <Container style={container}>
        {/* Logo */}
        <Section style={{ textAlign: 'center', padding: '40px 0 24px' }}>
          <Text style={logo}>ZURALOG</Text>
        </Section>

        {/* Hero */}
        <Section style={heroSection}>
          {isFoundingMember && (
            <Text style={badge}>⭐ FOUNDING MEMBER</Text>
          )}
          <Heading style={h1}>
            {isFoundingMember
              ? "You're in — Founding Member secured."
              : `You're #${position} on the waitlist.`}
          </Heading>
          <Text style={bodyText}>
            {isFoundingMember
              ? "You're one of the first 30 people on Zuralog. You'll get lifetime early-access pricing, direct input into the product roadmap, and first access when we launch."
              : "Zuralog is the AI fitness hub that finally connects all your apps — Strava, Apple Health, Garmin, MyFitnessPal — into one action layer. You'll be among the first to access it."}
          </Text>
        </Section>

        <Hr style={divider} />

        {/* Referral */}
        <Section style={{ padding: '24px 0' }}>
          <Heading as="h2" style={h2}>
            Move up the list — refer friends
          </Heading>
          <Text style={bodyText}>
            Each friend who joins using your link moves you up by one spot. Your
            unique referral code is:
          </Text>
          <Section style={codeBox}>
            <Text style={codeText}>{referralCode}</Text>
          </Section>
          <Button style={ctaButton} href={referralUrl}>
            Share Your Link
          </Button>
          <Text style={smallText}>
            Or copy: <Link href={referralUrl} style={linkStyle}>{referralUrl}</Link>
          </Text>
        </Section>

        <Hr style={divider} />

        {/* Footer */}
        <Section style={{ padding: '16px 0 40px' }}>
          <Text style={footerText}>
            You signed up with <strong>{email}</strong>. If this wasn't you,
            ignore this email.
          </Text>
          <Text style={footerText}>
            © 2026 Zuralog · <Link href={`${baseUrl}/privacy`} style={linkStyle}>Privacy</Link>
          </Text>
        </Section>
      </Container>
    </Body>
  </Html>
);

export default WaitlistWelcome;

// ─── Styles ──────────────────────────────────────────────────────────────────

const main: React.CSSProperties = {
  backgroundColor: '#0a0a0a',
  fontFamily: 'Inter, -apple-system, BlinkMacSystemFont, sans-serif',
};

const container: React.CSSProperties = {
  maxWidth: '560px',
  margin: '0 auto',
  padding: '0 24px',
};

const logo: React.CSSProperties = {
  fontSize: '22px',
  fontWeight: 700,
  letterSpacing: '0.15em',
  color: '#CFE1B9',
  margin: 0,
};

const heroSection: React.CSSProperties = {
  padding: '32px 0',
};

const badge: React.CSSProperties = {
  display: 'inline-block',
  backgroundColor: 'rgba(207,225,185,0.15)',
  color: '#CFE1B9',
  fontSize: '11px',
  fontWeight: 600,
  letterSpacing: '0.12em',
  padding: '4px 12px',
  borderRadius: '100px',
  marginBottom: '16px',
};

const h1: React.CSSProperties = {
  fontSize: '28px',
  fontWeight: 700,
  color: '#ffffff',
  lineHeight: 1.3,
  margin: '0 0 16px',
};

const h2: React.CSSProperties = {
  fontSize: '20px',
  fontWeight: 600,
  color: '#ffffff',
  margin: '0 0 12px',
};

const bodyText: React.CSSProperties = {
  fontSize: '15px',
  color: '#a1a1aa',
  lineHeight: 1.6,
  margin: '0 0 16px',
};

const codeBox: React.CSSProperties = {
  backgroundColor: '#1c1c1e',
  borderRadius: '12px',
  padding: '16px',
  textAlign: 'center',
  margin: '16px 0',
};

const codeText: React.CSSProperties = {
  fontSize: '24px',
  fontWeight: 700,
  letterSpacing: '0.2em',
  color: '#CFE1B9',
  margin: 0,
};

const ctaButton: React.CSSProperties = {
  backgroundColor: '#CFE1B9',
  color: '#0a0a0a',
  fontWeight: 600,
  fontSize: '15px',
  padding: '12px 28px',
  borderRadius: '100px',
  textDecoration: 'none',
  display: 'inline-block',
  margin: '8px 0 16px',
};

const smallText: React.CSSProperties = {
  fontSize: '13px',
  color: '#71717a',
  margin: '8px 0 0',
};

const divider: React.CSSProperties = {
  borderColor: '#27272a',
  margin: '8px 0',
};

const footerText: React.CSSProperties = {
  fontSize: '12px',
  color: '#52525b',
  lineHeight: 1.6,
  margin: '0 0 8px',
};

const linkStyle: React.CSSProperties = {
  color: '#CFE1B9',
  textDecoration: 'none',
};
