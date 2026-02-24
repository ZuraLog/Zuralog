/**
 * ScrollHandler — reads the `?scroll=` query parameter on mount and
 * smoothly scrolls to the matching section ID.
 *
 * Used by the /waitlist redirect to land the user on #waitlist.
 * Must be wrapped in <Suspense> by the caller (useSearchParams requirement).
 */
'use client';

import { useEffect } from 'react';
import { useSearchParams } from 'next/navigation';

/**
 * Reads `?scroll=<sectionId>` from the URL and scrolls to that element.
 * Waits briefly for the page to finish painting before scrolling.
 */
export function ScrollHandler() {
  const searchParams = useSearchParams();
  const scrollTarget = searchParams.get('scroll');

  useEffect(() => {
    if (!scrollTarget) return;
    // Give the page time to render before scrolling
    const timer = setTimeout(() => {
      document.getElementById(scrollTarget)?.scrollIntoView({ behavior: 'smooth' });
    }, 500);
    return () => clearTimeout(timer);
  }, [scrollTarget]);

  return null;
}
