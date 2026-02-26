/**
 * WaitlistStatsBar — three animated stat cards above the waitlist form.
 *
 * Fetches /api/waitlist/stats for the initial paint, then subscribes to
 * Supabase Realtime on the `waitlist_users` table so every INSERT or UPDATE
 * re-fetches fresh stats without a page reload.
 *
 * Peach/apricot palette on cream background.
 */
'use client';

import { useEffect, useRef, useState } from 'react';
import { motion } from 'framer-motion';
import { WaitlistCounter } from '@/components/waitlist-counter';
import { createClient } from '@/lib/supabase/client';

interface Stats {
  totalSignups: number;
  foundingMembersLeft: number;
  totalReferrals: number;
}

/** Fetches the latest stats from the API route. */
async function fetchStats(): Promise<Stats | null> {
  try {
    const r = await fetch('/api/waitlist/stats', { cache: 'no-store' });
    if (!r.ok) return null;
    return (await r.json()) as Stats;
  } catch {
    return null;
  }
}

export function WaitlistStatsBar() {
  const [stats, setStats] = useState<Stats | null>(null);
  // Keep a stable ref to the latest setStats so the realtime callback can use it
  const setStatsRef = useRef(setStats);
  setStatsRef.current = setStats;

  useEffect(() => {
    // 1. Initial load
    fetchStats().then((s) => {
      if (s) setStatsRef.current(s);
    });

    // 2. Supabase Realtime subscription — fires on every INSERT / UPDATE
    const supabase = createClient();

    const channel = supabase
      .channel('waitlist-stats-realtime')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'waitlist_users',
        },
        () => {
          // Re-fetch aggregated stats from the server after each change
          fetchStats().then((s) => {
            if (s) setStatsRef.current(s);
          });
        },
      )
      .subscribe((status, err) => {
        if (status === 'SUBSCRIBED') {
          console.debug('[waitlist] Realtime connected');
        }
        if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') {
          console.warn('[waitlist] Realtime issue:', status, err);
          // Polling fallback handles updates regardless
        }
      });

    // 3. Polling fallback — refresh every 15 s in case realtime misses an event
    const interval = setInterval(() => {
      fetchStats().then((s) => {
        if (s) setStatsRef.current(s);
      });
    }, 15_000);

    return () => {
      clearInterval(interval);
      supabase.removeChannel(channel);
    };
  }, []);

  if (!stats) {
    return (
      <div className="mb-12 grid grid-cols-1 gap-3 sm:grid-cols-3 sm:gap-4">
        {[0, 1, 2].map((i) => (
          <div
            key={i}
            className="h-[120px] animate-pulse rounded-2xl bg-white/50 border border-black/6"
          />
        ))}
      </div>
    );
  }

  const cards = [
    {
      value: stats.totalSignups,
      label: 'People Waiting',
      icon: (
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" className="mx-auto">
          <circle cx="9" cy="7" r="3" stroke="currentColor" strokeWidth="1.5" />
          <circle cx="16" cy="7" r="2.5" stroke="currentColor" strokeWidth="1.5" strokeOpacity="0.5" />
          <path d="M2 19c0-3.3 2.7-6 6-6h2c3.3 0 6 2.7 6 6" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
          <path d="M16 13c2.2 0 4 1.8 4 4v2" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeOpacity="0.5" />
        </svg>
      ),
      color: '#E8F5A8',
      delay: 0,
      urgent: false,
    },
    {
      value: stats.foundingMembersLeft,
      label: 'Founding Spots Left',
      icon: (
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" className="mx-auto">
          <path d="M12 2l2.4 7.4H22l-6.2 4.5 2.4 7.4L12 16.8l-6.2 4.5 2.4-7.4L2 9.4h7.6L12 2z" stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round" />
        </svg>
      ),
      color: '#D4F291',
      delay: 150,
      urgent: stats.foundingMembersLeft <= 10,
    },
    {
      value: stats.totalReferrals,
      label: 'Referrals Made',
      icon: (
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" className="mx-auto">
          <path d="M10 13a5 5 0 0 0 7.5.5l3-3a5 5 0 0 0-7-7l-1.8 1.8" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
          <path d="M14 11a5 5 0 0 0-7.5-.5l-3 3a5 5 0 0 0 7 7l1.8-1.8" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
        </svg>
      ),
      color: '#b8e05a',
      delay: 300,
      urgent: false,
    },
  ] as const;

  return (
    <div className="mb-12 grid grid-cols-1 gap-3 sm:grid-cols-3 sm:gap-4">
      {cards.map((card, i) => (
        <motion.div
          key={card.label}
          initial={{ opacity: 0, y: 20, scale: 0.95 }}
          whileInView={{ opacity: 1, y: 0, scale: 1 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6, delay: i * 0.12, ease: 'easeOut' }}
          className={`group relative overflow-hidden rounded-2xl border border-black/6 bg-white p-5 text-center shadow-sm ${card.urgent ? 'waitlist-urgent' : ''}`}
        >
          {/* Ambient glow behind icon */}
          <div
            className="pointer-events-none absolute left-1/2 top-0 h-24 w-24 -translate-x-1/2 -translate-y-1/2 rounded-full opacity-30 blur-2xl transition-opacity group-hover:opacity-50"
            style={{ backgroundColor: card.color }}
          />

          {/* Icon */}
          <div className="mb-3 transition-colors" style={{ color: card.color }}>
            {card.icon}
          </div>

          {/* Counter */}
          <WaitlistCounter value={card.value} delay={card.delay} sizeClass="text-3xl sm:text-2xl" />

          {/* Label */}
          <p className="mt-2 text-[10px] font-semibold uppercase tracking-[0.2em] text-black/35">
            {card.label}
          </p>

          {/* Bottom accent line */}
          <div
            className="absolute bottom-0 left-1/2 h-[2px] w-12 -translate-x-1/2 opacity-40 rounded-full"
            style={{ background: `linear-gradient(90deg, transparent, ${card.color}, transparent)` }}
          />
        </motion.div>
      ))}
    </div>
  );
}
