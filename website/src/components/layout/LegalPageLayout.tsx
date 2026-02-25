/**
 * LegalPageLayout — shared wrapper for legal / policy pages.
 *
 * Provides a consistent cream background, max-width prose container,
 * back-to-home link, and heading hierarchy that matches the site's
 * Geist Sans / dark-charcoal / sage-lime design system.
 */

import Link from 'next/link';
import { Navbar } from '@/components/layout/Navbar';
import { Footer } from '@/components/layout/Footer';
import { PageBackground } from '@/components/PageBackground';

interface LegalPageLayoutProps {
  /** Page title shown as the H1 */
  title: string;
  /** ISO date string e.g. "2025-01-01" */
  lastUpdated: string;
  /** Body content rendered inside the prose container */
  children: React.ReactNode;
}

/**
 * Reusable shell for Privacy Policy, Terms of Service, and Cookie Policy pages.
 *
 * @param title       - Main H1 heading
 * @param lastUpdated - Last-updated date shown below the title
 * @param children    - Page-specific content sections
 * @returns Full page layout with navbar and footer included
 */
export function LegalPageLayout({ title, lastUpdated, children }: LegalPageLayoutProps) {
  const formatted = new Date(lastUpdated).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  });

  return (
    <>
      <PageBackground />
      <div className="relative flex min-h-screen flex-col">
        <Navbar />

        <main className="mx-auto w-full max-w-[720px] flex-1 px-6 pb-24 pt-32 lg:px-8">
          {/* Back link */}
          <Link
            href="/"
            className="mb-10 inline-flex items-center gap-1.5 text-xs font-medium text-black/40 transition-colors hover:text-[#2D2D2D]"
          >
            <svg
              aria-hidden="true"
              viewBox="0 0 16 16"
              fill="none"
              stroke="currentColor"
              strokeWidth="1.5"
              className="h-3.5 w-3.5"
            >
              <path d="M10 12L6 8l4-4" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
            Back to home
          </Link>

          {/* Header */}
          <div className="mb-10 border-b border-black/[0.06] pb-8">
            {/* Eyebrow */}
            <span className="mb-3 inline-flex items-center gap-2 rounded-full border border-[#E8F5A8]/60 bg-[#E8F5A8]/20 px-3 py-1 text-[10px] font-semibold uppercase tracking-widest text-[#2D2D2D]/60">
              Legal
            </span>
            <h1 className="mt-3 text-3xl font-bold tracking-tight text-[#1A1A1A] sm:text-4xl">
              {title}
            </h1>
            <p className="mt-3 text-sm text-black/40">Last updated: {formatted}</p>
          </div>

          {/* Prose content */}
          <div className="prose-legal">{children}</div>
        </main>

        <Footer />
      </div>
    </>
  );
}
