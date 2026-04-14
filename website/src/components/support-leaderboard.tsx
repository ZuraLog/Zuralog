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

/** Row background tint — top 3 get a subtle sage wash */
function rowBg(rank: number): string {
  if (rank === 1) return 'rgba(52,78,65,0.08)';
  if (rank === 2) return 'rgba(52,78,65,0.05)';
  if (rank === 3) return 'rgba(52,78,65,0.03)';
  return 'transparent';
}

/** Rank badge style — top 3 pop in sage, rest are muted */
function RankBadge({ rank }: { rank: number }) {
  const isTop3 = rank <= 3;
  return (
    <span
      className={[
        'inline-flex h-6 w-8 items-center justify-center rounded-md text-[11px] font-semibold tabular-nums',
        isTop3
          ? 'bg-[#344E41] text-[#E8EDE0]'
          : 'bg-[#DEDAD4] text-black/40',
      ].join(' ')}
    >
      #{rank}
    </span>
  );
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

      <div className="overflow-hidden rounded-2xl border border-black/[0.06] bg-[#E8E6E1] shadow-sm">

        {/* Header row */}
        <div className="grid grid-cols-[56px_1fr_100px] border-b border-black/[0.06] bg-[#DEDAD4] px-5 py-3 text-[10px] font-semibold uppercase tracking-[0.15em] text-black/40">
          <span>Rank</span>
          <span>Supporter</span>
          <span className="text-right">Amount</span>
        </div>

        {/* Loading skeleton */}
        {leaderboard === null && (
          <div className="divide-y divide-black/[0.05]">
            {Array.from({ length: 5 }).map((_, i) => (
              <div key={i} className="grid grid-cols-[56px_1fr_100px] items-center px-5 py-4 gap-3">
                <div className="h-6 w-8 animate-pulse rounded-md bg-[#DEDAD4]" />
                <div className="h-4 w-36 animate-pulse rounded bg-[#DEDAD4]" />
                <div className="ml-auto h-4 w-14 animate-pulse rounded bg-[#DEDAD4]" />
              </div>
            ))}
          </div>
        )}

        {/* Empty state */}
        {leaderboard !== null && leaderboard.length === 0 && (
          <div className="flex flex-col items-center gap-3 px-5 py-14 text-center">
            <p className="text-sm text-black/35">
              No public supporters yet. Be the first!
            </p>
            <a
              href="https://buymeacoffee.com/zuralog"
              target="_blank"
              rel="noopener noreferrer"
              className="relative isolate overflow-hidden inline-flex items-center justify-center gap-2 font-jakarta rounded-ds-pill h-[32px] px-[18px] text-[13px] font-medium bg-transparent border-[1.5px] border-[var(--color-ds-secondary-border)] text-ds-text-primary transition-all duration-300 hover:scale-[1.03] active:scale-[0.97]"
            >
              Buy Us a Coffee
            </a>
          </div>
        )}

        {/* Leaderboard rows */}
        {leaderboard !== null && leaderboard.length > 0 && (
          <div className="divide-y divide-black/[0.05]">
            {leaderboard.map((entry) => (
              <div
                key={entry.rank}
                className="grid grid-cols-[56px_1fr_100px] items-center px-5 py-3.5 transition-colors duration-150 hover:bg-[#DEDAD4]"
                style={{ backgroundColor: rowBg(entry.rank) }}
              >
                <RankBadge rank={entry.rank} />
                <span className="text-[13px] font-medium text-[#161618]">
                  {entry.name}
                </span>
                <span className="text-right text-[13px] font-semibold tabular-nums text-[#344E41]">
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
        All contributions count toward the total.
      </p>
    </motion.div>
  );
}
