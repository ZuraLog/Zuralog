/**
 * Response caching utilities backed by Upstash Redis.
 *
 * Provides a simple get/set interface for caching API responses
 * with TTL. Falls back to no-op if Redis is unavailable.
 */

import { redis } from "@/lib/redis";

/**
 * Get a cached value.
 *
 * @param key - Cache key.
 * @returns The cached value or null.
 */
export async function getCached<T>(key: string): Promise<T | null> {
  try {
    const value = await redis.get<T>(key);
    return value;
  } catch {
    console.warn(`Cache GET failed: ${key}`);
    return null;
  }
}

/**
 * Set a cached value with TTL.
 *
 * @param key - Cache key.
 * @param value - Value to cache (must be JSON-serializable).
 * @param ttlSeconds - Time-to-live in seconds.
 */
export async function setCached<T>(
  key: string,
  value: T,
  ttlSeconds: number
): Promise<void> {
  try {
    await redis.set(key, JSON.stringify(value), { ex: ttlSeconds });
  } catch {
    console.warn(`Cache SET failed: ${key}`);
  }
}

/**
 * Delete a cached value.
 *
 * @param key - Cache key to delete.
 */
export async function deleteCached(key: string): Promise<void> {
  try {
    await redis.del(key);
  } catch {
    console.warn(`Cache DELETE failed: ${key}`);
  }
}
