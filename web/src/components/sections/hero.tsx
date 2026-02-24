/**
 * Hero section — full-screen cinematic opener for the Zuralog landing page.
 *
 * Layout:
 * - Full-viewport black background
 * - 3D scene (HeroSceneLoader) fills the screen
 * - Text overlay: eyebrow badge, headline, sub-copy, CTA
 * - Animated scroll-cue indicator at bottom
 * - Waitlist stats counter (live data)
 */
'use client';

import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import dynamic from 'next/dynamic';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';

const HeroSceneLoader = dynamic(
  () =>
    import('@/components/3d/hero-scene-loader').then((m) => m.HeroSceneLoader),
  { ssr: false },
);

interface WaitlistStats {
  totalSignups: number;
  foundingMembersLeft: number;
}

function scrollToQuiz() {
  document.getElementById('waitlist')?.scrollIntoView({ behavior: 'smooth' });
}

/**
 * Hero section with full-screen 3D background and text overlay.
 */
export function Hero() {
  const [stats, setStats] = useState<WaitlistStats | null>(null);

  useEffect(() => {
    fetch('/api/waitlist/stats')
      .then((r) => r.json())
      .then(setStats)
      .catch(() => {});
  }, []);

  return (
    <section
      id="hero"
      className="relative flex min-h-screen flex-col items-center justify-center overflow-hidden bg-black"
    >
      {/* 3D background — SSR disabled */}
      <div className="absolute inset-0 -z-10">
        <HeroSceneLoader />
      </div>

      {/* Gradient overlay — ensures text legibility over 3D */}
      <div className="pointer-events-none absolute inset-0 bg-gradient-to-b from-black/30 via-transparent to-black/80" />

      {/* Content */}
      <div className="relative z-10 flex flex-col items-center gap-6 px-6 text-center">
        {/* Eyebrow badge */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, ease: 'easeOut' }}
        >
          <Badge
            variant="outline"
            className="rounded-full border-sage/30 bg-sage/10 px-4 py-1.5 text-xs font-semibold uppercase tracking-widest text-sage"
          >
            {stats && stats.foundingMembersLeft > 0
              ? `${stats.foundingMembersLeft} Founding Member spots left`
              : 'Early Access — Join the Waitlist'}
          </Badge>
        </motion.div>

        {/* Headline */}
        <motion.h1
          initial={{ opacity: 0, y: 24 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.7, delay: 0.1, ease: 'easeOut' }}
          className="font-display max-w-4xl text-5xl font-bold leading-[1.08] tracking-tight text-white md:text-7xl lg:text-8xl"
        >
          All your fitness apps.{' '}
          <span className="text-sage">One AI brain.</span>
        </motion.h1>

        {/* Sub-copy */}
        <motion.p
          initial={{ opacity: 0, y: 24 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.7, delay: 0.2, ease: 'easeOut' }}
          className="max-w-xl text-lg text-zinc-400 md:text-xl"
        >
          Zuralog unifies Strava, Apple Health, Garmin, MyFitnessPal and more
          into a single action layer — then tells you exactly what to do next.
        </motion.p>

        {/* CTAs */}
        <motion.div
          initial={{ opacity: 0, y: 24 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.7, delay: 0.3, ease: 'easeOut' }}
          className="flex flex-col items-center gap-3 sm:flex-row"
        >
          <Button
            size="lg"
            onClick={scrollToQuiz}
            className="rounded-full bg-sage px-8 py-4 text-base font-semibold text-black shadow-[0_0_40px_rgba(207,225,185,0.3)] hover:bg-sage/90 hover:shadow-[0_0_60px_rgba(207,225,185,0.5)]"
          >
            Claim your spot
          </Button>
          <Button
            variant="ghost"
            size="lg"
            onClick={() =>
              document
                .getElementById('problem')
                ?.scrollIntoView({ behavior: 'smooth' })
            }
            className="rounded-full px-8 py-4 text-base text-zinc-400 hover:text-white"
          >
            See how it works
          </Button>
        </motion.div>

        {/* Stats */}
        {stats && stats.totalSignups > 0 && (
          <motion.p
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.6 }}
            className="text-sm text-zinc-500"
          >
            {stats.totalSignups.toLocaleString()} people already on the list
          </motion.p>
        )}
      </div>

      {/* Scroll cue */}
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 1.2 }}
        className="absolute bottom-8 left-1/2 -translate-x-1/2"
      >
        <motion.div
          animate={{ y: [0, 8, 0] }}
          transition={{ repeat: Infinity, duration: 2, ease: 'easeInOut' }}
          className="flex h-10 w-6 items-start justify-center rounded-full border border-white/20 pt-2"
        >
          <div className="h-1.5 w-1 rounded-full bg-white/40" />
        </motion.div>
      </motion.div>
    </section>
  );
}
