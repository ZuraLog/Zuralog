/**
 * sitemap.ts — Next.js Metadata API for sitemap.xml generation.
 *
 * Currently contains just the homepage. Phase 3.2+ will add
 * dynamic routes once waitlist and content pages are built.
 */
import type { MetadataRoute } from 'next';

/**
 * Generates the XML sitemap for the site.
 *
 * @returns MetadataRoute.Sitemap — array of URL entries.
 */
export default function sitemap(): MetadataRoute.Sitemap {
  const siteUrl = process.env.NEXT_PUBLIC_SITE_URL || 'https://zuralog.com';

  return [
    {
      url: siteUrl,
      lastModified: new Date(),
      changeFrequency: 'weekly',
      priority: 1,
    },
  ];
}
