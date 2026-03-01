/**
 * Server-side PostHog client for API route tracking.
 *
 * Uses posthog-node for server-side event capture in Next.js
 * API routes and Server Actions. Cannot be imported in client components.
 *
 * Returns null if POSTHOG_API_KEY is not set, making all
 * tracking calls safe no-ops.
 */

import { PostHog } from "posthog-node";

// Use globalThis to survive Next.js hot-reloads in development
// without creating multiple instances with multiple flush timers.
const globalForPostHog = globalThis as typeof globalThis & {
  posthogClient?: PostHog;
};

/**
 * Get or create the server-side PostHog client singleton.
 *
 * Returns null if POSTHOG_API_KEY is not set (local dev without credentials).
 * All callers must guard with `if (posthog)` before calling.
 */
export function getServerPostHog(): PostHog | null {
  if (!process.env.POSTHOG_API_KEY) {
    return null;
  }

  if (!globalForPostHog.posthogClient) {
    globalForPostHog.posthogClient = new PostHog(
      process.env.POSTHOG_API_KEY,
      {
        host:
          process.env.NEXT_PUBLIC_POSTHOG_HOST ||
          "https://us.i.posthog.com",
        // flushAt: 1 ensures events are sent immediately in serverless
        // environments where the process may be frozen before a batch accumulates.
        flushAt: 1,
        flushInterval: 0,
      }
    );
  }

  return globalForPostHog.posthogClient;
}

/**
 * Capture a server-side event and immediately flush to PostHog.
 *
 * Prefer this over calling capture() + flushAsync() manually.
 * Safe to call when POSTHOG_API_KEY is not set — returns immediately.
 *
 * @param distinctId - User identifier (email for pre-auth, Supabase UID for auth'd)
 * @param event - Event name
 * @param properties - Optional event properties (no PII)
 */
export async function captureServerEvent(
  distinctId: string,
  event: string,
  properties?: Record<string, unknown>
): Promise<void> {
  const ph = getServerPostHog();
  if (!ph) return;
  try {
    await ph.captureImmediate({ distinctId, event, properties });
  } catch {
    // Analytics must never break server logic
  }
}
