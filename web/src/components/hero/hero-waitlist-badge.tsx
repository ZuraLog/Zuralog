/**
 * HeroWaitlistBadge — live counter pill shown in the hero section.
 *
 * Fetches total signup count from /api/waitlist/stats and displays
 * as a subtle animated pill: "● 247 people waiting"
 */
'use client';

import { useEffect, useRef, useState } from 'react';
import { motion, useSpring, useTransform, useInView } from 'framer-motion';

export function HeroWaitlistBadge() {
  const [count, setCount] = useState(0);
  const [loaded, setLoaded] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  const isInView = useInView(ref, { once: true });
  const spring = useSpring(0, { stiffness: 55, damping: 22 });
  const display = useTransform(spring, (v) => Math.round(v).toLocaleString());

  useEffect(() => {
    fetch('/api/waitlist/stats')
      .then((r) => r.json())
      .then((d: { totalSignups?: number }) => {
        setCount(d.totalSignups ?? 0);
        setLoaded(true);
      })
      .catch(() => setLoaded(true));
  }, []);

  useEffect(() => {
    if (isInView && count > 0) spring.set(count);
  }, [isInView, count, spring]);

  if (!loaded) return null;

  return (
    <motion.div
      ref={ref}
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: 0.5, duration: 0.5 }}
      className="flex items-center gap-2.5 rounded-full border border-white/10 bg-white/5 px-4 py-2 backdrop-blur-sm"
    >
      {/* Pulsing dot */}
      <motion.span
        animate={{ scale: [1, 1.4, 1], opacity: [0.7, 1, 0.7] }}
        transition={{ repeat: Infinity, duration: 2.5, ease: 'easeInOut' }}
        className="block h-2 w-2 rounded-full bg-sage"
      />
      <span className="text-sm text-zinc-300">
        <motion.span className="font-semibold text-white tabular-nums">{display}</motion.span>
        {' '}people waiting
      </span>
    </motion.div>
  );
}
