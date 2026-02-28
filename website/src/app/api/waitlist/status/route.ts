/**
 * GET /api/waitlist/status?email=...
 *
 * Returns the waitlist position and referral code for a given email.
 * Used to restore the success state when a user revisits the page.
 *
 * @param email - The user's email address (query param).
 */
import { NextRequest, NextResponse } from 'next/server';
import * as Sentry from "@sentry/nextjs";
import { createClient } from '@supabase/supabase-js';

const IS_PREVIEW = process.env.NEXT_PUBLIC_PREVIEW_MODE === 'true';

export async function GET(request: NextRequest) {
  return Sentry.withServerActionInstrumentation(
    "waitlist/status",
    async () => {
      const email = request.nextUrl.searchParams.get('email');
      if (!email) {
        return NextResponse.json({ error: 'email query param required.' }, { status: 400 });
      }

      if (IS_PREVIEW) {
        return NextResponse.json({ position: 42, referralCode: 'PREVIEW123', tier: 'standard' });
      }

      const supabase = createClient(
        process.env.NEXT_PUBLIC_SUPABASE_URL!,
        process.env.SUPABASE_SERVICE_ROLE_KEY!,
      );

      const { data, error } = await supabase
        .from('waitlist_users')
        .select('queue_position, referral_code, tier')
        .eq('email', email.toLowerCase().trim())
        .maybeSingle();

      if (error) {
        console.error('[waitlist/status] query error:', error);
        return NextResponse.json({ error: 'Failed to fetch status.' }, { status: 500 });
      }

      if (!data) {
        return NextResponse.json({ error: 'Email not found on waitlist.' }, { status: 404 });
      }

      return NextResponse.json({
        position: data.queue_position,
        referralCode: data.referral_code,
        tier: data.tier,
      });
    }
  );
}
