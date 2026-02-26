/**
 * WaitlistLeaderboard — displays top referrers on the waitlist.
 *
 * Fetches from /api/waitlist/leaderboard and renders a ranked list
 * with trophy icons for the top 3.
 */
'use client';

import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';

interface LeaderboardEntry {
  rank: number;
  display_name: string;
  referral_count: number;
  queue_position: number;
}

const RANK_COLORS: Record<number, string> = {
  1: '#D4F291',
  2: '#E8F5A8',
  3: '#b8e05a',
};

const RANK_EMOJI: Record<number, string> = {
  1: '1st',
  2: '2nd',
  3: '3rd',
};

export function WaitlistLeaderboard() {
  const [entries, setEntries] = useState<LeaderboardEntry[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch('/api/waitlist/leaderboard')
      .then((r) => r.json())
      .then((data) => {
        setEntries(data.leaderboard ?? []);
        setLoading(false);
      })
      .catch(() => setLoading(false));
  }, []);

  if (loading) {
    return (
      <div className="mt-10 flex justify-center">
        <div className="h-6 w-6 animate-spin rounded-full border-2 border-primary-lime/30 border-t-primary-lime" />
      </div>
    );
  }

  if (entries.length === 0) return null;

  return (
    <motion.div
      initial={{ opacity: 0, y: 24 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true }}
      transition={{ duration: 0.6, delay: 0.2 }}
      className="w-full"
    >
      {/* Header */}
      <div className="mb-4 flex items-center justify-center gap-2">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" className="text-primary-lime">
          <path
            d="M12 2l2.4 7.4H22l-6.2 4.5 2.4 7.4L12 16.8l-6.2 4.5 2.4-7.4L2 9.4h7.6L12 2z"
            stroke="currentColor"
            strokeWidth="1.5"
            strokeLinejoin="round"
            fill="currentColor"
            fillOpacity="0.15"
          />
        </svg>
        <h3 className="text-sm font-semibold uppercase tracking-[0.15em] text-dark-charcoal/60">
          Top Referrers
        </h3>
      </div>

      {/* Leaderboard card */}
      <div className="overflow-hidden rounded-2xl border border-black/6 bg-white shadow-sm">
        {entries.map((entry, i) => {
          const isTop3 = entry.rank <= 3;
          const accentColor = RANK_COLORS[entry.rank] ?? '#E8F5A8';

          return (
            <motion.div
              key={entry.rank}
              initial={{ opacity: 0, x: -12 }}
              whileInView={{ opacity: 1, x: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.4, delay: 0.1 + i * 0.08 }}
              className={`flex items-center gap-3 px-5 py-3.5 ${
                i !== entries.length - 1 ? 'border-b border-black/5' : ''
              } ${isTop3 ? 'bg-primary-lime/5' : ''}`}
            >
              {/* Rank badge */}
              <div
                className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full text-[11px] font-bold"
                style={{
                  backgroundColor: isTop3 ? accentColor : '#f5f5f0',
                  color: isTop3 ? '#1A1A1A' : '#999',
                }}
              >
                {entry.rank}
              </div>

              {/* Name & position */}
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-medium text-dark-charcoal">
                  {entry.display_name}
                </p>
                <p className="text-[10px] text-black/35">
                  #{entry.queue_position} in line
                </p>
              </div>

              {/* Referral count */}
              <div className="text-right">
                <p className="text-sm font-semibold" style={{ color: isTop3 ? '#6B8F23' : '#999' }}>
                  {entry.referral_count}
                </p>
                <p className="text-[9px] uppercase tracking-wider text-black/30">
                  {entry.referral_count === 1 ? 'referral' : 'referrals'}
                </p>
              </div>

              {/* Top 3 label */}
              {isTop3 && (
                <span
                  className="shrink-0 rounded-full px-2 py-0.5 text-[9px] font-semibold"
                  style={{ backgroundColor: accentColor, color: '#1A1A1A' }}
                >
                  {RANK_EMOJI[entry.rank]}
                </span>
              )}
            </motion.div>
          );
        })}
      </div>

      {/* CTA text */}
      <p className="mt-3 text-center text-[11px] text-black/35">
        Share your referral link to climb the leaderboard
      </p>
    </motion.div>
  );
}
