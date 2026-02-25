/**
 * GET /api/waitlist/stats
 *
 * Returns aggregate waitlist statistics for the hero counter.
 * Queries the waitlist_stats view.
 *
 * Not cached — always returns fresh data so realtime counter updates
 * are immediately reflected when the client re-fetches after a DB change.
 */
import { NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

export const revalidate = 0;

const IS_PREVIEW = process.env.NEXT_PUBLIC_PREVIEW_MODE === 'true';

export async function GET() {
  if (IS_PREVIEW) {
    return NextResponse.json({
      totalSignups: 142,
      foundingMembersLeft: 12,
      totalReferrals: 38,
    });
  }

  const supabase = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
  );

  const { data, error } = await supabase
    .from('waitlist_stats')
    .select('*')
    .maybeSingle();

  if (error) {
    console.error('[waitlist/stats] query error:', error);
    return NextResponse.json({ error: 'Failed to fetch stats.' }, { status: 500 });
  }

  return NextResponse.json(
    {
      totalSignups: data?.total_signups ?? 0,
      foundingMembersLeft: Math.max(0, 30 - (data?.founding_members ?? 0)),
      totalReferrals: data?.total_referrals ?? 0,
    },
    { headers: { 'Cache-Control': 'no-store' } },
  );
}
