/**
 * robots.ts — Next.js Metadata API for robots.txt generation.
 *
 * Allows all crawlers to index the site. Disables crawling of
 * internal API routes. Sitemap URL is included for discoverability.
 */
import type { MetadataRoute } from "next";

export default function robots(): MetadataRoute.Robots {
  const siteUrl = process.env.NEXT_PUBLIC_SITE_URL || "https://zuralog.com";

  return {
    rules: [
      {
        userAgent: "*",
        allow: "/",
        disallow: ["/api/", "/_next/"],
      },
    ],
    sitemap: `${siteUrl}/sitemap.xml`,
  };
}
