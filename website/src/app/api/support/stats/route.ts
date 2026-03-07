/**
 * GET /api/support/stats
 *
 * Syncs Buy Me a Coffee supporters into Supabase (idempotent upsert, dedup by
 * source + source_id), then returns aggregated stats from the database:
 *   - totalFundsRaised: sum of ALL contributions (BMC + manual/sponsor)
 *   - totalSupporters: count of all contribution rows
 *   - leaderboard: top 10 non-anonymous funders ordered by total contributed
 *
 * BMC API sync runs on every request; stats are cached at the edge for 2 minutes.
 *
 * @route GET /api/support/stats
 * @returns JSON with totalFundsRaised, totalSupporters, leaderboard[]
 */
import { NextResponse } from 'next/server';
import * as Sentry from "@sentry/nextjs";
import { createClient } from '@supabase/supabase-js';
import { fetchAllBmcSupporters } from '@/lib/bmc';
import { captureServerEvent, hashDistinctId } from '@/lib/posthog-server';

const IS_PREVIEW = process.env.NEXT_PUBLIC_PREVIEW_MODE === 'true';

export async function GET(request: Request) {
  return Sentry.withServerActionInstrumentation(
    "support/stats",
    async () => {
      // ── Preview / dev mock ─────────────────────────────────────────────────
      if (IS_PREVIEW) {
        return NextResponse.json({
          totalFundsRaised: 1250.0,
          totalSupporters: 42,
          leaderboard: [
            { rank: 1, name: 'Alex K.', amount: 150.0 },
            { rank: 2, name: 'Sam T.', amount: 100.0 },
            { rank: 3, name: 'Jordan L.', amount: 75.0 },
          ],
        });
      }

      const supabase = createClient(
        process.env.NEXT_PUBLIC_SUPABASE_URL!,
        process.env.SUPABASE_SERVICE_ROLE_KEY!,
      );

      // ── Sync BMC data ──────────────────────────────────────────────────────
      try {
        const supporters = await fetchAllBmcSupporters();

        if (supporters.length > 0) {
          const rows = supporters
            .filter((s) => !s.is_refunded)
            .map((s) => ({
              source: 'buymeacoffee',
              source_id: String(s.support_id),
              supporter_name: s.payer_name ?? s.supporter_name ?? 'Someone',
              is_anonymous: s.support_visibility === 0 || !s.payer_name,
              amount: s.support_coffees * parseFloat(s.support_coffee_price),
              currency: s.support_currency || 'USD',
              message: s.support_note ?? null,
              contributed_at: s.support_created_on,
            }));

          const { error } = await supabase
            .from('support_contributions')
            .upsert(rows, { onConflict: 'source,source_id', ignoreDuplicates: true });

          if (error) {
            console.error('[support/stats] BMC upsert error:', error);
          }
        }
      } catch (err) {
        console.error('[support/stats] BMC sync failed:', err);
        // Non-fatal: continue and serve whatever is cached in Supabase
      }

      // ── Read aggregated stats from Supabase views ─────────────────────────
      const [statsResult, leaderboardResult] = await Promise.all([
        supabase.from('support_stats').select('*').maybeSingle(),
        supabase.from('support_leaderboard').select('*'),
      ]);

      if (statsResult.error) {
        console.error('[support/stats] stats query error:', statsResult.error);
        return NextResponse.json(
          { error: 'Failed to fetch support stats.' },
          { status: 500 },
        );
      }

      const leaderboard = (leaderboardResult.data ?? []).map((row, i) => ({
        rank: i + 1,
        name: row.supporter_name ?? 'Anonymous',
        amount: Number(row.total_contributed ?? 0),
      }));

      const statsResponse = {
        totalFundsRaised: Number(statsResult.data?.total_funds_raised ?? 0),
        totalSupporters: Number(statsResult.data?.total_supporters ?? 0),
        leaderboard,
      };

      // Fire-and-forget: track fresh page view.
      const freshIp = request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
      captureServerEvent(hashDistinctId(`anon_${freshIp}`), "support_stats_viewed", {
        cached: false,
      }).catch(() => {});

      return NextResponse.json(statsResponse, {
        headers: {
          "Cache-Control": "public, s-maxage=120, stale-while-revalidate=300",
        },
      });
    }
  );
}
