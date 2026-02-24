/**
 * AnimatedBackground — full-page living background system.
 *
 * Layers (back → front):
 *   1. Static mesh gradient (CSS) — warm sage/teal base atmosphere
 *   2. GSAP-animated ambient orbs — large, slow-drifting radial blobs
 *   3. Framer Motion constellation dots — micro particle field
 *   4. Subtle SVG noise grain overlay (CSS)
 *
 * Fixed-position, pointer-events-none — invisible to layout.
 * Respects prefers-reduced-motion.
 */
'use client';

import { useRef, useEffect } from 'react';
import { motion } from 'framer-motion';
import { gsap } from 'gsap';

// ─── Orb config ──────────────────────────────────────────────────────────────

interface OrbConfig {
  id: string;
  /** Initial x position as % of viewport width */
  x: number;
  /** Initial y position as % of viewport height */
  y: number;
  /** Orb diameter in vw units */
  size: number;
  color: string;
  /** Animation duration in seconds */
  duration: number;
  /** x drift range in px */
  driftX: number;
  /** y drift range in px */
  driftY: number;
  opacity: number;
}

const ORBS: OrbConfig[] = [
  {
    id: 'orb-1',
    x: 15,
    y: 20,
    size: 55,
    color: 'radial-gradient(circle, rgba(207,225,185,0.18) 0%, rgba(207,225,185,0) 70%)',
    duration: 18,
    driftX: 80,
    driftY: 60,
    opacity: 1,
  },
  {
    id: 'orb-2',
    x: 75,
    y: 60,
    size: 65,
    color: 'radial-gradient(circle, rgba(120,200,180,0.12) 0%, rgba(120,200,180,0) 70%)',
    duration: 22,
    driftX: -100,
    driftY: 80,
    opacity: 1,
  },
  {
    id: 'orb-3',
    x: 50,
    y: 85,
    size: 45,
    color: 'radial-gradient(circle, rgba(207,225,185,0.10) 0%, rgba(207,225,185,0) 70%)',
    duration: 14,
    driftX: 60,
    driftY: -40,
    opacity: 1,
  },
  {
    id: 'orb-4',
    x: 85,
    y: 15,
    size: 40,
    color: 'radial-gradient(circle, rgba(168,216,168,0.14) 0%, rgba(168,216,168,0) 70%)',
    duration: 26,
    driftX: -70,
    driftY: 50,
    opacity: 1,
  },
  {
    id: 'orb-5',
    x: 30,
    y: 65,
    size: 35,
    color: 'radial-gradient(circle, rgba(100,180,160,0.08) 0%, rgba(100,180,160,0) 70%)',
    duration: 20,
    driftX: 50,
    driftY: -60,
    opacity: 1,
  },
];

// ─── Particle config ─────────────────────────────────────────────────────────

interface Particle {
  id: number;
  x: number; // % of width
  y: number; // % of height
  size: number;
  opacity: number;
  duration: number;
  delay: number;
}

const PARTICLES: Particle[] = Array.from({ length: 28 }, (_, i) => ({
  id: i,
  x: (i * 37 + 11) % 100,
  y: (i * 19 + 7) % 100,
  size: 1 + (i % 3) * 0.5,
  opacity: 0.15 + (i % 5) * 0.04,
  duration: 8 + (i % 7) * 3,
  delay: (i % 5) * 1.5,
}));

// ─── Component ───────────────────────────────────────────────────────────────

/**
 * Full-page animated background — fixed, behind all content.
 */
export function AnimatedBackground() {
  const orbsRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const prefersReduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (prefersReduced || !orbsRef.current) return;

    const orbs = orbsRef.current.querySelectorAll<HTMLElement>('.bg-orb');

    orbs.forEach((orb, i) => {
      const cfg = ORBS[i];
      if (!cfg) return;

      // Sinusoidal drift — each orb gets unique timing
      gsap.to(orb, {
        x: cfg.driftX,
        y: cfg.driftY,
        duration: cfg.duration,
        ease: 'sine.inOut',
        repeat: -1,
        yoyo: true,
        delay: i * 2.5,
      });

      // Subtle pulse opacity
      gsap.to(orb, {
        opacity: cfg.opacity * 0.6,
        duration: cfg.duration * 0.7,
        ease: 'sine.inOut',
        repeat: -1,
        yoyo: true,
        delay: i * 1.8,
      });
    });

    return () => {
      gsap.killTweensOf(orbs);
    };
  }, []);

  return (
    <div
      className="pointer-events-none fixed inset-0 z-0 overflow-hidden"
      aria-hidden="true"
    >
      {/* ── Layer 1: Base mesh gradient ─────────────────────────────────── */}
      <div
        className="absolute inset-0"
        style={{
          background: `
            radial-gradient(ellipse 80% 50% at 20% 30%, rgba(207,225,185,0.06) 0%, transparent 60%),
            radial-gradient(ellipse 60% 40% at 80% 70%, rgba(120,200,180,0.05) 0%, transparent 60%),
            radial-gradient(ellipse 50% 60% at 50% 100%, rgba(207,225,185,0.04) 0%, transparent 60%)
          `,
        }}
      />

      {/* ── Layer 2: GSAP-animated ambient orbs ─────────────────────────── */}
      <div ref={orbsRef} className="absolute inset-0">
        {ORBS.map((orb) => (
          <div
            key={orb.id}
            className="bg-orb absolute rounded-full"
            style={{
              left: `${orb.x}%`,
              top: `${orb.y}%`,
              width: `${orb.size}vw`,
              height: `${orb.size}vw`,
              background: orb.color,
              transform: 'translate(-50%, -50%)',
              filter: 'blur(40px)',
              opacity: orb.opacity,
            }}
          />
        ))}
      </div>

      {/* ── Layer 3: Framer Motion constellation dot field ──────────────── */}
      <div className="absolute inset-0">
        {PARTICLES.map((p) => (
          <motion.div
            key={p.id}
            className="absolute rounded-full bg-sage"
            style={{
              left: `${p.x}%`,
              top: `${p.y}%`,
              width: p.size,
              height: p.size,
            }}
            animate={{
              opacity: [p.opacity, p.opacity * 0.3, p.opacity],
              y: [0, -15, 0],
            }}
            transition={{
              duration: p.duration,
              delay: p.delay,
              repeat: Infinity,
              ease: 'easeInOut',
            }}
          />
        ))}
      </div>

      {/* ── Layer 4: Subtle grid overlay ────────────────────────────────── */}
      <div
        className="absolute inset-0 opacity-[0.025]"
        style={{
          backgroundImage: `
            linear-gradient(rgba(207,225,185,0.5) 1px, transparent 1px),
            linear-gradient(90deg, rgba(207,225,185,0.5) 1px, transparent 1px)
          `,
          backgroundSize: '80px 80px',
        }}
      />

      {/* ── Layer 5: Vignette edge darkening ────────────────────────────── */}
      <div
        className="absolute inset-0"
        style={{
          background: `
            radial-gradient(ellipse 120% 120% at 50% 50%, transparent 40%, rgba(0,0,0,0.6) 100%)
          `,
        }}
      />
    </div>
  );
}
