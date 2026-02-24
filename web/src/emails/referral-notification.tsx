/**
 * Referral notification email — sent to a user when someone joins via their link.
 */
import {
  Body,
  Container,
  Head,
  Heading,
  Hr,
  Html,
  Link,
  Preview,
  Section,
  Text,
} from '@react-email/components';
import * as React from 'react';

interface ReferralNotificationProps {
  /** Original referrer's email */
  referrerEmail: string;
  /** New queue position after referral */
  newPosition: number;
  /** Total referrals so far */
  referralCount: number;
  /** Their referral URL */
  referralUrl: string;
}

const baseUrl = 'https://zuralog.com';

export const ReferralNotification = ({
  referrerEmail = 'you@example.com',
  newPosition = 15,
  referralCount = 3,
  referralUrl = 'https://zuralog.com?ref=ZURA1234',
}: ReferralNotificationProps) => (
  <Html>
    <Head />
    <Preview>
      {`Someone used your link — you moved up to #${newPosition} on the Zuralog waitlist!`}
    </Preview>
    <Body style={main}>
      <Container style={container}>
        <Section style={{ textAlign: 'center', padding: '40px 0 24px' }}>
          <Text style={logo}>ZURALOG</Text>
        </Section>

        <Section style={{ padding: '8px 0 32px' }}>
          <Text style={emoji}>🎉</Text>
          <Heading style={h1}>Someone joined via your link!</Heading>
          <Text style={bodyText}>
            Your referral is working. You've now referred{' '}
            <strong style={{ color: '#CFE1B9' }}>
              {referralCount} {referralCount === 1 ? 'person' : 'people'}
            </strong>{' '}
            and you've moved up to{' '}
            <strong style={{ color: '#CFE1B9' }}>#{newPosition}</strong> on the
            waitlist.
          </Text>
          <Text style={bodyText}>Keep sharing to climb higher!</Text>
        </Section>

        <Hr style={divider} />

        <Section style={{ padding: '24px 0 40px' }}>
          <Text style={bodyText}>Your referral link:</Text>
          <Link href={referralUrl} style={linkStyle}>
            {referralUrl}
          </Link>
          <Text style={{ ...footerText, marginTop: '32px' }}>
            Sent to <strong>{referrerEmail}</strong>
          </Text>
          <Text style={footerText}>
            © 2026 Zuralog ·{' '}
            <Link href={`${baseUrl}/privacy`} style={dimLink}>
              Privacy
            </Link>
          </Text>
        </Section>
      </Container>
    </Body>
  </Html>
);

export default ReferralNotification;

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
  textAlign: 'center',
};

const emoji: React.CSSProperties = {
  fontSize: '40px',
  margin: '0 0 8px',
};

const h1: React.CSSProperties = {
  fontSize: '26px',
  fontWeight: 700,
  color: '#ffffff',
  lineHeight: 1.3,
  margin: '0 0 16px',
};

const bodyText: React.CSSProperties = {
  fontSize: '15px',
  color: '#a1a1aa',
  lineHeight: 1.6,
  margin: '0 0 12px',
};

const linkStyle: React.CSSProperties = {
  color: '#CFE1B9',
  fontSize: '14px',
  wordBreak: 'break-all',
};

const divider: React.CSSProperties = { borderColor: '#27272a', margin: '8px 0' };

const footerText: React.CSSProperties = {
  fontSize: '12px',
  color: '#52525b',
  margin: '8px 0 0',
};

const dimLink: React.CSSProperties = { color: '#52525b' };
