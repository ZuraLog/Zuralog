/**
 * Hero section — full-screen cinematic opener for the ZuraLog landing page.
 *
 * CryptoHub-inspired redesign: cream background (#FAFAF5), dark text, premium
 * Satoshi typography, staggered Framer Motion entrance sequence.
 *
 * Layer stack (back → front):
 *   z-0   : Cream background fill (bg-[var(--section-cream)])
 *   z-[5] : HeroOverlayBehind — convergence lines ONLY (behind phone)
 *   z-10  : HeroSceneLoader — Three.js transparent canvas (phone)
 *   z-[15]: HeroOverlayFront — floating graphics + integration cards (in front)
 *   z-20  : Bottom fade gradient (cream → transparent, blends into next section)
 *   z-30  : Text content layer (eyebrow badge, headline, CTA, stat line)
 *
 * HeroGlow (sage radial underlay) sits behind everything at z-0 and provides
 * a subtle sage-green atmospheric tint visible through the cream background.
 *
 * Page load animation sequence (Framer Motion):
 *   0ms   : Section background visible immediately
 *   150ms : Eyebrow badge fades in + slides down 10px→0
 *   300ms : Headline line 1 fades in + slides up 20px→0
 *   450ms : Headline line 2 fades in + slides up 20px→0
 *   600ms : Headline line 3 fades in + slides up 20px→0
 *   750ms : CTA button scales in (0.9→1) + fades in
 *   900ms : Stat line fades in
 */
'use client';

import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import dynamic from 'next/dynamic';
import { Sparkles } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
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

/** Smooth-scroll to the waitlist section. */
function scrollToWaitlist() {
  document.getElementById('waitlist')?.scrollIntoView({ behavior: 'smooth' });
}

/**
 * Hook: fetches the live waitlist count from `/api/waitlist/stats`.
 * Returns `null` while loading or on error, so the stat line can be hidden
 * gracefully when the count is unavailable.
 */
function useWaitlistCount(): number | null {
  const [count, setCount] = useState<number | null>(null);

  useEffect(() => {
    let cancelled = false;

    async function fetchCount() {
      try {
        const res = await fetch('/api/waitlist/stats');
        if (!res.ok) return;
        const data = (await res.json()) as { count?: number };
        if (!cancelled && typeof data.count === 'number') {
          setCount(data.count);
        }
      } catch {
        // Silently ignore — stat line is hidden on error
      }
    }

    void fetchCount();
    return () => { cancelled = true; };
  }, []);

  return count;
}

/** Reusable Framer Motion fade-up variant factory. */
const fadeUp = (delayMs: number) => ({
  initial: { opacity: 0, y: 20 },
  animate: { opacity: 1, y: 0 },
  transition: { duration: 0.55, delay: delayMs / 1000, ease: [0.16, 1, 0.3, 1] as const },
});

/** Reusable Framer Motion fade-down variant (eyebrow badge). */
const fadeDown = (delayMs: number) => ({
  initial: { opacity: 0, y: -10 },
  animate: { opacity: 1, y: 0 },
  transition: { duration: 0.45, delay: delayMs / 1000, ease: [0.16, 1, 0.3, 1] as const },
});

/** Reusable Framer Motion scale-in variant (CTA button). */
const scaleIn = (delayMs: number) => ({
  initial: { opacity: 0, scale: 0.9 },
  animate: { opacity: 1, scale: 1 },
  transition: { duration: 0.4, delay: delayMs / 1000, ease: [0.16, 1, 0.3, 1] as const },
});

export function Hero() {
  const waitlistCount = useWaitlistCount();

  return (
    <section
      id="hero"
      className="relative flex min-h-screen flex-col items-center justify-center overflow-hidden bg-[var(--section-cream)]"
    >
      {/* Layer 1 — CSS atmospheric sage glow underlay (z-0) */}
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

      {/* Layer 5 — Bottom fade: cream → transparent, blends into next section */}
      <div className="pointer-events-none absolute inset-x-0 bottom-0 z-20 h-56 bg-gradient-to-t from-[#FAFAF5] to-transparent" />

      {/* Layer 6 — Text content, centered with absolute bottom anchor */}
      <div className="absolute bottom-20 left-0 right-0 z-30 flex flex-col items-center gap-5 px-6 text-center">

        {/* Eyebrow badge — fades in + slides down (150ms delay) */}
        <motion.div {...fadeDown(150)}>
          <Badge variant="eyebrow" className="flex items-center gap-1.5">
            <Sparkles className="size-3" aria-hidden="true" />
            AI-Powered Health Assistant
          </Badge>
        </motion.div>

        {/* Headline — three lines, staggered 300/450/600ms */}
        <div className="flex flex-col items-center">
          {/* Line 1: regular weight */}
          <motion.h1
            {...fadeUp(300)}
            className="text-display-hero font-normal text-[var(--text-primary)]"
          >
            Unified Health.
          </motion.h1>

          {/* Line 2: bold weight */}
          <motion.span
            {...fadeUp(450)}
            className="text-display-hero block font-bold text-[var(--text-primary)]"
          >
            Made Simple.
          </motion.span>

          {/* Line 3: bold weight, sage green */}
          <motion.span
            {...fadeUp(600)}
            className="text-display-hero block font-bold text-sage"
          >
            Made Smart.
          </motion.span>
        </div>

        {/* CTA button — scales in (750ms delay) with idle pulse-glow animation */}
        <motion.div {...scaleIn(750)}>
          <Button
            variant="pill"
            size="pill"
            onClick={scrollToWaitlist}
            className="animate-pulse-glow"
          >
            Claim Your Spot
          </Button>
        </motion.div>

        {/* Live stat line — fades in (900ms), only rendered when count available */}
        {waitlistCount !== null && (
          <motion.p
            {...fadeUp(900)}
            className="text-caption text-[var(--text-muted)]"
          >
            Join {waitlistCount.toLocaleString()} others on the waitlist
          </motion.p>
        )}
      </div>

      {/* Scroll cue — subtle bounce at bottom */}
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 1.4 }}
        className="absolute bottom-6 left-1/2 z-30 -translate-x-1/2"
      >
        <motion.div
          animate={{ y: [0, 8, 0] }}
          transition={{ repeat: Infinity, duration: 2, ease: 'easeInOut' }}
          className="flex h-10 w-6 items-start justify-center rounded-full border border-[var(--text-primary)]/20 pt-2"
        >
          <div className="h-1.5 w-1 rounded-full bg-[var(--text-primary)]/40" />
        </motion.div>
      </motion.div>
    </section>
  );
}
