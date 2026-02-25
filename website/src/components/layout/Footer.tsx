/**
 * Footer — site-wide footer for ZuraLog marketing site.
 *
 * Responsibilities:
 *   - Brand identity: logo, tagline, tagline descriptor
 *   - App store badges (coming soon — locked state)
 *   - Navigation columns: Product, Legal, Company
 *   - Social media links (Twitter/X, Instagram, LinkedIn, Facebook)
 *   - Support contact email
 *   - Copyright notice + Manage cookies link
 *
 * Design tokens: cream background (#FAFAF5), sage/lime accent line,
 * same Geist Sans typography and spacing language as the rest of the site.
 */

import Image from 'next/image';
import Link from 'next/link';
import { FaXTwitter, FaInstagram, FaLinkedinIn, FaFacebookF, FaAppStoreIos, FaGooglePlay } from 'react-icons/fa6';
import { ManageCookiesButton } from '@/components/ui/ManageCookiesButton';

// ---------------------------------------------------------------------------
// Data
// ---------------------------------------------------------------------------

const NAV_COLUMNS = [
  {
    heading: 'Product',
    links: [
      { label: 'Features', href: '/#features' },
      { label: 'How It Works', href: '/#how-it-works' },
      { label: 'Join Waitlist', href: '/#waitlist' },
    ],
  },
  {
    heading: 'Legal',
    links: [
      { label: 'Privacy Policy', href: '/privacy-policy' },
      { label: 'Terms of Service', href: '/terms-of-service' },
      { label: 'Cookie Policy', href: '/cookie-policy' },
      { label: 'Community Guidelines', href: '/community-guidelines' },
    ],
  },
  {
    heading: 'Company',
    links: [
      { label: 'About Us', href: '/about' },
      { label: 'Contact', href: '/contact' },
    ],
  },
];

const SOCIAL_LINKS = [
  {
    label: 'X (Twitter)',
    href: 'https://twitter.com/zuralog',
    icon: FaXTwitter,
  },
  {
    label: 'Instagram',
    href: 'https://instagram.com/zuralog',
    icon: FaInstagram,
  },
  {
    label: 'LinkedIn',
    href: 'https://www.linkedin.com/company/112446156/',
    icon: FaLinkedinIn,
  },
  {
    label: 'Facebook',
    href: 'https://facebook.com/zuralog',
    icon: FaFacebookF,
  },
];

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

/**
 * Site footer with brand identity, navigation, social links, app store badges,
 * and legal copy.
 *
 * @returns Full-width `<footer>` element.
 */
