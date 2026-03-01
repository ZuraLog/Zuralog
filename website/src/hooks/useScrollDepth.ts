"use client";

/**
 * Hook to track scroll depth milestones (25%, 50%, 75%, 100%).
 *
 * Fires a 'page_scrolled' event to PostHog at each milestone,
 * only once per page load per milestone. Useful for understanding
 * how far users read on long pages (homepage, feature pages).
 *
 * Usage:
 *   function HomePage() {
 *     useScrollDepth();
 *     return <main>...</main>;
 *   }
 */

import { useEffect, useRef } from "react";
import { usePostHog } from "posthog-js/react";
import { usePathname } from "next/navigation";

export function useScrollDepth() {
  const posthog = usePostHog();
  const pathname = usePathname();
  const milestonesHit = useRef<Set<number>>(new Set());

  // Reset milestones only when the route changes, not when posthog ref changes
  useEffect(() => {
    milestonesHit.current = new Set();
  }, [pathname]);

  useEffect(() => {
    const handleScroll = () => {
      const scrollTop = window.scrollY;
      const docHeight =
        document.documentElement.scrollHeight - window.innerHeight;
      if (docHeight <= 0) return;

      const scrollPercent = Math.min(
        100,
        Math.round((scrollTop / docHeight) * 100)
      );
      const milestones = [25, 50, 75, 100];

      for (const milestone of milestones) {
        if (
          scrollPercent >= milestone &&
          !milestonesHit.current.has(milestone)
        ) {
          milestonesHit.current.add(milestone);
          posthog?.capture("page_scrolled", {
            depth: milestone,
            path: pathname,
          });
        }
      }
    };

    window.addEventListener("scroll", handleScroll, { passive: true });
    return () => window.removeEventListener("scroll", handleScroll);
  }, [pathname, posthog]);
}
