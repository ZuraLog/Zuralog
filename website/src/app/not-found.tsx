/**
 * 404 Not Found page — ZuraLog.
 * Next.js App Router automatically renders this file for any unmatched route.
 */

import Link from 'next/link';
import { FloatingNav } from '@/components/layout/FloatingNav';
import { Footer } from '@/components/layout/Footer';

export default function NotFound() {
  return (
    <div className="relative flex min-h-screen flex-col bg-[#F0EEE9] font-jakarta" data-theme="light">
      <FloatingNav />

      <main className="flex flex-1 items-center justify-center px-6 py-32">
        <div className="flex max-w-md flex-col items-center text-center">

          {/* Big 404 — topographic pattern text */}
          <p
            className="ds-pattern-text text-[120px] font-bold leading-none tracking-tighter select-none"
            style={{ backgroundImage: 'var(--ds-pattern-sage)' }}
          >
            404
          </p>

          {/* Eyebrow */}
          <span className="mt-4 inline-flex items-center gap-2 rounded-full border border-[#344E41]/20 bg-[#344E41]/8 px-3 py-1 text-[11px] font-medium uppercase tracking-widest text-[#344E41]/70">
            <span className="h-1.5 w-1.5 rounded-full bg-[#344E41]" />
            Page not found
          </span>

          {/* Headline */}
          <h1 className="mt-5 text-[24px] font-semibold tracking-tight text-[#161618]">
            Looks like this page skipped leg day.
          </h1>

          {/* Subtext */}
          <p className="mt-4 text-[14px] leading-relaxed text-black/45">
            It trained hard, but it just does not exist. The page you are
            looking for may have been moved, deleted, or never existed in the
            first place.
          </p>

          {/* Actions */}
          <div className="mt-8 flex flex-col items-center gap-3 sm:flex-row">
            <Link
              href="/"
              className="relative isolate overflow-hidden inline-flex items-center justify-center gap-2 font-jakarta rounded-ds-pill h-[44px] px-6 text-[15px] font-semibold text-ds-text-on-sage ds-pattern-drift transition-all duration-300 hover:scale-[1.03] active:scale-[0.97]"
              style={{ backgroundImage: 'var(--ds-pattern-sage)' }}
            >
              Back to home
            </Link>
            <Link
              href="/#waitlist"
              className="relative isolate overflow-hidden inline-flex items-center justify-center gap-2 font-jakarta rounded-ds-pill h-[44px] px-6 text-[15px] font-semibold bg-transparent border-[1.5px] border-[var(--color-ds-secondary-border)] text-ds-text-primary transition-all duration-300 hover:scale-[1.03] active:scale-[0.97]"
            >
              Join the waitlist
            </Link>
          </div>

        </div>
      </main>

      <Footer />
    </div>
  );
}
