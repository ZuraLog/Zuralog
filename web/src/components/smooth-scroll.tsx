/**
 * SmoothScroll provider — integrates Lenis smooth scrolling with GSAP ScrollTrigger.
 *
 * Features:
 * - Buttery smooth scroll via Lenis
 * - GSAP ScrollTrigger synchronized via RAF ticker
 * - Respects `prefers-reduced-motion` — disables smooth scroll for accessibility
 * - Cleans up Lenis instance on unmount to prevent memory leaks
 *
 * Place this as a wrapper in layout.tsx around page content.
 */
'use client';

import { createContext, useContext, useEffect, useRef } from 'react';
import Lenis from 'lenis';
import { gsap, ScrollTrigger } from '@/lib/gsap';

interface SmoothScrollContextValue {
  /** The Lenis instance, or null if smooth scroll is disabled. */
  lenis: Lenis | null;
}

const SmoothScrollContext = createContext<SmoothScrollContextValue>({ lenis: null });

/**
 * Access the Lenis instance from any child component.
 *
 * @returns The SmoothScrollContextValue with a lenis instance (or null).
 */
export function useSmoothScroll() {
  return useContext(SmoothScrollContext);
}

interface SmoothScrollProps {
  children: React.ReactNode;
}

/**
 * Wraps children with Lenis smooth scroll, synced to GSAP ScrollTrigger.
 *
 * @param props.children - Page content to wrap.
 */
export function SmoothScroll({ children }: SmoothScrollProps) {
  const lenisRef = useRef<Lenis | null>(null);

  useEffect(() => {
    // Respect user's motion preference
    const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (prefersReducedMotion) return;

    const lenis = new Lenis({
      duration: 1.2,
      easing: (t) => Math.min(1, 1.001 - Math.pow(2, -10 * t)),
      orientation: 'vertical',
      smoothWheel: true,
    });

    lenisRef.current = lenis;

    // Sync Lenis scroll position with GSAP ScrollTrigger
    lenis.on('scroll', ScrollTrigger.update);

    // Drive Lenis via GSAP's ticker for frame-perfect sync
    const tickerHandler = (time: number) => {
      lenis.raf(time * 1000);
    };
    gsap.ticker.add(tickerHandler);
    gsap.ticker.lagSmoothing(0);

    return () => {
      gsap.ticker.remove(tickerHandler);
      lenis.destroy();
      lenisRef.current = null;
    };
  }, []);

  return (
    <SmoothScrollContext.Provider value={{ lenis: lenisRef.current }}>
      {children}
    </SmoothScrollContext.Provider>
  );
}
