/**
 * Next.js configuration for the ZuraLog marketing website.
 */
import type { NextConfig } from "next";
import { withSentryConfig } from "@sentry/nextjs";

const nextConfig: NextConfig = {
  images: {
    formats: ["image/avif", "image/webp"],
  },
  async headers() {
    return [
      {
        source: "/(.*)",
        headers: [
          { key: "X-Frame-Options", value: "DENY" },
          { key: "X-Content-Type-Options", value: "nosniff" },
          { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
          {
            key: "Permissions-Policy",
            value: "camera=(), microphone=(), geolocation=()",
          },
        ],
      },
    ];
  },
};

export default withSentryConfig(nextConfig, {
  // Upload source maps for readable stack traces
  sourcemaps: {
    deleteSourcemapsAfterUpload: true,
  },
  // Suppress noisy build logs
  silent: !process.env.CI,
  // Tunnel Sentry events through /monitoring to bypass ad blockers
  tunnelRoute: "/monitoring",
  // Automatically tree-shake Sentry logger from production bundles
  disableLogger: true,
  // Disable Sentry telemetry
  telemetry: false,
});
