'use client';

import { useEffect } from 'react';

/**
 * Reads window.location.hash on mount and smooth-scrolls to the
 * matching element after a short delay.
 *
 * Required because Next.js App Router doesn't auto-scroll to hash
 * targets when navigating between pages, especially when sections
 * mount asynchronously via dynamic imports.
 */
export function HashScrollHandler() {
  useEffect(() => {
    const hash = window.location.hash.slice(1);
    if (!hash) return;

    // Delay to let lazy/dynamic sections mount and GSAP measure layout
    const timer = setTimeout(() => {
      const el = document.getElementById(hash);
      if (el) {
        el.scrollIntoView({ behavior: 'smooth' });
      }
    }, 300);

    return () => clearTimeout(timer);
  }, []);

  return null;
}
