/**
 * Resend email client singleton.
 */
import { Resend } from 'resend';

let _resend: Resend | null = null;

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

export const FROM_EMAIL = 'ZuraLog <support@zuralog.com>';
