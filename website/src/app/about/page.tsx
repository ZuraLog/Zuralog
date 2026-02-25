/**
 * About Us page — ZuraLog company story, mission, values, and founders.
 *
 * Founders:
 *   - Hyowon Arzil B. Bernabe — Co-Founder, CEO & CTO
 *   - Fernando Leano           — Co-Founder, CEO & CFO
 *
 * Photo slots reserved at /public/founders/hyowon.jpg and
 * /public/founders/fernando.jpg — drop the files in to activate real photos.
 */

import { Metadata } from 'next';
import Image from 'next/image';
import Link from 'next/link';
import { FaLinkedinIn } from 'react-icons/fa6';
import { Navbar } from '@/components/layout/Navbar';
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
    title: 'Privacy First',
    body: 'Your health data is deeply personal. We encrypt everything, sell nothing, and give you full control at all times.',
  },
  {
    title: 'Radical Simplicity',
    body: 'Fragmented fitness apps create cognitive overload. We obsess over reducing that friction — one unified view, one clear recommendation.',
  },
  {
    title: 'Honest Intelligence',
    body: 'AI should be transparent. ZuraLog surfaces its reasoning so you can trust its suggestions — not just follow them blindly.',
  },
  {
    title: 'Built for Real People',
    body: "Not just elite athletes. We build for busy humans who want clarity about their health without spending hours staring at dashboards.",
  },
];

const FOUNDERS = [
  {
    name: 'Hyowon Arzil B. Bernabe',
    role: 'Co-Founder · CEO & CTO',
    initials: 'HB',
    photoPath: '/founders/hyowon.jpg',
    bio: "Hyowon studied Computer Science with one goal: build things that actually solve problems. He's the kind of person who can't see friction without immediately wanting to automate it away. ZuraLog started as one of those ideas — a tool he wanted for himself, to make sense of all the health data scattered across his apps. If it makes life easier for everyone else too, even better.",
    linkedin: 'https://linkedin.com/in/hyowon-bernabe',
  },
  {
    name: 'Fernando Leano',
    role: 'Co-Founder · CEO & CFO',
    initials: 'FL',
    photoPath: '/founders/fernando.jpg',
    bio: "Fernando is a born builder. He spent years working in the health space and kept running into the same wall — great data, zero clarity. He knows what it feels like to be deep in the fitness game and still not have a straight answer about why things aren't working. ZuraLog is the thing he wishes had existed. Now he's making sure it does.",
    linkedin: 'https://www.linkedin.com/in/fernando-leano-7221b13b3/',
  },
];

// ---------------------------------------------------------------------------
// Subcomponents
// ---------------------------------------------------------------------------

interface FounderCardProps {
  name: string;
  role: string;
  initials: string;
  photoPath: string;
  bio: string;
  linkedin: string;
}

/**
 * Founder profile card with photo placeholder, bio, and LinkedIn link.
 *
 * @param name      - Full name
 * @param role      - Role / title string
 * @param initials  - Two-letter initials shown while no photo is available
 * @param photoPath - Path to photo in /public (reserved for later)
 * @param bio       - Short biography text
 * @param linkedin  - LinkedIn profile URL
 */
