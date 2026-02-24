/**
 * Referral code utilities.
 *
 * Generates unique, human-readable referral codes for waitlist users.
 * Uses nanoid v5 with a restricted alphabet (uppercase + digits, no ambiguous chars).
 */
import { customAlphabet } from 'nanoid';

/** Custom nanoid with uppercase alphabet, no ambiguous chars (0/O, 1/I/L) */
const nanoid = customAlphabet('ABCDEFGHJKMNPQRSTUVWXYZ23456789', 8);

/**
 * Generates a unique referral code.
 *
 * @returns An 8-character uppercase alphanumeric string.
 */
export function generateReferralCode(): string {
  return nanoid();
}

/**
 * Formats a referral URL for sharing.
 *
 * @param code - The user's referral code.
 * @param baseUrl - The base URL of the site (defaults to env var).
 * @returns The full referral URL.
 */
export function getReferralUrl(code: string, baseUrl?: string): string {
  const base =
    baseUrl ??
    process.env.NEXT_PUBLIC_SITE_URL ??
    'https://zuralog.com';
  return `${base}?ref=${code}`;
}

/**
 * Builds share text for social platforms.
 *
 * @param position - The user's current waitlist position.
 * @param referralUrl - The full referral URL.
 * @returns Object with platform-specific share text.
 */
export function buildShareText(
  position: number,
  referralUrl: string,
): { twitter: string; generic: string } {
  const generic = `I'm #${position} on the ZuraLog waitlist — the AI that finally connects all your fitness apps. Skip the line: ${referralUrl}`;
  const twitter = `I just joined @zuralog — the AI fitness hub that connects ALL your apps. I'm #${position} on the waitlist! Skip ahead 👉 ${referralUrl}`;
  return { twitter, generic };
}