export function Footer() {
  const currentYear = new Date().getFullYear();

  return (
    <footer
      aria-label="Site footer"
      className="relative border-t border-black/[0.06] bg-[#FAFAF5]"
    >
      {/* ── Sage-to-lime gradient accent line ─────────────────────────────── */}
      <div
        aria-hidden="true"
        className="absolute inset-x-0 top-0 h-px"
        style={{
          background:
            'linear-gradient(to right, transparent 0%, #CFE1B9 20%, #D4F291 50%, #E8F5A8 80%, transparent 100%)',
        }}
      />

      {/* ── Main content ──────────────────────────────────────────────────── */}
      <div className="mx-auto max-w-[1280px] px-6 lg:px-12">

        {/* Top grid: brand + nav columns */}
        <div className="grid grid-cols-1 gap-12 py-16 sm:grid-cols-2 lg:grid-cols-[2fr_1fr_1fr_1fr]">

          {/* Brand column */}
          <div className="flex flex-col gap-5">
            {/* Logo + wordmark */}
            <Link
              href="/"
              className="inline-flex items-center gap-2 transition-opacity hover:opacity-80"
              aria-label="ZuraLog home"
            >
              <Image
                src="/logo/Zuralog.png"
                alt="ZuraLog logo"
                width={28}
                height={28}
                className="rounded-lg object-contain"
              />
              <span
                className="text-sm font-semibold tracking-tight"
                style={{ color: 'var(--color-sage)' }}
              >
                ZuraLog
              </span>
            </Link>

            {/* Tagline */}
            <p
              className="text-xs font-semibold uppercase tracking-[0.22em]"
              style={{ color: '#2D2D2D' }}
            >
              Unified Health. Made Smart.
            </p>

            {/* Short descriptor */}
            <p className="max-w-xs text-sm leading-relaxed text-black/45">
              The AI that connects your fitness apps and actually thinks — so
              your health data finally works for you.
            </p>

            {/* App store badges — locked / coming soon */}
            <div className="flex flex-col gap-2 pt-1">
              {/* App Store */}
              <div
                aria-label="App Store — coming soon"
                title="Coming soon"
                className="inline-flex w-fit cursor-not-allowed select-none items-center gap-2.5 rounded-xl border border-black/[0.08] bg-white/60 px-3.5 py-2.5 opacity-50"
              >
                <FaAppStoreIos className="h-4 w-4 shrink-0 text-[#2D2D2D]" />
                <div className="leading-none">
                  <div className="text-[8px] font-medium uppercase tracking-widest text-black/40">
                    Download on the
                  </div>
                  <div className="text-[12px] font-semibold text-[#1A1A1A]">App Store</div>
                </div>
                <span className="ml-1 text-[10px] text-black/25">Soon</span>
              </div>

              {/* Google Play */}
              <div
                aria-label="Google Play — coming soon"
                title="Coming soon"
                className="inline-flex w-fit cursor-not-allowed select-none items-center gap-2.5 rounded-xl border border-black/[0.08] bg-white/60 px-3.5 py-2.5 opacity-50"
              >
                <FaGooglePlay className="h-3.5 w-3.5 shrink-0 text-[#2D2D2D]" />
                <div className="leading-none">
                  <div className="text-[8px] font-medium uppercase tracking-widest text-black/40">
                    Get it on
                  </div>
                  <div className="text-[12px] font-semibold text-[#1A1A1A]">Google Play</div>
                </div>
                <span className="ml-1 text-[10px] text-black/25">Soon</span>
              </div>
            </div>

            {/* Support email */}
            <a
              href="mailto:support@zuralog.com"
              className="inline-flex items-center gap-1.5 text-xs font-medium text-black/40 transition-colors hover:text-[#2D2D2D]"
            >
              <svg
                aria-hidden="true"
                viewBox="0 0 16 16"
                fill="none"
                className="h-3.5 w-3.5 shrink-0"
                stroke="currentColor"
                strokeWidth="1.5"
              >
                <path d="M2 4l6 5 6-5M2 4h12v8H2V4z" strokeLinejoin="round" />
              </svg>
              support@zuralog.com
            </a>

            {/* Social icons */}
            <div className="flex items-center gap-3">
              {SOCIAL_LINKS.map(({ label, href, icon: Icon }) => (
                <a
                  key={label}
                  href={href}
                  target="_blank"
                  rel="noopener noreferrer"
                  aria-label={label}
                  className="flex h-8 w-8 items-center justify-center rounded-full border border-black/[0.08] bg-white/60 text-black/40 transition-all hover:border-[#CFE1B9] hover:bg-[#CFE1B9]/20 hover:text-[#2D2D2D]"
                >
                  <Icon className="h-3.5 w-3.5" />
                </a>
              ))}
            </div>
          </div>

          {/* Nav columns */}
          {NAV_COLUMNS.map((col) => (
            <div key={col.heading} className="flex flex-col gap-4">
              <h3 className="text-[10px] font-semibold uppercase tracking-[0.22em] text-black/30">
                {col.heading}
              </h3>
              <ul className="flex flex-col gap-3">
                {col.links.map(({ label, href }) => (
                  <li key={label}>
                    <Link
                      href={href}
                      className="text-sm font-medium text-black/50 transition-colors hover:text-[#2D2D2D]"
                    >
                      {label}
                    </Link>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>

        {/* Divider */}
        <div className="h-px bg-black/[0.06]" />

        {/* Bottom bar: copyright + legal links + manage cookies */}
        <div className="flex flex-col items-center justify-between gap-4 py-6 sm:flex-row">
          <p className="text-xs text-black/30">
            &copy; {currentYear} ZuraLog. All rights reserved.
          </p>

          {/* Inline legal links + manage cookies */}
          <nav aria-label="Legal navigation" className="flex flex-wrap items-center gap-x-5 gap-y-1">
            <Link
              href="/privacy-policy"
              className="text-xs font-medium text-black/30 transition-colors hover:text-[#2D2D2D]"
            >
              Privacy Policy
            </Link>
            <span aria-hidden="true" className="text-black/20">·</span>
            <Link
              href="/terms-of-service"
              className="text-xs font-medium text-black/30 transition-colors hover:text-[#2D2D2D]"
            >
              Terms of Service
            </Link>
            <span aria-hidden="true" className="text-black/20">·</span>
            <Link
              href="/cookie-policy"
              className="text-xs font-medium text-black/30 transition-colors hover:text-[#2D2D2D]"
            >
              Cookie Policy
            </Link>
            <span aria-hidden="true" className="text-black/20">·</span>
            <Link
              href="/community-guidelines"
              className="text-xs font-medium text-black/30 transition-colors hover:text-[#2D2D2D]"
            >
              Community Guidelines
            </Link>
            <span aria-hidden="true" className="text-black/20">·</span>
            {/* Manage cookies — client component (onClick handler) */}
            <ManageCookiesButton />
          </nav>
        </div>

      </div>
    </footer>
  );
}
