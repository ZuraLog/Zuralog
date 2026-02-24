/**
 * GET /api/waitlist/status/[code]
 *
 * Returns the waitlist status for a user identified by their referral code.
 * Used to restore the success state when a user revisits the page.
 *
 * @param code - The user's unique referral code (path param).
 */
import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';
import { referralCodeSchema } from '@/lib/validations';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
);

export async function GET(
  _request: NextRequest,
  { params }: { params: Promise<{ code: string }> },
) {
  const { code } = await params;

  const parsed = referralCodeSchema.safeParse({ code: code.toUpperCase() });
  if (!parsed.success) {
    return NextResponse.json({ error: 'Invalid referral code.' }, { status: 400 });
  }

  const { data, error } = await supabase
    .from('waitlist_users')
    .select('email, referral_code, queue_position, referral_count, tier, created_at')
    .eq('referral_code', parsed.data.code)
    .maybeSingle();

  if (error) {
    console.error('[waitlist/status] query error:', error);
    return NextResponse.json({ error: 'Failed to fetch status.' }, { status: 500 });
  }

  if (!data) {
    return NextResponse.json({ error: 'Referral code not found.' }, { status: 404 });
  }

  return NextResponse.json({
    email: data.email,
    position: data.queue_position,
    referralCode: data.referral_code,
    referralCount: data.referral_count,
    tier: data.tier,
    joinedAt: data.created_at,
  });
}
