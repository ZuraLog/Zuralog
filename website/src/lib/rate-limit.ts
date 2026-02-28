/**
 * Distributed rate limiter powered by Upstash Redis.
 *
 * Replaces the previous in-memory sliding-window implementation.
 * This version persists across Vercel cold starts and works
 * consistently across all serverless function instances.
 *
 * Uses the Upstash Ratelimit SDK with a sliding window algorithm
 * backed by atomic Redis Lua scripts.
 */

import { Ratelimit } from "@upstash/ratelimit";
import { redis } from "@/lib/redis";

/**
 * Result of a rate limit check.
 * Maintains the same interface as the previous in-memory version
 * so existing consumers don't need changes.
 */
export interface RateLimitResult {
  success: boolean;
  limit: number;
  remaining: number;
  reset: number;
}

/**
 * Waitlist signup rate limiter: 5 requests per 60 seconds per IP.
 *
 * Matches the previous in-memory limiter's config exactly.
 * Now survives cold starts and is consistent across instances.
 */
const waitlistLimiter = new Ratelimit({
  redis,
  limiter: Ratelimit.slidingWindow(5, "60 s"),
  analytics: true,
  prefix: "ratelimit:waitlist",
});

/**
 * Contact form rate limiter: 3 requests per 60 seconds per IP.
 */
const contactLimiter = new Ratelimit({
  redis,
  limiter: Ratelimit.slidingWindow(3, "60 s"),
  analytics: true,
  prefix: "ratelimit:contact",
});

/**
 * General API rate limiter: 30 requests per 60 seconds per IP.
 * Used for public GET endpoints (stats, leaderboard, status).
 */
const generalLimiter = new Ratelimit({
  redis,
  limiter: Ratelimit.slidingWindow(30, "60 s"),
  analytics: true,
  prefix: "ratelimit:general",
});

/**
 * Check rate limit for a given identifier.
 *
 * @param identifier - Usually the client IP address.
 * @param type - Which limiter to use.
 * @returns Rate limit result compatible with the previous API.
 */
export async function checkRateLimit(
  identifier: string,
  type: "waitlist" | "contact" | "general" = "general"
): Promise<RateLimitResult> {
  const limiter =
    type === "waitlist"
      ? waitlistLimiter
      : type === "contact"
        ? contactLimiter
        : generalLimiter;

  const result = await limiter.limit(identifier);

  return {
    success: result.success,
    limit: result.limit,
    remaining: result.remaining,
    reset: result.reset,
  };
}

/**
 * Legacy-compatible export for existing consumers.
 *
 * The waitlist/join route imports `rateLimiter` and calls
 * `rateLimiter.limit(ip)`. This preserves that interface.
 */
export const rateLimiter = {
  limit: async (identifier: string): Promise<RateLimitResult> => {
    return checkRateLimit(identifier, "waitlist");
  },
};
