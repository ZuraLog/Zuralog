/**
 * Next.js Edge Middleware — Global Rate Limiting.
 *
 * Runs on every matched request BEFORE the route handler.
 * Uses Upstash Ratelimit with the Edge-compatible REST client.
 *
 * Rate limits:
 * - API routes (/api/*): 60 requests/minute per IP
 * - Page routes: No rate limiting (static/ISR pages)
 */

import { NextResponse, type NextRequest } from "next/server";
import { Ratelimit } from "@upstash/ratelimit";
import { Redis } from "@upstash/redis";

// Create Redis client for Edge Runtime (can't use singleton from lib/redis
// because Edge Middleware has its own module scope)
const redis = new Redis({
  url: process.env.UPSTASH_REDIS_REST_URL!,
  token: process.env.UPSTASH_REDIS_REST_TOKEN!,
});

const globalLimiter = new Ratelimit({
  redis,
  limiter: Ratelimit.slidingWindow(60, "60 s"),
  analytics: true,
  prefix: "ratelimit:global",
});

export async function middleware(request: NextRequest) {
  // Only rate-limit API routes
  if (!request.nextUrl.pathname.startsWith("/api/")) {
    return NextResponse.next();
  }

  // Skip rate limiting for admin routes (authenticated separately)
  if (request.nextUrl.pathname.includes("/admin/")) {
    return NextResponse.next();
  }

  const ip =
    request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";

  const result = await globalLimiter.limit(ip);

  if (!result.success) {
    return NextResponse.json(
      { error: "Too many requests. Please try again later." },
      {
        status: 429,
        headers: {
          "X-RateLimit-Limit": String(result.limit),
          "X-RateLimit-Remaining": String(result.remaining),
          "X-RateLimit-Reset": String(result.reset),
          "Retry-After": String(Math.ceil((result.reset - Date.now()) / 1000)),
        },
      }
    );
  }

  // Add rate limit headers to successful responses
  const response = NextResponse.next();
  response.headers.set("X-RateLimit-Limit", String(result.limit));
  response.headers.set("X-RateLimit-Remaining", String(result.remaining));
  response.headers.set("X-RateLimit-Reset", String(result.reset));

  return response;
}

export const config = {
  matcher: ["/api/:path*"],
};
