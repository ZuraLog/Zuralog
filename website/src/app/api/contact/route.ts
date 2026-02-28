/**
 * POST /api/contact
 *
 * Accepts a contact form submission and forwards it to support@zuralog.com
 * via Resend. Also sends a confirmation email to the sender.
 *
 * Flow:
 * 1. Validate body (name, email, subject, message)
 * 2. Send notification email to support@zuralog.com
 * 3. Send confirmation email to the sender
 * 4. Return success
 */

import { NextRequest, NextResponse } from 'next/server';
import * as Sentry from "@sentry/nextjs";
import { getResendClient, FROM_EMAIL } from '@/lib/resend';

/** Expected request body shape */
interface ContactBody {
  name: string;
  email: string;
  subject: string;
  message: string;
}

/**
 * Validates that all required fields are present and non-empty strings.
 *
 * @param body - Parsed request body of unknown shape
 * @returns Typed ContactBody or null if validation fails
 */
function validateBody(body: unknown): ContactBody | null {
  if (typeof body !== 'object' || body === null) return null;
  const { name, email, subject, message } = body as Record<string, unknown>;
  if (
    typeof name !== 'string' || name.trim().length === 0 ||
    typeof email !== 'string' || !email.includes('@') ||
    typeof subject !== 'string' || subject.trim().length === 0 ||
    typeof message !== 'string' || message.trim().length === 0
  ) {
    return null;
  }
  return {
    name: name.trim(),
    email: email.trim().toLowerCase(),
    subject: subject.trim(),
    message: message.trim(),
  };
}

export async function POST(request: NextRequest) {
  return Sentry.withServerActionInstrumentation(
    "contact",
    async () => {
      // 1. Parse and validate
      let body: unknown;
      try {
        body = await request.json();
      } catch {
        return NextResponse.json({ error: 'Invalid request body.' }, { status: 400 });
      }

      const data = validateBody(body);
      if (!data) {
        return NextResponse.json(
          { error: 'Please fill in all fields with valid values.' },
          { status: 400 },
        );
      }

      const resend = getResendClient();

      if (!resend) {
        // In development without Resend configured, return success so the UI works
        console.info('[contact] Resend not configured — skipping email send.');
        return NextResponse.json({ message: 'Message received. We will be in touch soon.' }, { status: 200 });
      }

      try {
        // 2. Notify the ZuraLog team
        await resend.emails.send({
          from: FROM_EMAIL,
          to: 'support@zuralog.com',
          replyTo: data.email,
          subject: `[Contact] ${data.subject}`,
          html: `
            <h2>New contact form submission</h2>
            <p><strong>Name:</strong> ${data.name}</p>
            <p><strong>Email:</strong> ${data.email}</p>
            <p><strong>Subject:</strong> ${data.subject}</p>
            <hr />
            <p>${data.message.replace(/\n/g, '<br />')}</p>
          `,
        });

        // 3. Confirmation to sender (fire-and-forget — don't fail the request if this errors)
        resend.emails
          .send({
            from: FROM_EMAIL,
            to: data.email,
            subject: "We got your message — ZuraLog",
            html: `
              <p>Hi ${data.name},</p>
              <p>Thanks for reaching out. We received your message and will get back to you within 2 business days.</p>
              <p>In the meantime, you can join our waitlist at <a href="https://zuralog.com/#waitlist">zuralog.com</a>.</p>
              <p>The ZuraLog Team</p>
            `,
          })
          .catch((err: unknown) => console.error('[contact] confirmation email error:', err));

      } catch (err) {
        console.error('[contact] send error:', err);
        return NextResponse.json(
          { error: 'Failed to send your message. Please try again or email us directly at support@zuralog.com.' },
          { status: 500 },
        );
      }

      return NextResponse.json(
        { message: 'Message received. We will be in touch soon.' },
        { status: 200 },
      );
    }
  );
}
