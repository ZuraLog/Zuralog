/**
 * GET /api/waitlist/leaderboard
 * Returns top referrers by referral count.
 */
import { NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

export const revalidate = 60;

const IS_PREVIEW = process.env.NEXT_PUBLIC_PREVIEW_MODE === 'true';

export async function GET() {
  if (IS_PREVIEW) {
    return NextResponse.json({
      leaderboard: [
        { position: 1, referralCode: 'ALPHA123', referralCount: 12 },
        { position: 2, referralCode: 'BETA4567', referralCount: 8 },
        { position: 3, referralCode: 'GAMMA890', referralCount: 5 },
      ],
    });
  }

  const supabase = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
  );

  const { data, error } = await supabase
    .from('waitlist_users')
    .select('referral_code, referral_count, queue_position')
    .order('referral_count', { ascending: false })
    .limit(10);

  if (error) {
    return NextResponse.json({ error: 'Failed to fetch leaderboard.' }, { status: 500 });
  }

  return NextResponse.json({
    leaderboard: (data ?? []).map((u, i) => ({
      position: i + 1,
      referralCode: u.referral_code,
      referralCount: u.referral_count,
    })),
  });
}
