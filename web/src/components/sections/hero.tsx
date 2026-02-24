/**
 * Hero section — full-screen cinematic opener for the ZuraLog landing page.
 *
 * Layer stack (back → front):
 *   z-0  : CSS radial sage glow (HeroGlow) — atmospheric underlay
 *   z-10 : Three.js Canvas (HeroSceneLoader) — transparent, phone on top of glow
 *   z-15 : HTML/CSS/SVG overlay (HeroOverlay) — integration cards, graphics, lines
 *   z-20 : bottom fade gradient
 *   z-30 : text content
 */
'use client';

import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import dynamic from 'next/dynamic';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { HeroGlow } from '@/components/hero-glow';

const HeroSceneLoader = dynamic(
  () => import('@/components/3d/hero-scene-loader').then((m) => m.HeroSceneLoader),
  { ssr: false },
);

const HeroOverlay = dynamic(
  () => import('@/components/hero/hero-overlay').then((m) => m.HeroOverlay),
  { ssr: false },
);

interface WaitlistStats {
  totalSignups: number;
  foundingMembersLeft: number;
}

function scrollToQuiz() {
  document.getElementById('waitlist')?.scrollIntoView({ behavior: 'smooth' });
}

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
      {/* Layer 1 — CSS atmospheric sage glow underlay */}
      <div className="absolute inset-0 z-0">
        <HeroGlow />
      </div>

      {/* Layer 2 — Three.js transparent canvas (phone) */}
      <div className="absolute inset-0 z-10">
        <HeroSceneLoader />
      </div>

      {/* Layer 3 — HTML/CSS/SVG overlay: integration cards, floating graphics, convergence lines */}
      <div className="absolute inset-0 z-[15]">
        <HeroOverlay />
      </div>

      {/* Layer 4 — bottom fade so the scene blends into the next section */}
      <div className="pointer-events-none absolute inset-x-0 bottom-0 z-20 h-48 bg-gradient-to-t from-black to-transparent" />

      {/* Layer 5 — hero text content */}
      <div className="relative z-30 flex flex-col items-center gap-6 px-6 text-center">
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
          ZuraLog unifies Strava, Apple Health, Garmin, MyFitnessPal and more
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
              document.getElementById('problem')?.scrollIntoView({ behavior: 'smooth' })
            }
            className="rounded-full px-8 py-4 text-base text-zinc-400 hover:text-white"
          >
            See how it works
          </Button>
        </motion.div>

        {/* Live signup count */}
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
        transition={{ delay: 1.4 }}
        className="absolute bottom-8 left-1/2 z-30 -translate-x-1/2"
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
