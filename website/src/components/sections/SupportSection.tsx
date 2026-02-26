/**
 * SupportSection — main content for the /support page.
 *
 * Layout:
 *   1. Hero: heading + subtitle + total funds raised counter
 *   2. Primary CTA: Buy Me a Coffee card
 *   3. Other ways to support: grid of cards
 *   4. Leaderboard: top 10 funders
 */
'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { motion } from 'framer-motion';
import { WaitlistCounter } from '@/components/waitlist-counter';
import { SupportLeaderboard } from '@/components/support-leaderboard';
import {
  FaXTwitter,
  FaInstagram,
  FaLinkedinIn,
  FaTiktok,
} from 'react-icons/fa6';

// ── Types ──────────────────────────────────────────────────────────────
interface SupportStats {
  totalFundsRaised: number;
  totalSupporters: number;
  leaderboard: { rank: number; name: string; amount: number }[];
}

// ── Data fetcher ───────────────────────────────────────────────────────
async function fetchSupportStats(): Promise<SupportStats | null> {
  try {
    const r = await fetch('/api/support/stats', { cache: 'no-store' });
    if (!r.ok) return null;
    return (await r.json()) as SupportStats;
  } catch {
    return null;
  }
}

// ── Social share links ─────────────────────────────────────────────────
const SOCIAL_SHARES = [
  {
    label: 'Share on X',
    icon: FaXTwitter,
    href: 'https://twitter.com/intent/tweet?text=Check%20out%20%40zuralog%20%E2%80%94%20the%20AI%20that%20unifies%20all%20your%20health%20data!%20https%3A%2F%2Fzuralog.com',
  },
  {
    label: 'Share on Instagram',
    icon: FaInstagram,
    href: 'https://instagram.com/zuralog',
  },
  {
    label: 'Share on LinkedIn',
    icon: FaLinkedinIn,
    href: 'https://www.linkedin.com/sharing/share-offsite/?url=https%3A%2F%2Fzuralog.com',
  },
  {
    label: 'Share on TikTok',
    icon: FaTiktok,
    href: 'https://www.tiktok.com/@zuralog',
  },
] as const;

// ── Support method cards ───────────────────────────────────────────────

/** Inline icon for "Share on Social Media" */
function ShareIcon() {
  return (
    <svg
      width="28"
      height="28"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.5"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <circle cx="18" cy="5" r="3" />
      <circle cx="6" cy="12" r="3" />
      <circle cx="18" cy="19" r="3" />
      <line x1="8.59" y1="13.51" x2="15.42" y2="17.49" />
      <line x1="15.41" y1="6.51" x2="8.59" y2="10.49" />
    </svg>
  );
}

/** Inline icon for "Join the Waitlist" */
function ReferIcon() {
  return (
    <svg
      width="28"
      height="28"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.5"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" />
      <circle cx="9" cy="7" r="4" />
      <line x1="19" y1="8" x2="19" y2="14" />
      <line x1="22" y1="11" x2="16" y2="11" />
    </svg>
  );
}

/** Inline icon for "Spread the Word" */
function MegaphoneIcon() {
  return (
    <svg
      width="28"
      height="28"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.5"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5" />
      <path d="M19.07 4.93a10 10 0 0 1 0 14.14M15.54 8.46a5 5 0 0 1 0 7.07" />
    </svg>
  );
}

/** Inline icon for "Become a Sponsor" */
function SponsorIcon() {
  return (
    <svg
      width="28"
      height="28"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.5"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <rect x="2" y="7" width="20" height="14" rx="2" ry="2" />
      <path d="M16 21V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16" />
    </svg>
  );
}

/** Arrow-right icon for CTA buttons */
function ArrowRightIcon() {
  return (
    <svg
      width="12"
      height="12"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d="M5 12h14M12 5l7 7-7 7" />
    </svg>
  );
}

interface SupportMethodCard {
  title: string;
  description: string;
  icon: React.ReactNode;
  cta: { label: string; href: string } | null;
  type: 'social' | 'link' | 'text';
}

