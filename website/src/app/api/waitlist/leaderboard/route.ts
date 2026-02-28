/**
 * GET /api/waitlist/leaderboard
 *
 * Returns the top referrers for the social proof leaderboard.
 * Queries the referral_leaderboard view which computes referral_count
 * and handles display_name privacy.
 *
 * Cached for 1 minute.
 */
import { NextResponse } from 'next/server';
import * as Sentry from "@sentry/nextjs";
import { createClient } from '@supabase/supabase-js';
import { checkRateLimit } from "@/lib/rate-limit";
import { getCached, setCached } from "@/lib/cache";

export const revalidate = 60;

const IS_PREVIEW = process.env.NEXT_PUBLIC_PREVIEW_MODE === 'true';

export async function GET(request: Request) {
  return Sentry.withServerActionInstrumentation(
    "waitlist/leaderboard",
    async () => {
      if (IS_PREVIEW) {
        return NextResponse.json({
          leaderboard: [
            { rank: 1, display_name: 'Alex M.', referral_count: 12, queue_position: 3 },
            { rank: 2, display_name: 'Jordan K.', referral_count: 8, queue_position: 7 },
            { rank: 3, display_name: 'Anonymous #4421', referral_count: 5, queue_position: 15 },
          ],
        });
      }

      // Rate limit
      const ip = request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
      const rl = await checkRateLimit(ip, "general");
      if (!rl.success) {
        return NextResponse.json({ error: "Too many requests" }, { status: 429 });
      }

      // Try Redis cache first
      const cacheKey = "website:waitlist:leaderboard";
      const cachedLeaderboard = await getCached<Array<{ rank: number; display_name: string; referral_count: number; queue_position: number }>>(cacheKey);
      if (cachedLeaderboard) {
        return NextResponse.json({ leaderboard: cachedLeaderboard });
      }

      const supabase = createClient(
        process.env.NEXT_PUBLIC_SUPABASE_URL!,
        process.env.SUPABASE_SERVICE_ROLE_KEY!,
      );

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

      await setCached(cacheKey, leaderboard, 60);
      return NextResponse.json({ leaderboard });
    }
  );
}
