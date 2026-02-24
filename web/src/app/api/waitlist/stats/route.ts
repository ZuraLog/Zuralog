/**
 * GET /api/waitlist/stats
 *
 * Returns aggregate waitlist statistics for the hero counter.
 * Cached for 30 seconds.
 */
import { NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

export const revalidate = 30;

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
);

export async function GET() {
  const { data, error } = await supabase
    .from('waitlist_stats')
    .select('*')
    .maybeSingle();

  if (error) {
    console.error('[waitlist/stats] query error:', error);
    return NextResponse.json({ error: 'Failed to fetch stats.' }, { status: 500 });
  }

  return NextResponse.json({
    totalSignups: data?.total_signups ?? 0,
    foundingMembersLeft: Math.max(0, 30 - (data?.founding_members ?? 0)),
    totalReferrals: data?.total_referrals ?? 0,
  });
}
