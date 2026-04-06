/**
 * About Us page — ZuraLog company story, mission, values, and founders.
 *
 * Founders:
 *   - Hyowon Arzil B. Bernabe — Co-Founder, CTO & COO
 *   - Fernando Leano           — Co-Founder, CEO & CFO
 */

import { Metadata } from 'next';
import Image from 'next/image';
import Link from 'next/link';
import { FaLinkedinIn } from 'react-icons/fa6';
import { FloatingNav } from '@/components/layout/FloatingNav';
import { Footer } from '@/components/layout/Footer';
import { PageBackground } from '@/components/PageBackground';
import { FounderPhoto } from '@/components/ui/FounderPhoto';

export const metadata: Metadata = {
  title: 'About Us | ZuraLog',
  description:
    'Meet the team behind ZuraLog — the AI that unifies your health and fitness data into one intelligent action layer.',
};

// ---------------------------------------------------------------------------
// Data
// ---------------------------------------------------------------------------

const VALUES = [
  {
    icon: (
      <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z" />
      </svg>
    ),
    title: 'Privacy First',
    body: 'Your health data is deeply personal. We encrypt everything, sell nothing, and give you full control at all times.',
  },
  {
    icon: (
      <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M9 9V4.5M9 9H4.5M9 9L3.75 3.75M9 15v4.5M9 15H4.5M9 15l-5.25 5.25M15 9h4.5M15 9V4.5M15 9l5.25-5.25M15 15h4.5M15 15v4.5m0-4.5l5.25 5.25" />
      </svg>
    ),
    title: 'Radical Simplicity',
    body: 'Fragmented fitness apps create cognitive overload. We obsess over reducing that friction — one unified view, one clear recommendation.',
  },
  {
    icon: (
      <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12z" />
      </svg>
    ),
    title: 'Honest Intelligence',
    body: 'AI should be transparent. ZuraLog surfaces its reasoning so you can trust its suggestions — not just follow them blindly.',
  },
  {
    icon: (
      <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M15 19.128a9.38 9.38 0 002.625.372 9.337 9.337 0 004.121-.952 4.125 4.125 0 00-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 018.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0111.964-3.07M12 6.375a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zm8.25 2.25a2.625 2.625 0 11-5.25 0 2.625 2.625 0 015.25 0z" />
      </svg>
    ),
    title: 'Built for Real People',
    body: "Not just elite athletes. We build for busy humans who want clarity about their health without spending hours staring at dashboards.",
  },
];

const FOUNDERS = [
  {
    name: 'Hyowon Arzil B. Bernabe',
    role: 'Co-Founder · CTO & COO',
    initials: 'HB',
    photoPath: '/founders/hyowon.jpg',
    bio: "Hyowon is a programmer and Computer Science graduate who builds things with one goal in mind — solve real problems. He can't see friction without wanting to automate it away. ZuraLog started as one of those ideas: a tool he wanted for himself, to make sense of all the health data scattered across his apps. If it makes life easier for everyone else too, even better.",
    linkedin: 'https://linkedin.com/in/hyowon-bernabe',
    email: 'hyowonbernabe@zuralog.com',
  },
  {
    name: 'Fernando Leano',
    role: 'Co-Founder · CEO & CFO',
    initials: 'FL',
    photoPath: '/founders/fernando.jpg',
    bio: "Fernando is a detail-oriented software engineer and entrepreneur with half a decade of experience building automation systems and data infrastructure in the health industry. As Automation Lead and Lead Programmer at a health insurance FMO, he developed portal systems that streamlined operations for agents and agency partners across the country. That work revealed a persistent gap: an abundance of personal health data with no intelligent layer to make sense of it. He founded ZuraLog to close that gap. Today he serves as CEO and CFO, leading the company from concept to launch.",
    linkedin: 'https://www.linkedin.com/in/fernando-leano-682b28208/',
    email: 'fernandoleano@zuralog.com',
  },
];

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

