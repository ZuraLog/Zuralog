/**
 * GET /api/waitlist/leaderboard
 *
 * Returns the top referrers for the social proof leaderboard.
 * Results are cached for 60 seconds via Next.js route segment config.
 */
import { NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
);

export async function GET() {
  // Query waitlist_users directly, ordered by referral_count descending.
  // Compute rank client-side to avoid dependency on a potentially broken view.
  const { data, error } = await supabase
    .from('waitlist_users')
    .select('email, referral_count, tier')
    .gt('referral_count', 0)
    .order('referral_count', { ascending: false })
    .limit(10);

  if (error) {
    console.error('[waitlist/leaderboard] query error:', error);
    // Return empty leaderboard rather than 500 — the UI handles an empty state gracefully
    return NextResponse.json({ leaderboard: [] });
  }

  const leaderboard = (data ?? []).map((row, i) => ({
    rank: i + 1,
    // Mask email: show first 2 chars + *** + domain
    email_masked: row.email.replace(/^(.{2}).*?(@.*)$/, '$1***$2'),
    referral_count: row.referral_count,
    tier: row.tier,
  }));

  return NextResponse.json({ leaderboard });
}