const SUPPORT_METHODS: SupportMethodCard[] = [
  {
    title: 'Share on Social Media',
    description:
      'Tell your friends, followers, and community about ZuraLog. A single share can reach hundreds.',
    icon: <ShareIcon />,
    cta: null,
    type: 'social',
  },
  {
    title: 'Join the Waitlist & Refer Friends',
    description:
      'Sign up for early access and share your referral link. Each referral bumps you up the queue and helps us grow.',
    icon: <ReferIcon />,
    cta: { label: 'Join Waitlist', href: '/#waitlist' },
    type: 'link',
  },
  {
    title: 'Spread the Word',
    description:
      'Write a blog post, mention us in a podcast, tell your gym buddies, or drop a link in your Discord. Organic reach is priceless.',
    icon: <MegaphoneIcon />,
    cta: null,
    type: 'text',
  },
  {
    title: 'Become a Sponsor',
    description:
      "Companies and organizations can sponsor ZuraLog's development. Get your brand in front of our health-conscious community.",
    icon: <SponsorIcon />,
    cta: { label: 'Contact Us', href: '/contact' },
    type: 'link',
  },
];

// ── Component ──────────────────────────────────────────────────────────
export function SupportSection() {
  const [stats, setStats] = useState<SupportStats | null>(null);

  useEffect(() => {
    fetchSupportStats().then((s) => {
      if (s) setStats(s);
    });
  }, []);

  return (
    <section className="relative px-6 pb-24 pt-28 md:px-8 lg:px-12">
      <div className="mx-auto max-w-[960px]">

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

        {/* ── Hero ─────────────────────────────────────────────────── */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
          className="mb-16 text-center"
        >
          <span className="mb-4 inline-flex items-center gap-2 rounded-full border border-[#E8F5A8]/60 bg-[#E8F5A8]/20 px-3 py-1 text-[10px] font-semibold uppercase tracking-widest text-[#2D2D2D]/60">
            Support Us
          </span>
          <h1
            className="mb-4 mt-3 text-4xl font-bold tracking-tight sm:text-5xl"
            style={{ color: '#2D2D2D' }}
          >
            Help Us Build the Future
          </h1>
          <p className="mx-auto max-w-lg text-base leading-relaxed text-black/50">
            Every contribution — a coffee, a share, a referral — helps us build
            the future of unified health. Here are the ways you can help.
          </p>

          {/* Total Funds Raised */}
          <motion.div
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ duration: 0.5, delay: 0.3 }}
            className="mx-auto mt-8 inline-flex flex-col items-center rounded-2xl border border-black/[0.06] bg-white px-8 py-6 shadow-sm"
          >
            <p className="mb-1 text-[10px] font-semibold uppercase tracking-[0.2em] text-black/35">
              Total Funds Raised
            </p>
            {stats ? (
              <WaitlistCounter
                value={stats.totalFundsRaised}
                delay={0}
                sizeClass="text-4xl sm:text-5xl"
                prefix="$"
              />
            ) : (
              <div className="h-12 w-32 animate-pulse rounded-lg bg-black/5" />
            )}
            <p className="mt-2 text-xs text-black/30">
              from {stats?.totalSupporters ?? '—'} supporters
            </p>
            <p className="mt-1 text-[10px] italic text-black/25">
              Includes all contributions — not just Buy Me a Coffee
            </p>
          </motion.div>
        </motion.div>

        {/* ── Primary CTA: Buy Me a Coffee ─────────────────────────── */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.5 }}
          className="mb-12"
        >
          <a
            href="https://buymeacoffee.com/zuralog"
            target="_blank"
            rel="noopener noreferrer"
            className="group relative block overflow-hidden rounded-2xl border border-black/[0.06] bg-white p-8 shadow-sm transition-all hover:shadow-md"
          >
            {/* Gradient accent bar */}
            <div
              className="pointer-events-none absolute inset-x-0 top-0 h-1 opacity-60"
              style={{
                background: 'linear-gradient(90deg, #CFE1B9, #D4F291, #E8F5A8)',
              }}
            />

            <div className="flex flex-col items-center gap-4 sm:flex-row sm:items-start sm:gap-6">
              {/* Coffee icon */}
              <div
                className="flex h-16 w-16 shrink-0 items-center justify-center rounded-2xl"
                style={{ background: '#E8F5A8' }}
              >
                <svg
                  width="32"
                  height="32"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="#2D2D2D"
                  strokeWidth="1.5"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                >
                  <path d="M18 8h1a4 4 0 0 1 0 8h-1" />
                  <path d="M2 8h16v9a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4V8z" />
                  <line x1="6" y1="1" x2="6" y2="4" />
                  <line x1="10" y1="1" x2="10" y2="4" />
                  <line x1="14" y1="1" x2="14" y2="4" />
                </svg>
              </div>

              <div className="text-center sm:text-left">
                <h2 className="mb-2 text-xl font-bold text-[#2D2D2D]">
                  Buy Us a Coffee
                </h2>
                <p className="mb-4 text-sm leading-relaxed text-black/50">
                  The most direct way to support ZuraLog. Every coffee fuels late-night
                  coding sessions, server costs, and our mission to unify health data.
                  Pick any amount — $1, $5, $25 — it all adds up.
                </p>
                <span
                  className="inline-flex items-center gap-2 rounded-full px-5 py-2 text-sm font-semibold transition-opacity group-hover:opacity-90"
                  style={{ background: '#E8F5A8', color: '#2D2D2D' }}
                >
                  Support on Buy Me a Coffee
                  <svg
                    width="14"
                    height="14"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="2"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  >
                    <path d="M7 17L17 7M17 7H7M17 7v10" />
                  </svg>
                </span>
              </div>
            </div>
          </a>
        </motion.div>

        {/* ── Other ways to support ────────────────────────────────── */}
        <div className="mb-16">
          <h2 className="mb-8 text-center text-sm font-semibold uppercase tracking-[0.2em] text-black/30">
            Other Ways to Help
          </h2>

          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            {SUPPORT_METHODS.map((method, i) => (
              <motion.div
                key={method.title}
                initial={{ opacity: 0, y: 16 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ duration: 0.4, delay: i * 0.08 }}
                className="rounded-2xl border border-black/[0.06] bg-white p-6 shadow-sm"
              >
                <div className="mb-3 text-black/30">{method.icon}</div>
                <h3 className="mb-2 text-base font-semibold text-[#2D2D2D]">
                  {method.title}
                </h3>
                <p className="mb-4 text-sm leading-relaxed text-black/45">
                  {method.description}
                </p>

                {/* Social share icons */}
                {method.type === 'social' && (
                  <div className="flex items-center gap-2">
                    {SOCIAL_SHARES.map(({ label, icon: Icon, href }) => (
                      <a
                        key={label}
                        href={href}
                        target="_blank"
                        rel="noopener noreferrer"
                        aria-label={label}
                        className="flex h-9 w-9 items-center justify-center rounded-full border border-black/[0.08] bg-white text-black/40 transition-all hover:border-[#CFE1B9] hover:bg-[#CFE1B9]/20 hover:text-[#2D2D2D]"
                      >
                        <Icon className="h-3.5 w-3.5" />
                      </a>
                    ))}
                  </div>
                )}

                {/* CTA link */}
                {method.cta && (
                  <a
                    href={method.cta.href}
                    className="inline-flex items-center gap-1.5 rounded-full border border-black/[0.08] px-4 py-1.5 text-xs font-semibold text-black/50 transition-all hover:border-[#CFE1B9] hover:bg-[#CFE1B9]/10 hover:text-[#2D2D2D]"
                  >
                    {method.cta.label}
                    <ArrowRightIcon />
                  </a>
                )}
              </motion.div>
            ))}
          </div>
        </div>

        {/* ── Leaderboard ──────────────────────────────────────────── */}
        <SupportLeaderboard leaderboard={stats?.leaderboard ?? null} />

      </div>
    </section>
  );
}
