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
import * as Sentry from "@sentry/nextjs";
import { createClient } from '@supabase/supabase-js';
import { checkRateLimit } from "@/lib/rate-limit";
import { getCached, setCached } from "@/lib/cache";

const IS_PREVIEW = process.env.NEXT_PUBLIC_PREVIEW_MODE === 'true';

export async function GET(request: Request) {
  return Sentry.withServerActionInstrumentation(
    "waitlist/stats",
    async () => {
      if (IS_PREVIEW) {
        return NextResponse.json({
          totalSignups: 142,
          foundingMembersLeft: 12,
          totalReferrals: 38,
        });
      }

      // Rate limit
      const ip = request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
      const rl = await checkRateLimit(ip, "general");
      if (!rl.success) {
        return NextResponse.json({ error: "Too many requests" }, { status: 429 });
      }

      // Try Redis cache first
      const cacheKey = "website:waitlist:stats";
      const cachedData = await getCached<{ totalSignups: number; foundingMembersLeft: number; totalReferrals: number }>(cacheKey);
      if (cachedData) {
        return NextResponse.json(cachedData, {
          headers: { "Cache-Control": "public, s-maxage=5, stale-while-revalidate=10" },
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

      const statsData = {
        totalSignups: data?.total_signups ?? 0,
        foundingMembersLeft: Math.max(0, 30 - (data?.founding_members ?? 0)),
        totalReferrals: data?.total_referrals ?? 0,
      };
      await setCached(cacheKey, statsData, 10);

      return NextResponse.json(statsData, {
        headers: { "Cache-Control": "public, s-maxage=5, stale-while-revalidate=10" },
      });
    }
  );
}
