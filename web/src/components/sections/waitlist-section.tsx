/**
 * WaitlistSection — full-page quiz + signup section.
 *
 * This is the primary conversion section. It contains:
 * - Section header with social proof
 * - QuizContainer (steps + form)
 * - Leaderboard sidebar (desktop only)
 */
'use client';

import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import { QuizContainer } from '@/components/quiz/quiz-container';
import { WaitlistStatsBar } from '@/components/waitlist-stats-bar';

interface LeaderboardEntry {
  rank: number;
  display_name: string;
  referral_count: number;
  queue_position?: number;
}

/**
 * Full waitlist section with quiz funnel and referral leaderboard.
 */
export function WaitlistSection() {
  const [leaderboard, setLeaderboard] = useState<LeaderboardEntry[]>([]);

  useEffect(() => {
    fetch('/api/waitlist/leaderboard')
      .then((r) => r.json())
      .then((d) => setLeaderboard(d.leaderboard ?? []))
      .catch(() => {});
  }, []);

  return (
    <section
      id="waitlist"
      className="relative min-h-screen bg-black py-24 md:py-32"
    >
      {/* Background gradient glow */}
      <div className="pointer-events-none absolute inset-0 overflow-hidden">
        <div className="absolute left-1/2 top-1/2 h-[600px] w-[600px] -translate-x-1/2 -translate-y-1/2 rounded-full bg-sage/5 blur-[120px]" />
      </div>

      <div className="relative mx-auto max-w-6xl px-6">
        {/* Section header */}
        <motion.div
          initial={{ opacity: 0, y: 24 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          className="mb-16 text-center"
        >
          <h2 className="font-display text-4xl font-bold text-white md:text-5xl">
            Join the waitlist
          </h2>
          <p className="mx-auto mt-4 max-w-xl text-zinc-400">
            Secure your spot first — then answer 3 quick questions so we can
            personalize your experience before we launch.
          </p>
        </motion.div>

        {/* Animated stats counters */}
        <WaitlistStatsBar />

        {/* Main layout */}
        <div className="flex flex-col items-start gap-12 lg:flex-row lg:justify-between">
          {/* Quiz (left / main) */}
          <motion.div
            initial={{ opacity: 0, x: -24 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.6, delay: 0.1 }}
            className="w-full lg:max-w-xl"
          >
            <QuizContainer />
          </motion.div>

          {/* Leaderboard (right / sidebar, desktop only) */}
          {leaderboard.length > 0 && (
            <motion.aside
              initial={{ opacity: 0, x: 24 }}
              whileInView={{ opacity: 1, x: 0 }}
              viewport={{ once: true }}
              transition={{ duration: 0.6, delay: 0.2 }}
              className="hidden w-full max-w-xs shrink-0 lg:block"
            >
              <div className="rounded-3xl border border-white/8 bg-white/3 p-6 backdrop-blur-sm">
                <h3 className="mb-4 text-sm font-semibold uppercase tracking-widest text-zinc-400">
                  Top Referrers
                </h3>
                <ol className="flex flex-col gap-3">
                  {leaderboard.slice(0, 8).map((entry) => (
                    <li
                      key={entry.rank}
                      className="flex items-center justify-between gap-3"
                    >
                      <div className="flex items-center gap-3">
                        <span
                          className={`flex h-7 w-7 items-center justify-center rounded-full text-xs font-bold ${
                            entry.rank === 1
                              ? 'bg-yellow-400/20 text-yellow-400'
                              : entry.rank === 2
                                ? 'bg-zinc-300/15 text-zinc-300'
                                : entry.rank === 3
                                  ? 'bg-orange-400/15 text-orange-400'
                                  : 'bg-white/5 text-zinc-500'
                          }`}
                        >
                          {entry.rank}
                        </span>
                        <span className="text-sm text-zinc-300">
                           {entry.display_name}
                         </span>
                      </div>
                      <span className="text-xs font-medium text-sage">
                        {entry.referral_count} refs
                      </span>
                    </li>
                  ))}
                </ol>
                <p className="mt-4 text-xs text-zinc-600">
                  Refer friends to move up the list.
                </p>
              </div>
            </motion.aside>
          )}
        </div>
      </div>
    </section>
  );
}
