/**
 * Hero section — full-screen cinematic opener for the ZuraLog landing page.
 *
 * Layer stack (back → front):
 *   z-0   : CSS radial sage glow (HeroGlow) — atmospheric underlay
 *   z-[5] : HeroOverlayBehind — convergence lines ONLY (behind phone)
 *   z-10  : Three.js Canvas (HeroSceneLoader) — transparent, phone
 *   z-[15]: HeroOverlayFront — floating graphics + integration cards (in front)
 *   z-20  : bottom fade gradient
 *   z-30  : text content
 *
 * The z-[5] / z-10 / z-[15] split ensures convergence lines render BEHIND
 * the 3D phone model while UI graphics and integration cards stay IN FRONT.
 */
'use client';

import { motion } from 'framer-motion';
import dynamic from 'next/dynamic';
import { Button } from '@/components/ui/button';
import { HeroGlow } from '@/components/hero-glow';

const HeroSceneLoader = dynamic(
  () => import('@/components/3d/hero-scene-loader').then((m) => m.HeroSceneLoader),
  { ssr: false },
);

/** Convergence lines layer — rendered BEHIND the phone (z-[5]) */
const HeroOverlayBehind = dynamic(
  () => import('@/components/hero/hero-overlay').then((m) => m.HeroOverlayBehind),
  { ssr: false },
);

/** Graphics + integration cards — rendered IN FRONT of phone (z-[15]) */
const HeroOverlayFront = dynamic(
  () => import('@/components/hero/hero-overlay').then((m) => m.HeroOverlayFront),
  { ssr: false },
);

function scrollToQuiz() {
  document.getElementById('waitlist')?.scrollIntoView({ behavior: 'smooth' });
}

export function Hero() {
  return (
    <section
      id="hero"
      className="relative flex min-h-screen flex-col items-center justify-center overflow-hidden bg-black"
    >
      {/* Layer 1 — CSS atmospheric sage glow underlay */}
      <div className="absolute inset-0 z-0">
        <HeroGlow />
      </div>

      {/* Layer 2 — Convergence lines BEHIND the phone (z-[5] < z-10 phone) */}
      <div className="absolute inset-0 z-[5]">
        <HeroOverlayBehind />
      </div>

      {/* Layer 3 — Three.js transparent canvas (phone) */}
      <div className="absolute inset-0 z-10">
        <HeroSceneLoader />
      </div>

      {/* Layer 4 — Floating graphics + integration cards IN FRONT of phone */}
      <div className="absolute inset-0 z-[15]">
        <HeroOverlayFront />
      </div>

      {/* Layer 4 — bottom fade so the scene blends into the next section */}
      <div className="pointer-events-none absolute inset-x-0 bottom-0 z-20 h-56 bg-gradient-to-t from-black to-transparent" />

      {/* ZuraLog wordmark — top-left */}
      <motion.div
        initial={{ opacity: 0, y: -10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5, ease: 'easeOut' }}
        className="absolute left-6 top-6 z-30 flex items-center gap-2"
      >
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src="/logo.png" alt="ZuraLog" className="h-7 w-7" />
        <span className="text-base font-semibold tracking-tight text-white/90">ZuraLog</span>
      </motion.div>

      {/* Layer 5 — hero text content, anchored to bottom */}
      <div className="absolute bottom-16 left-0 right-0 z-30 flex flex-col items-center gap-5 px-6 text-center">
        {/* Headline — two distinct lines */}
        <motion.h1
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.7, delay: 0.1, ease: 'easeOut' }}
          className="font-display max-w-xl text-4xl font-bold leading-tight tracking-tight text-white md:text-5xl lg:text-6xl"
        >
          <span className="block">Unified Health.</span>
          <span className="block text-sage">Made Smart.</span>
        </motion.h1>

        {/* CTAs */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.7, delay: 0.25, ease: 'easeOut' }}
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
      </div>

      {/* Scroll cue */}
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 1.4 }}
        className="absolute bottom-6 left-1/2 z-30 -translate-x-1/2"
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
