/**
 * In-memory sliding-window rate limiter.
 *
 * Replaces Upstash Redis — zero external dependencies, zero cost.
 * Works on Vercel serverless: warm function instances persist the Map
 * between invocations for several minutes. Cold starts reset the
 * window, which is acceptable for a waitlist signup endpoint.
 *
 * Algorithm: sliding window log — stores timestamps of recent requests
 * per identifier (IP address). On each check, prunes expired entries
 * and counts remaining.
 */

interface RateLimitResult {
  success: boolean;
  limit: number;
  remaining: number;
  reset: number;
}

interface RateLimiterConfig {
  /** Maximum requests allowed within the window. */
  maxRequests: number;
  /** Window duration in milliseconds. */
  windowMs: number;
}

/** Per-identifier request log: array of timestamps (ms). */
const requestLog = new Map<string, number[]>();

/** Periodic cleanup to prevent unbounded memory growth. */
let cleanupScheduled = false;

function scheduleCleanup(windowMs: number) {
  if (cleanupScheduled) return;
  cleanupScheduled = true;

  const interval = setInterval(() => {
    const now = Date.now();
    for (const [key, timestamps] of requestLog) {
      const valid = timestamps.filter((t) => now - t < windowMs);
      if (valid.length === 0) {
        requestLog.delete(key);
      } else {
        requestLog.set(key, valid);
      }
    }
  }, windowMs * 2);

  // .unref() prevents the timer from keeping the Node process alive
  if (typeof interval === 'object' && 'unref' in interval) {
    (interval as { unref: () => void }).unref();
  }
}

function createRateLimiter(config: RateLimiterConfig = { maxRequests: 5, windowMs: 60_000 }) {
  const { maxRequests, windowMs } = config;

  scheduleCleanup(windowMs);

  return {
    limit: async (identifier: string): Promise<RateLimitResult> => {
      const now = Date.now();
      const timestamps = requestLog.get(identifier) ?? [];

      // Prune entries outside the current window
      const valid = timestamps.filter((t) => now - t < windowMs);

      if (valid.length >= maxRequests) {
        const oldestInWindow = valid[0]!;
        return {
          success: false,
          limit: maxRequests,
          remaining: 0,
          reset: oldestInWindow + windowMs,
        };
      }

      // Allow — record timestamp
      valid.push(now);
      requestLog.set(identifier, valid);

      return {
        success: true,
        limit: maxRequests,
        remaining: maxRequests - valid.length,
        reset: now + windowMs,
      };
    },
  };
}

/** Waitlist signup: 5 requests per 60 seconds per IP. */
export const rateLimiter = createRateLimiter({ maxRequests: 5, windowMs: 60_000 });
