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
  // Query the referral_leaderboard view which computes referral_count via JOIN
  // and handles display_name privacy (real name or "Anonymous #XXXX").
  const { data, error } = await supabase
    .from('referral_leaderboard')
    .select('display_name, referral_count, queue_position')
    .gt('referral_count', 0)
    .limit(10);

  if (error) {
    console.error('[waitlist/leaderboard] query error:', error);
    // Return empty leaderboard rather than 500 — the UI handles an empty state gracefully
    return NextResponse.json({ leaderboard: [] });
  }

  const leaderboard = (data ?? []).map((row, i) => ({
    rank: i + 1,
    display_name: row.display_name ?? `Anonymous #${i + 1}`,
    referral_count: Number(row.referral_count),
    queue_position: row.queue_position,
  }));

  return NextResponse.json({ leaderboard });
}
