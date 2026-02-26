/**
 * SupportLeaderboard — Top 10 funders displayed as a ranked list.
 *
 * Only shows non-anonymous supporters.
 * Renders a loading skeleton when data is null.
 * Renders an empty state when data is an empty array.
 */
'use client';

import { motion } from 'framer-motion';

// ── Types ──────────────────────────────────────────────────────────────

interface LeaderboardEntry {
  rank: number;
  name: string;
  amount: number;
}

interface SupportLeaderboardProps {
  /** null = loading; empty array = no public supporters */
  leaderboard: LeaderboardEntry[] | null;
}

// ── Helpers ────────────────────────────────────────────────────────────

/** Rank label for top 3 uses positional text; rest use #N */
function rankDisplay(rank: number): string {
  return `#${rank}`;
}

/** Background tint colour for top 3 rows (hex with 13% alpha appended) */
function rankColor(rank: number): string {
  if (rank === 1) return '#D4F29122'; // gold-lime tint
  if (rank === 2) return '#E8F5A822'; // silver-lime tint
  if (rank === 3) return '#F0F8D422'; // bronze-lime tint
  return 'transparent';
}

/** Text accent colour for rank badge on top 3 */
function rankTextColor(rank: number): string {
  if (rank <= 3) return '#2D2D2D';
  return '#2D2D2D80';
}

// ── Component ──────────────────────────────────────────────────────────

export function SupportLeaderboard({ leaderboard }: SupportLeaderboardProps) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true }}
      transition={{ duration: 0.5 }}
    >
      <h2 className="mb-6 text-center text-sm font-semibold uppercase tracking-[0.2em] text-black/30">
        Top Supporters
      </h2>

      <div className="overflow-hidden rounded-2xl border border-black/[0.06] bg-white shadow-sm">
        {/* Header row */}
        <div className="grid grid-cols-[48px_1fr_100px] border-b border-black/[0.06] px-5 py-3 text-[10px] font-semibold uppercase tracking-[0.15em] text-black/30">
          <span>Rank</span>
          <span>Supporter</span>
          <span className="text-right">Amount</span>
        </div>

        {/* Loading skeleton */}
        {leaderboard === null && (
          <div className="divide-y divide-black/[0.04]">
            {Array.from({ length: 5 }).map((_, i) => (
              <div key={i} className="grid grid-cols-[48px_1fr_100px] items-center px-5 py-4">
                <div className="h-4 w-6 animate-pulse rounded bg-black/5" />
                <div className="h-4 w-32 animate-pulse rounded bg-black/5" />
                <div className="ml-auto h-4 w-16 animate-pulse rounded bg-black/5" />
              </div>
            ))}
          </div>
        )}

        {/* Empty state */}
        {leaderboard !== null && leaderboard.length === 0 && (
          <div className="px-5 py-12 text-center">
            <p className="text-sm text-black/30">
              No public supporters yet — be the first!
            </p>
            <a
              href="https://buymeacoffee.com/zuralog"
              target="_blank"
              rel="noopener noreferrer"
              className="mt-3 inline-flex items-center gap-1.5 rounded-full px-4 py-1.5 text-xs font-semibold transition-opacity hover:opacity-90"
              style={{ background: '#E8F5A8', color: '#2D2D2D' }}
            >
              Buy Us a Coffee
            </a>
          </div>
        )}

        {/* Leaderboard rows */}
        {leaderboard !== null && leaderboard.length > 0 && (
          <div className="divide-y divide-black/[0.04]">
            {leaderboard.map((entry) => (
              <div
                key={entry.rank}
                className="grid grid-cols-[48px_1fr_100px] items-center px-5 py-4 transition-colors hover:bg-black/[0.015]"
                style={{ background: rankColor(entry.rank) }}
              >
                <span
                  className="text-sm font-bold"
                  style={{ color: rankTextColor(entry.rank) }}
                >
                  {rankDisplay(entry.rank)}
                </span>
                <span className="text-sm font-medium text-[#2D2D2D]">
                  {entry.name}
                </span>
                <span className="text-right text-sm font-semibold tabular-nums text-[#2D2D2D]">
                  ${entry.amount.toFixed(2)}
                </span>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Attribution note */}
      <p className="mt-4 text-center text-[10px] text-black/25">
        Only supporters who chose to show their name appear here.
        All contributions — Buy Me a Coffee, sponsorships, and other support — count toward the total.
      </p>
    </motion.div>
  );
}
