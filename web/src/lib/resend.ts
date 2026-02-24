/**
 * Resend email client singleton.
 *
 * Lazily instantiates the Resend client so the app still boots
 * in development without a Resend API key (emails just won't send).
 */
import { Resend } from 'resend';

let _resend: Resend | null = null;

/**
 * Returns the Resend client, creating it if necessary.
 * Returns null in environments where RESEND_API_KEY is not set.
 */
export function getResendClient(): Resend | null {
  const apiKey = process.env.RESEND_API_KEY;
  if (!apiKey) {
    if (process.env.NODE_ENV !== 'production') {
      console.warn('[resend] RESEND_API_KEY not set — emails will not be sent.');
    }
    return null;
  }
  if (!_resend) {
    _resend = new Resend(apiKey);
  }
  return _resend;
}

/** Default from address for transactional emails */
export const FROM_EMAIL = 'ZuraLog <hello@zuralog.com>';
