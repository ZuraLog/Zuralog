/**
 * Next.js configuration for the Zuralog website.
 * Monorepo-compatible setup with security headers and image optimization.
 */
import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  // Allow importing from parent directories (assets/brand/)
  transpilePackages: [],
  images: {
    formats: ['image/avif', 'image/webp'],
  },
  // Headers for security
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: [
          { key: 'X-Frame-Options', value: 'DENY' },
          { key: 'X-Content-Type-Options', value: 'nosniff' },
          { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
        ],
      },
    ];
  },
};

export default nextConfig;
