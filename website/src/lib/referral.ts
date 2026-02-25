/**
 * Referral code utilities.
 */
import { customAlphabet } from 'nanoid';

const nanoid = customAlphabet('ABCDEFGHJKMNPQRSTUVWXYZ23456789', 8);

export function generateReferralCode(): string {
  return nanoid();
}

export function getReferralUrl(code: string, baseUrl?: string): string {
  const base =
    baseUrl ??
    process.env.NEXT_PUBLIC_SITE_URL ??
    'https://zuralog.com';
  return `${base}?ref=${code}`;
}

export function buildShareText(
  position: number,
  referralUrl: string,
): { twitter: string; generic: string } {
  const generic = `I'm #${position} on the ZuraLog waitlist — the AI that finally connects all your fitness apps. Skip the line: ${referralUrl}`;
  const twitter = `I just joined @zuralog — the AI fitness hub that connects ALL your apps. I'm #${position} on the waitlist! Skip ahead 👉 ${referralUrl}`;
  return { twitter, generic };
}