function FounderCard({ name, role, initials, photoPath, bio, linkedin }: FounderCardProps) {
  return (
    <div className="flex flex-col gap-5 rounded-3xl border border-black/[0.06] bg-white/60 p-8">
      {/* Avatar + name row */}
      <div className="flex items-center gap-4">
        {/* Photo slot — shows initials fallback until photo is added to /public/founders/ */}
        <FounderPhoto src={photoPath} name={name} initials={initials} />

        {/* Name + role + LinkedIn */}
        <div className="flex flex-1 flex-col gap-0.5">
          <div className="flex items-center gap-2">
            <span className="text-sm font-semibold text-[#1A1A1A]">{name}</span>
            <a
              href={linkedin}
              target="_blank"
              rel="noopener noreferrer"
              aria-label={`${name} on LinkedIn`}
              className="flex h-5 w-5 items-center justify-center rounded-full border border-black/[0.08] bg-white/60 text-black/30 transition-all hover:border-[#CFE1B9] hover:text-[#2D2D2D]"
            >
              <FaLinkedinIn className="h-2.5 w-2.5" />
            </a>
          </div>
          <span className="text-xs font-medium text-black/40">{role}</span>
        </div>
      </div>

      {/* Bio */}
      <p className="text-sm leading-relaxed text-black/50">{bio}</p>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

export default function AboutPage() {
  return (
    <>
      <PageBackground />
      <div className="relative flex min-h-screen flex-col">
        <Navbar />

        <main className="flex-1">
          {/* ── Hero ─────────────────────────────────────────────────── */}
          <section className="mx-auto max-w-[1280px] px-6 pb-20 pt-36 lg:px-12">
            {/* Back link */}
            <Link
              href="/"
              className="mb-12 inline-flex items-center gap-1.5 text-xs font-medium text-black/40 transition-colors hover:text-[#2D2D2D]"
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

            <div className="flex flex-col items-start gap-16 lg:flex-row lg:gap-24">
              {/* Left: text */}
              <div className="flex-1">
                <span className="mb-4 inline-flex items-center gap-2 rounded-full border border-[#E8F5A8]/60 bg-[#E8F5A8]/20 px-3 py-1 text-[10px] font-semibold uppercase tracking-widest text-[#2D2D2D]/60">
                  Our Story
                </span>
                <h1 className="mt-3 text-4xl font-bold tracking-tight text-[#1A1A1A] sm:text-5xl lg:text-[56px] lg:leading-[1.1]">
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
                    className="inline-flex items-center justify-center rounded-full bg-[#E8F5A8] px-6 py-2.5 text-sm font-semibold text-[#2D2D2D] transition-opacity hover:opacity-80"
                  >
                    Join the waitlist
                  </Link>
                  <a
                    href="mailto:support@zuralog.com"
                    className="inline-flex items-center justify-center rounded-full border border-black/10 px-6 py-2.5 text-sm font-medium text-black/60 transition-colors hover:border-[#CFE1B9] hover:text-[#2D2D2D]"
                  >
                    Get in touch
                  </a>
                </div>
              </div>

              {/* Right: logo lockup */}
              <div className="flex items-center justify-center lg:w-64">
                <div className="flex flex-col items-center gap-5 rounded-3xl border border-black/[0.06] bg-white/60 p-10 shadow-sm">
                  <Image
                    src="/logo/Zuralog.png"
                    alt="ZuraLog logo"
                    width={64}
                    height={64}
                    className="rounded-2xl object-contain"
                  />
                  <div className="text-center">
                    <p
                      className="text-base font-semibold tracking-tight"
                      style={{ color: '#CFE1B9' }}
                    >
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
          <section className="border-y border-black/[0.06] bg-[#2D2D2D] py-20">
            <div className="mx-auto max-w-[1280px] px-6 lg:px-12">
              <p className="max-w-3xl text-2xl font-medium leading-relaxed tracking-tight text-white/70 sm:text-3xl">
                Our mission is to give every person a single, intelligent view of their
                health — one that adapts to their life, speaks plainly, and actually helps
                them improve.
              </p>
            </div>
          </section>

          {/* ── Founders ─────────────────────────────────────────────── */}
          <section className="mx-auto max-w-[1280px] px-6 py-20 lg:px-12">
            <h2 className="mb-2 text-[10px] font-semibold uppercase tracking-[0.22em] text-black/30">
              The People Behind It
            </h2>
            <p className="mb-10 text-sm text-black/40">
              Two builders. One shared frustration. Zero tolerance for fragmented data.
            </p>
            <div className="grid grid-cols-1 gap-6 md:grid-cols-2">
              {FOUNDERS.map((founder) => (
                <FounderCard key={founder.name} {...founder} />
              ))}
            </div>
          </section>

          {/* ── Values ───────────────────────────────────────────────── */}
          <section className="border-t border-black/[0.06] bg-[#FAFAF5] px-6 py-20 lg:px-12">
            <div className="mx-auto max-w-[1280px]">
              <h2 className="mb-10 text-[10px] font-semibold uppercase tracking-[0.22em] text-black/30">
                What We Stand For
              </h2>
              <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-4">
                {VALUES.map((v) => (
                  <div
                    key={v.title}
                    className="rounded-3xl border border-black/[0.06] bg-white/60 p-8"
                  >
                    <h3 className="mb-3 text-sm font-semibold text-[#1A1A1A]">{v.title}</h3>
                    <p className="text-sm leading-relaxed text-black/45">{v.body}</p>
                  </div>
                ))}
              </div>
            </div>
          </section>

          {/* ── Contact CTA ──────────────────────────────────────────── */}
          <section className="border-t border-black/[0.06] py-20">
            <div className="mx-auto max-w-[1280px] px-6 text-center lg:px-12">
              <h2 className="mb-2 text-2xl font-bold tracking-tight text-[#1A1A1A]">
                Say hello
              </h2>
              <p className="mb-6 text-sm text-black/40">
                Questions, press inquiries, partnership ideas — we&apos;d love to hear from you.
              </p>
              <a
                href="mailto:support@zuralog.com"
                className="inline-flex items-center gap-2 rounded-full bg-[#E8F5A8] px-6 py-2.5 text-sm font-semibold text-[#2D2D2D] transition-opacity hover:opacity-80"
              >
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
