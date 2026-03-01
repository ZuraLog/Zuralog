"use client";

/**
 * PostHog analytics provider for the Next.js app.
 *
 * Wraps the application in the PostHog React context, enabling:
 * - Automatic pageview tracking on route changes
 * - Feature flag access via useFeatureFlagEnabled()
 * - Session recording (opt-in, controlled via PostHog dashboard)
 * - Event capture via usePostHog()
 *
 * This is a client component because PostHog requires browser APIs
 * (window, document, navigator) for initialization.
 */

import posthog from "posthog-js";
import { PostHogProvider as PHProvider, usePostHog } from "posthog-js/react";
import { usePathname, useSearchParams } from "next/navigation";
import { useEffect, Suspense } from "react";

// Initialize PostHog client-side only (runs once when module is first loaded)
if (typeof window !== "undefined" && process.env.NEXT_PUBLIC_POSTHOG_KEY) {
  posthog.init(process.env.NEXT_PUBLIC_POSTHOG_KEY, {
    api_host:
      process.env.NEXT_PUBLIC_POSTHOG_HOST || "https://us.i.posthog.com",

    // Manual pageview capture — Next.js App Router uses client-side navigation
    // which doesn't trigger full page loads, so we track manually via PostHogPageView
    capture_pageview: false,

    // Capture page leave events for session duration tracking
    capture_pageleave: true,

    // Session recording — opt-in, controlled via PostHog dashboard settings
    // Not auto-enabled; toggle in Project Settings → Session Recording
    session_recording: {
      maskAllInputs: true,
      maskTextSelector: "[data-ph-mask]",
    },

    // Autocapture — captures clicks, form submissions automatically
    autocapture: true,

    // Persistence via localStorage + cookie (survives page refreshes)
    persistence: "localStorage+cookie",

    // Strip accidentally captured email from set properties
    sanitize_properties: (properties) => {
      if (properties["$set"]?.email) {
        return {
          ...properties,
          $set: { ...properties["$set"], email: undefined },
        };
      }
      return properties;
    },

    loaded: (ph) => {
      if (process.env.NODE_ENV === "development") {
        ph.debug();
      }
    },
  });
}

/**
 * Tracks pageviews on route changes in Next.js App Router.
 *
 * App Router uses client-side navigation, so traditional pageview tracking
 * (on full page load) misses most navigations. This component listens to
 * pathname + searchParams changes and fires a manual $pageview event.
 *
 * Must be wrapped in <Suspense> because useSearchParams() suspends.
 */
function PostHogPageView() {
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const posthogClient = usePostHog();

  useEffect(() => {
    if (pathname && posthogClient) {
      let url = window.origin + pathname;
      const search = searchParams?.toString();
      if (search) {
        url += `?${search}`;
      }
      posthogClient.capture("$pageview", {
        $current_url: url,
      });
    }
  }, [pathname, searchParams, posthogClient]);

  return null;
}

/**
 * PostHog provider wrapper for the Next.js application.
 *
 * Usage in layout.tsx:
 *   import { PostHogProvider } from "@/components/providers/PostHogProvider";
 *   <PostHogProvider>{children}</PostHogProvider>
 */
export function PostHogProvider({ children }: { children: React.ReactNode }) {
  return (
    <PHProvider client={posthog}>
      <Suspense fallback={null}>
        <PostHogPageView />
      </Suspense>
      {children}
    </PHProvider>
  );
}
