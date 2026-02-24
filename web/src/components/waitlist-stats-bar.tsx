/**
 * WaitlistStatsBar — three animated stat cards shown above the waitlist form.
 *
 * Fetches /api/waitlist/stats and animates three counters:
 *   - Total Signups (people waiting)
 *   - Founding Spots Left (glows amber when ≤ 10)
 *   - Referrals Made
 */
'use client';

import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import { WaitlistCounter } from '@/components/waitlist-counter';

interface Stats {
  totalSignups: number;
  foundingMembersLeft: number;
  totalReferrals: number;
}

export function WaitlistStatsBar() {
  const [stats, setStats] = useState<Stats | null>(null);

  useEffect(() => {
    fetch('/api/waitlist/stats')
      .then((r) => r.json())
      .then((d: Stats) => setStats(d))
      .catch(() => {});
  }, []);

  if (!stats) return null;

  const cards = [
    {
      value: stats.totalSignups,
      label: 'People Waiting',
      icon: '👥',
      delay: 0,
      glow: false,
    },
    {
      value: stats.foundingMembersLeft,
      label: 'Founding Spots Left',
      icon: '⭐',
      delay: 150,
      glow: stats.foundingMembersLeft <= 10,
    },
    {
      value: stats.totalReferrals,
      label: 'Referrals Made',
      icon: '🔗',
      delay: 300,
      glow: false,
    },
  ] as const;

  return (
    <div className="mb-12 grid grid-cols-3 gap-4">
      {cards.map((card, i) => (
        <motion.div
          key={i}
          initial={{ opacity: 0, y: 16 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5, delay: i * 0.1 }}
          className={`relative overflow-hidden rounded-2xl border bg-white/3 p-4 text-center backdrop-blur-sm transition-all ${
            card.glow
              ? 'border-sage/40 shadow-[0_0_30px_rgba(207,225,185,0.12)]'
              : 'border-white/8'
          }`}
        >
          {card.glow && (
            <motion.div
              animate={{ opacity: [0.3, 0.7, 0.3] }}
              transition={{ repeat: Infinity, duration: 2.5, ease: 'easeInOut' }}
              className="pointer-events-none absolute inset-0 rounded-2xl bg-sage/5"
            />
          )}
          <div className="mb-2 text-xl leading-none">{card.icon}</div>
          <WaitlistCounter value={card.value} delay={card.delay} sizeClass="text-2xl" />
          <p className="mt-1 text-xs font-medium uppercase tracking-widest text-zinc-500">
            {card.label}
          </p>
        </motion.div>
      ))}
    </div>
  );
}
