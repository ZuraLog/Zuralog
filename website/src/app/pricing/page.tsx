import { Metadata } from 'next';
import Link from 'next/link';
import { FloatingNav } from '@/components/layout/FloatingNav';
import { Footer } from '@/components/layout/Footer';

export const metadata: Metadata = {
  title: 'Pricing | ZuraLog',
  description: 'Simple, transparent pricing for ZuraLog — the AI that unifies your health and fitness data.',
};

export default function PricingPage() {
  return (
    <div className="relative flex min-h-screen flex-col bg-[#F0EEE9] font-jakarta" data-theme="light">
      <FloatingNav />

      <main className="flex-1 flex flex-col items-center justify-center px-6 py-36">
        <Link
          href="/"
          className="mb-12 inline-flex items-center gap-1.5 text-xs font-medium text-black/40 transition-colors hover:text-[#344E41] self-start max-w-[1280px] w-full mx-auto lg:px-12"
        >
          <svg aria-hidden="true" viewBox="0 0 16 16" fill="none" stroke="currentColor" strokeWidth="1.5" className="h-3.5 w-3.5">
            <path d="M10 12L6 8l4-4" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
          Back to home
        </Link>

        <div className="flex flex-col items-center gap-4 text-center max-w-lg mx-auto">
          <span className="inline-flex items-center gap-2 rounded-full border border-[#344E41]/20 bg-[#344E41]/8 px-3 py-1 text-[11px] font-medium uppercase tracking-widest text-[#344E41]/70">
            Coming Soon
          </span>
          <h1 className="text-[34px] font-bold tracking-tight text-[#161618]">
            Pricing is on the way.
          </h1>
          <p className="text-base leading-relaxed text-black/50">
            We are still figuring out the right pricing for ZuraLog. Join the waitlist and you will be the first to know — early supporters get founding access.
          </p>
          <div className="mt-4">
            <Link
              href="/#waitlist"
              className="relative isolate overflow-hidden inline-flex items-center justify-center gap-2 font-jakarta rounded-ds-pill h-[44px] px-6 text-[15px] font-semibold text-ds-text-on-sage ds-pattern-drift transition-all duration-300 hover:scale-[1.03] active:scale-[0.97]"
              style={{ backgroundImage: 'var(--ds-pattern-sage)' }}
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