export default function AboutPage() {
  return (
    <>
      <PageBackground />
      <div className="relative flex min-h-screen flex-col font-jakarta">
        <FloatingNav />

        <main className="flex-1">
          {/* ── Hero ─────────────────────────────────────────────────── */}
          <section className="mx-auto max-w-[1280px] px-6 pb-20 pt-36 lg:px-12">
            {/* Back link */}
            <Link
              href="/"
              className="mb-12 inline-flex items-center gap-1.5 text-xs font-medium text-black/40 transition-colors hover:text-[#344E41]"
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

            <div className="flex flex-col items-start gap-16 lg:flex-row lg:items-center lg:gap-20">
              {/* Left: text */}
              <div className="flex-1">
                <span className="mb-4 inline-flex items-center gap-2 rounded-full border border-[#344E41]/20 bg-[#344E41]/8 px-3 py-1 text-[11px] font-medium uppercase tracking-widest text-[#344E41]/70">
                  Our Story
                </span>
                <h1 className="mt-3 text-[34px] font-bold tracking-tight text-[#161618] sm:text-5xl lg:text-[72px] lg:leading-[1.05]">
                  Health data shouldn&apos;t be this hard.
                </h1>
                <p className="mt-6 max-w-lg text-lg leading-relaxed text-black/50">
                  ZuraLog was born out of frustration. Between Garmin, Apple Health, Strava,
                  MyFitnessPal, Whoop, and a dozen others — the data existed, but the insight
                  didn&apos;t. We built the layer that was missing.
                </p>

                <div className="mt-8 flex flex-col gap-4 sm:flex-row">
                  <Link
                    href="/#waitlist"
                    className="inline-flex items-center justify-center rounded-full bg-[#344E41] px-6 py-2.5 text-[13px] font-medium text-[#F0EEE9] shadow-[0_2px_16px_rgba(52,78,65,0.25)] transition-all duration-300 hover:opacity-90 hover:scale-[1.03] active:scale-[0.97]"
                  >
                    Join the waitlist
                  </Link>
                  <a
                    href="mailto:support@zuralog.com"
                    className="inline-flex items-center justify-center rounded-full border border-black/10 px-6 py-2.5 text-[13px] font-medium text-black/60 transition-colors hover:border-[#344E41]/30 hover:text-[#344E41]"
                  >
                    Get in touch
                  </a>
                </div>
              </div>

              {/* Right: logo lockup */}
              <div className="flex items-center justify-center lg:w-64">
                <div className="flex flex-col items-center gap-5 rounded-3xl border border-black/[0.06] bg-[#E8E6E1] p-10 shadow-sm">
                  <Image
                    src="/logo/ZuraLog-Forest-Green.svg"
                    alt="ZuraLog logo"
                    width={64}
                    height={64}
                    className="rounded-2xl object-contain"
                  />
                  <div className="text-center">
                    <p className="text-[17px] font-semibold tracking-tight" style={{ color: '#344E41' }}>
                      ZuraLog
                    </p>
                    <p className="mt-1 text-[10px] font-semibold uppercase tracking-[0.22em] text-black/30">
                      Unified Health. Made Smart.
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </section>

          {/* ── Mission ──────────────────────────────────────────────── */}
          <section className="py-20">
            <div className="mx-auto flex max-w-[800px] flex-col items-center gap-6 px-6 text-center">
              <div className="h-0.5 w-10 bg-black/[0.12]" />
              <p className="text-[22px] font-medium italic leading-[1.7] text-black/50">
                Our mission is to give every person a single, intelligent view of their
                health — one that adapts to their life, speaks plainly, and actually helps
                them improve.
              </p>
              <div className="h-0.5 w-10 bg-black/[0.12]" />
            </div>
          </section>

          {/* ── Team — Editorial Layout ────────────────────────────── */}
          <section className="mx-auto max-w-[1280px] px-6 py-20 lg:px-12">
            <div className="flex flex-col gap-10 lg:flex-row lg:items-stretch lg:gap-10">
              {/* ── Left Column: Bold text + Hyowon ──────────────── */}
              <div className="flex flex-col lg:w-[420px] lg:shrink-0">
                {/* Text block */}
                <div className="flex flex-col items-center gap-7 px-4 py-10 text-center lg:px-8">
                  <p className="text-[12px] font-semibold uppercase tracking-[0.22em] text-black/30">
                    The People Behind It
                  </p>
                  <h2 className="text-[34px] font-bold leading-[1.2] tracking-tight text-[#161618]">
                    TWO BUILDERS.
                    <br />
                    ONE SHARED
                    <br />
                    FRUSTRATION.
                    <br />
                    ZERO TOLERANCE
                    <br />
                    FOR FRAGMENTED
                    <br />
                    DATA.
                  </h2>
                  <p className="max-w-[380px] text-[13px] uppercase leading-[1.6] tracking-[0.05em] text-black/40">
                    A team of builders, operators and health enthusiasts. The people who lived
                    the problem, building the solution.
                  </p>
                  <button className="group relative inline-flex items-center justify-center overflow-hidden border border-black/20 px-8 py-3.5 text-[13px] font-medium uppercase tracking-[0.15em] text-[#161618] transition-all duration-300 hover:border-[#344E41] hover:bg-[#344E41] hover:text-[#F0EEE9] hover:shadow-[0_2px_16px_rgba(52,78,65,0.25)] active:scale-[0.97]">
                    <span className="pointer-events-none absolute inset-[-50%] h-[200%] w-[200%] opacity-0 transition-opacity duration-500 group-hover:opacity-[0.08]" style={{ backgroundImage: 'url(/pattern-sm.jpg)', backgroundSize: '300px auto', backgroundRepeat: 'repeat', mixBlendMode: 'multiply', animation: 'patternDrift 25s linear infinite' }} />
                    <span className="relative z-[2]">Meet the Team</span>
                  </button>
                </div>

                {/* Hyowon photo */}
                <div className="relative aspect-square w-full overflow-hidden bg-gradient-to-b from-[#344E41]/[0.06] to-[#344E41]/[0.02]">
                  <Image
                    src={FOUNDERS[0].photoPath}
                    alt={`Photo of ${FOUNDERS[0].name}`}
                    fill
                    sizes="(max-width: 1024px) 100vw, 420px"
                    quality={100}
                    priority
                    className="object-cover"
                  />
                </div>

                {/* Hyowon info */}
                <div className="flex flex-col gap-2.5 pt-6">
                  <div className="flex items-center justify-between">
                    <h3 className="text-[15px] font-semibold uppercase tracking-[0.12em] text-[#161618]">
                      {FOUNDERS[0].name}
                    </h3>
                  </div>
                  <p className="text-[13px] font-medium text-black/40">{FOUNDERS[0].role}</p>
                  <p className="text-[13px] leading-[1.6] tracking-[0.02em] text-black/40">
                    {FOUNDERS[0].bio}
                  </p>
                  <div className="mt-1 flex gap-4">
                    <a
                      href={FOUNDERS[0].linkedin}
                      target="_blank"
                      rel="noopener noreferrer"
                      aria-label={`${FOUNDERS[0].name} on LinkedIn`}
                      className="flex items-center justify-center border border-black/10 px-5 py-3 text-[14px] font-bold text-[#161618] transition-colors hover:border-[#344E41]/30 hover:bg-[#344E41]/8"
                    >
                      in
                    </a>
                    <a
                      href={`mailto:${FOUNDERS[0].email}`}
                      className="flex items-center justify-center border border-black/10 px-6 py-3 text-[12px] font-semibold uppercase tracking-[0.15em] text-[#161618] transition-colors hover:border-[#344E41]/30 hover:bg-[#344E41]/8"
                    >
                      Connect
                    </a>
                  </div>
                </div>
              </div>

              {/* ── Right Column: Fernando + Supporters ──────────── */}
              <div className="flex flex-1 flex-col">
                {/* Fernando photo */}
                <div className="relative aspect-[4/3] w-full overflow-hidden rounded-t-[20px] bg-gradient-to-b from-[#344E41]/[0.06] to-[#344E41]/[0.02]">
                  <Image
                    src={FOUNDERS[1].photoPath}
                    alt={`Photo of ${FOUNDERS[1].name}`}
                    fill
                    sizes="(max-width: 1024px) 100vw, 50vw"
                    quality={100}
                    priority
                    className="object-cover"
                  />
                  {/* CO-FOUNDER badge */}
                  <div className="absolute bottom-6 right-6 flex items-center gap-2 rounded bg-[#E8E6E1] px-3.5 py-1.5">
                    <span className="h-2 w-2 rounded-full bg-black/30" />
                    <span className="text-[11px] font-semibold uppercase tracking-[0.15em] text-[#161618]">
                      Co-Founder
                    </span>
                  </div>
                </div>

                {/* Fernando info */}
                <div className="flex flex-col gap-2.5 pt-6">
                  <div className="flex items-center justify-between">
                    <h3 className="text-[15px] font-semibold uppercase tracking-[0.12em] text-[#161618]">
                      {FOUNDERS[1].name}
                    </h3>
                    <span className="text-[13px] font-medium text-black/40">{FOUNDERS[1].role}</span>
                  </div>
                  <p className="text-[13px] leading-[1.6] tracking-[0.02em] text-black/40">
                    {FOUNDERS[1].bio}
                  </p>
                  <div className="mt-1 flex gap-4">
                    <a
                      href={FOUNDERS[1].linkedin}
                      target="_blank"
                      rel="noopener noreferrer"
                      aria-label={`${FOUNDERS[1].name} on LinkedIn`}
                      className="flex items-center justify-center border border-black/10 px-5 py-3 text-[14px] font-bold text-[#161618] transition-colors hover:border-[#344E41]/30 hover:bg-[#344E41]/8"
                    >
                      in
                    </a>
                    <a
                      href={`mailto:${FOUNDERS[1].email}`}
                      className="flex items-center justify-center border border-black/10 px-6 py-3 text-[12px] font-semibold uppercase tracking-[0.15em] text-[#161618] transition-colors hover:border-[#344E41]/30 hover:bg-[#344E41]/8"
                    >
                      Connect
                    </a>
                  </div>
                </div>

                {/* Spacer to push Supporters to bottom */}
                <div className="flex-1" />

                {/* ── Supporters Block ───────────────────────────── */}
                <div className="flex flex-col gap-5 pt-6">
                  <div className="h-px w-full bg-black/[0.06]" />
                  <p className="text-[14px] font-semibold uppercase tracking-[0.2em] text-black/40">
                    Supporters
                  </p>
                  <h3 className="text-[36px] font-bold leading-[1.15] tracking-tight text-[#161618]">
                    SUPPORT THE FUTURE
                    <br />
                    OF UNIFIED HEALTH.
                  </h3>
                  <div className="h-px w-full bg-black/[0.06]" />
                  <p className="text-[15px] uppercase leading-[1.7] tracking-[0.04em] text-black/40">
                    Back our mission to give every person a single, intelligent view of their
                    health. Early supporters get founding access and a voice in what we build
                    next.
                  </p>
                  <div>
                    <a
                      href="https://buymeacoffee.com/zuralog"
                      target="_blank"
                      rel="noopener noreferrer"
                      className="btn-pattern-light inline-flex items-center justify-center rounded-full bg-[#344E41] px-7 py-3.5 text-[14px] font-semibold uppercase tracking-[0.15em] text-[#F0EEE9] shadow-[0_2px_16px_rgba(52,78,65,0.25)] transition-all duration-300 hover:scale-[1.03] hover:shadow-[0_4px_30px_rgba(52,78,65,0.45)] active:scale-[0.97]"
                    >
                      Support Us
                    </a>
                  </div>
                </div>
              </div>
            </div>
          </section>

          {/* ── Values ───────────────────────────────────────────────── */}
          <section className="border-t border-black/[0.06] bg-[#F0EEE9] px-6 py-20 lg:px-12">
            <div className="mx-auto max-w-[1280px]">
              <h2 className="mb-10 text-[12px] font-semibold uppercase tracking-[0.22em] text-black/30">
                What We Stand For
              </h2>
              <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-4">
                {VALUES.map((v) => (
                  <div
                    key={v.title}
                    className="rounded-2xl border border-black/[0.06] bg-[#E8E6E1] p-7"
                  >
                    <div className="mb-4 flex h-10 w-10 items-center justify-center rounded-[10px] bg-[#344E41]/8 text-[#344E41]">
                      {v.icon}
                    </div>
                    <h3 className="mb-3 text-[17px] font-semibold text-[#161618]">{v.title}</h3>
                    <p className="text-[14px] leading-relaxed text-black/45">{v.body}</p>
                  </div>
                ))}
              </div>
            </div>
          </section>

          {/* ── Contact CTA ──────────────────────────────────────────── */}
          <section className="border-t border-black/[0.06] py-20">
            <div className="mx-auto flex max-w-[1280px] flex-col items-center gap-6 px-6 text-center lg:px-12">
              <div className="h-0.5 w-10 bg-black/[0.12]" />
              <h2 className="text-[40px] font-bold tracking-tight text-[#161618]">
                Say hello
              </h2>
              <p className="text-base text-black/40">
                Questions, press inquiries, partnership ideas — we&apos;d love to hear from you.
              </p>
              <a
                href="mailto:support@zuralog.com"
                className="btn-pattern-light inline-flex items-center gap-2.5 rounded-full bg-[#344E41] px-9 py-4 text-[15px] font-semibold text-[#F0EEE9] shadow-[0_2px_16px_rgba(52,78,65,0.25)] transition-all duration-300 hover:scale-[1.03] hover:shadow-[0_4px_30px_rgba(52,78,65,0.45)] active:scale-[0.97]"
              >
                <svg className="h-[18px] w-[18px]" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M21.75 6.75v10.5a2.25 2.25 0 01-2.25 2.25h-15a2.25 2.25 0 01-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0019.5 4.5h-15a2.25 2.25 0 00-2.25 2.25m19.5 0v.243a2.25 2.25 0 01-1.07 1.916l-7.5 4.615a2.25 2.25 0 01-2.36 0L3.32 8.91a2.25 2.25 0 01-1.07-1.916V6.75" />
                </svg>
                support@zuralog.com
              </a>
            </div>
          </section>
        </main>

        <Footer />
      </div>
    </>
  );
}
