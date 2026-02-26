/**
 * GET /api/waitlist/stats
 *
 * Returns aggregate waitlist statistics for the hero counter.
 * Queries the waitlist_stats view.
 *
 * Cached at the edge with stale-while-revalidate: served fresh for 5s,
 * then stale for up to 10s while revalidating in the background. With
 * 15s client polling, most requests hit the CDN cache rather than Supabase.
 */
import { NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

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
    { headers: { 'Cache-Control': 'public, s-maxage=5, stale-while-revalidate=10' } },
  );
}
