/**
 * useScrollProgress — tracks normalized scroll progress (0..1) for a section.
 *
 * Useful for GSAP scroll-triggered animations and 3D convergence effects.
 */
'use client';

import { useEffect, useRef, useState } from 'react';

/**
 * Returns a normalized scroll progress value between 0 and 1
 * for the current viewport scroll position.
 *
 * @returns progress — 0 at top, 1 at bottom of scrollable area.
 */
export function useScrollProgress(): number {
  const [progress, setProgress] = useState(0);

  useEffect(() => {
    const handleScroll = () => {
      const { scrollTop, scrollHeight, clientHeight } = document.documentElement;
      const total = scrollHeight - clientHeight;
      setProgress(total > 0 ? scrollTop / total : 0);
    };

    window.addEventListener('scroll', handleScroll, { passive: true });
    handleScroll();
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  return progress;
}

/**
 * Returns scroll progress (0..1) scoped to a specific element.
 *
 * @param ref - React ref pointing to the target element.
 * @returns progress — 0 when element enters viewport, 1 when it exits.
 */
export function useElementScrollProgress(
  ref: React.RefObject<HTMLElement | null>,
): number {
  const [progress, setProgress] = useState(0);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;

    const handleScroll = () => {
      const rect = el.getBoundingClientRect();
      const vh = window.innerHeight;
      // 0 when bottom of element is at bottom of viewport, 1 when top leaves top
      const raw = (vh - rect.bottom) / (vh + rect.height);
      setProgress(Math.max(0, Math.min(1, raw)));
    };

    window.addEventListener('scroll', handleScroll, { passive: true });
    handleScroll();
    return () => window.removeEventListener('scroll', handleScroll);
  }, [ref]);

  return progress;
}
