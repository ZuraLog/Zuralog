/**
 * Upstash Redis client singleton.
 *
 * Uses HTTP REST protocol — works in Vercel Serverless Functions,
 * Edge Middleware, and ISR. No TCP connections, no cold-start
 * connection overhead.
 */

import { Redis } from "@upstash/redis";

if (!process.env.UPSTASH_REDIS_REST_URL || !process.env.UPSTASH_REDIS_REST_TOKEN) {
  console.warn("Upstash Redis credentials missing — caching disabled");
}

export const redis = Redis.fromEnv();
