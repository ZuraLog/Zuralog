/**
 * 500 Error page — ZuraLog.
 * Next.js App Router renders this file for unhandled runtime errors.
 * Must be a Client Component because it receives the error and reset props.
 */

'use client';

import * as Sentry from "@sentry/nextjs";
import { useEffect } from 'react';
import Link from 'next/link';
import { FloatingNav } from '@/components/layout/FloatingNav';
import { Footer } from '@/components/layout/Footer';
import { DSButton } from '@/components/design-system';

interface ErrorPageProps {
  error: Error & { digest?: string };
  reset: () => void;
}

export default function ErrorPage({ error, reset }: ErrorPageProps) {
  useEffect(() => {
    Sentry.captureException(error);
  }, [error]);

  return (
    <div className="relative flex min-h-screen flex-col bg-[#F0EEE9] font-jakarta" data-theme="light">
      <FloatingNav />

      <main className="flex flex-1 items-center justify-center px-6 py-32">
        <div className="flex max-w-md flex-col items-center text-center">

          {/* Big 500 — topographic pattern text */}
          <p
            className="ds-pattern-text text-[120px] font-bold leading-none tracking-tighter select-none"
            style={{ backgroundImage: 'var(--ds-pattern-sage)' }}
          >
            500
          </p>

          {/* Eyebrow */}
          <span className="mt-4 inline-flex items-center gap-2 rounded-full border border-[#344E41]/20 bg-[#344E41]/8 px-3 py-1 text-[11px] font-medium uppercase tracking-widest text-[#344E41]/70">
            <span className="h-1.5 w-1.5 rounded-full bg-[#344E41] animate-pulse" />
            Server error
          </span>

          {/* Headline */}
          <h1 className="mt-5 text-[24px] font-semibold tracking-tight text-[#161618]">
            Our server pulled a muscle.
          </h1>

          {/* Subtext */}
          <p className="mt-4 text-[14px] leading-relaxed text-black/45">
            Something went wrong on our end. Give it a moment and try again.
            If the problem keeps up, let us know.
          </p>

          {/* Actions */}
          <div className="mt-8 flex flex-col items-center gap-3 sm:flex-row">
            <DSButton intent="primary" size="md" onClick={reset}>
              Try again
            </DSButton>
            <Link
              href="/"
              className="relative isolate overflow-hidden inline-flex items-center justify-center gap-2 font-jakarta rounded-ds-pill h-[44px] px-6 text-[15px] font-semibold bg-transparent border-[1.5px] border-[var(--color-ds-secondary-border)] text-ds-text-primary transition-all duration-300 hover:scale-[1.03] active:scale-[0.97]"
            >
              Back to home
            </Link>
            <a
              href="mailto:support@zuralog.com"
              className="relative isolate overflow-hidden inline-flex items-center justify-center gap-2 font-jakarta rounded-ds-pill h-[44px] px-6 text-[15px] font-semibold bg-transparent border-[1.5px] border-[var(--color-ds-secondary-border)] text-ds-text-primary transition-all duration-300 hover:scale-[1.03] active:scale-[0.97]"
            >
              Report this
            </a>
          </div>

          {error.digest && (
            <p className="mt-8 font-mono text-[11px] text-black/20">
              Error ID: {error.digest}
            </p>
          )}

        </div>
      </main>

      <Footer />
    </div>
  );
}
