/**
 * 500 Error page — ZuraLog.
 *
 * Next.js App Router renders this file for unhandled runtime errors.
 * Must be a Client Component because it receives the error and reset props.
 * Light, witty, health-themed — consistent with the 404 page.
 */

'use client';

import { useEffect } from 'react';
import Link from 'next/link';

interface ErrorPageProps {
  /** The error that was thrown */
  error: Error & { digest?: string };
  /** Call this to attempt recovering by re-rendering the segment */
  reset: () => void;
}

/**
 * Global error boundary page for unhandled server/client runtime errors.
 *
 * @param error - The caught error object
 * @param reset - Function to re-render and attempt recovery
 */
export default function ErrorPage({ error, reset }: ErrorPageProps) {
  useEffect(() => {
    // Log to console in dev; replace with error reporting service in production
    console.error('[ZuraLog] Unhandled error:', error);
  }, [error]);

  return (
    <div
      className="relative flex min-h-screen flex-col items-center justify-center px-6 py-32 text-center"
      style={{ background: '#FAFAF5' }}
    >
      {/* Big 500 */}
      <p
        className="text-[120px] font-bold leading-none tracking-tighter"
        style={{
          background: 'linear-gradient(135deg, #CFE1B9 0%, #D4F291 50%, #E8F5A8 100%)',
          WebkitBackgroundClip: 'text',
          WebkitTextFillColor: 'transparent',
          backgroundClip: 'text',
        }}
      >
        500
      </p>

      {/* Eyebrow */}
      <span className="mt-4 inline-flex items-center gap-2 rounded-full border border-[#E8F5A8]/60 bg-[#E8F5A8]/20 px-3 py-1 text-[10px] font-semibold uppercase tracking-widest text-[#2D2D2D]/60">
        <span className="h-1.5 w-1.5 rounded-full bg-[#D4F291] animate-pulse" />
        Server error
      </span>

      {/* Headline */}
      <h1 className="mt-5 max-w-sm text-2xl font-bold tracking-tight text-[#1A1A1A] sm:text-3xl">
        Our server pulled a muscle.
      </h1>

      {/* Subtext */}
      <p className="mt-4 max-w-xs text-sm leading-relaxed text-black/45">
        Something went wrong on our end. Give it a moment and try again.
        If the problem keeps up, let us know.
      </p>

      {/* Actions */}
      <div className="mt-8 flex flex-col items-center gap-3 sm:flex-row">
        <button
          type="button"
          onClick={reset}
          className="inline-flex items-center justify-center rounded-full bg-[#E8F5A8] px-6 py-2.5 text-sm font-semibold text-[#2D2D2D] transition-opacity hover:opacity-80"
        >
          Try again
        </button>
        <Link
          href="/"
          className="inline-flex items-center justify-center rounded-full border border-black/10 px-6 py-2.5 text-sm font-medium text-black/60 transition-colors hover:border-[#CFE1B9] hover:text-[#2D2D2D]"
        >
          Back to home
        </Link>
        <a
          href="mailto:support@zuralog.com"
          className="inline-flex items-center justify-center rounded-full border border-black/10 px-6 py-2.5 text-sm font-medium text-black/60 transition-colors hover:border-[#CFE1B9] hover:text-[#2D2D2D]"
        >
          Report this
        </a>
      </div>

      {/* Error digest for debugging */}
      {error.digest && (
        <p className="mt-8 font-mono text-[10px] text-black/20">
          Error ID: {error.digest}
        </p>
      )}
    </div>
  );
}
