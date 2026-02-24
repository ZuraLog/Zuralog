/**
 * twitter-image.tsx — Twitter/X card image.
 *
 * Re-exports the same OG image design for Twitter cards.
 * Next.js automatically picks this up for twitter:image meta.
 */
export { default } from './opengraph-image';

export const runtime = 'edge';
export const alt = 'ZuraLog — Unified Health. Made Smart.';
export const size = { width: 1200, height: 630 };
export const contentType = 'image/png';
