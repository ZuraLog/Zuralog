/**
 * 404 Not Found page — ZuraLog.
 * Next.js App Router automatically renders this file for any unmatched route.
 */

import Link from 'next/link';
import { FloatingNav } from '@/components/layout/FloatingNav';
import { Footer } from '@/components/layout/Footer';
import { PageBackground } from '@/components/PageBackground';

export default function NotFound() {
  return (
    <>
      <PageBackground />
      <div className="relative flex min-h-screen flex-col font-jakarta">
        <FloatingNav />

        <main className="flex flex-1 items-center justify-center px-6 py-32">
          <div className="flex max-w-md flex-col items-center text-center">

            {/* Big 404 */}
            <p
              className="text-[120px] font-bold leading-none tracking-tighter"
              style={{
                background: 'linear-gradient(135deg, #344E41 0%, #9EC98F 100%)',
                WebkitBackgroundClip: 'text',
                WebkitTextFillColor: 'transparent',
                backgroundClip: 'text',
              }}
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
                className="btn-pattern-light inline-flex items-center justify-center rounded-full bg-[#344E41] px-6 py-2.5 text-[13px] font-medium text-[#F0EEE9] shadow-[0_2px_16px_rgba(52,78,65,0.2)] transition-all duration-300 hover:scale-[1.03] hover:shadow-[0_4px_30px_rgba(52,78,65,0.4)] active:scale-[0.97]"
              >
                Back to home
              </Link>
              <Link
                href="/#waitlist"
                className="inline-flex items-center justify-center rounded-full border border-black/10 px-6 py-2.5 text-[13px] font-medium text-black/60 transition-colors hover:border-[#344E41]/30 hover:text-[#344E41]"
              >
                Join the waitlist
              </Link>
            </div>

          </div>
        </main>

        <Footer />
      </div>
    </>
  );
}
