/**
 * Analytics providers for the Zuralog website.
 *
 * Provides:
 * - PostHog for product analytics (events, funnels, session replay)
 * - PostHog is initialized only when NEXT_PUBLIC_POSTHOG_KEY is set
 *
 * Vercel Analytics and Speed Insights are added directly in layout.tsx
 * as they are server-safe (no client initialization needed).
 */
'use client';

import { useEffect } from 'react';
import { usePathname, useSearchParams } from 'next/navigation';
import posthog from 'posthog-js';

/** PostHog analytics provider — initializes on mount and tracks page views. */
export function PostHogProvider({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const searchParams = useSearchParams();

  useEffect(() => {
    const posthogKey = process.env.NEXT_PUBLIC_POSTHOG_KEY;
    const posthogHost = process.env.NEXT_PUBLIC_POSTHOG_HOST || 'https://us.i.posthog.com';

    if (!posthogKey) return;

    posthog.init(posthogKey, {
      api_host: posthogHost,
      person_profiles: 'identified_only',
      capture_pageview: false, // We manually track page views below
      capture_pageleave: true,
    });
  }, []);

  // Track page views on route change
  useEffect(() => {
    const posthogKey = process.env.NEXT_PUBLIC_POSTHOG_KEY;
    if (!posthogKey || !posthog.__loaded) return;

    const url = pathname + (searchParams.toString() ? `?${searchParams.toString()}` : '');
    posthog.capture('$pageview', { $current_url: url });
  }, [pathname, searchParams]);

  return <>{children}</>;
}
