/**
 * Rate limiter using Upstash Redis.
 * Falls back gracefully if env vars are not set (development).
 */
import { Ratelimit } from '@upstash/ratelimit';
import { Redis } from '@upstash/redis';

function createRateLimiter() {
  const url = process.env.UPSTASH_REDIS_REST_URL;
  const token = process.env.UPSTASH_REDIS_REST_TOKEN;

  if (!url || !token) {
    return {
      limit: async (_identifier: string) => ({ success: true, limit: 5, remaining: 5, reset: 0 }),
    };
  }

  return new Ratelimit({
    redis: new Redis({ url, token }),
    limiter: Ratelimit.slidingWindow(5, '60 s'),
    analytics: true,
    prefix: 'zuralog_waitlist',
  });
}

export const rateLimiter = createRateLimiter();
