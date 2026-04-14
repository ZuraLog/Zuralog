/**
 * Footer — premium light-mode footer for ZuraLog marketing site.
 *
 * Cream background with sage accents, topographic pattern texture,
 * matching the overall light aesthetic of the site.
 */

"use client";

import Link from "next/link";
import {
  FaXTwitter,
  FaInstagram,
  FaLinkedinIn,
  FaTiktok,
  FaAppStoreIos,
  FaGooglePlay,
} from "react-icons/fa6";
import { ManageCookiesButton } from "@/components/ui/ManageCookiesButton";
import { useSoundContext } from "@/components/design-system/interactions/sound-provider";

const NAV_COLUMNS = [
  {
    heading: "Features",
    links: [
      { label: "Today",    href: "/#today-section" },
      { label: "Data",     href: "/#data-section" },
      { label: "Coach",    href: "/#coach-section" },
      { label: "Progress", href: "/#progress-section" },
      { label: "Trends",   href: "/#trends-section" },
      { label: "Pricing",  href: "/pricing" },
    ],
  },
  {
    heading: "Legal",
    links: [
      { label: "Privacy Policy",       href: "/privacy-policy" },
      { label: "Terms of Service",     href: "/terms-of-service" },
      { label: "Cookie Policy",        href: "/cookie-policy" },
      { label: "Community Guidelines", href: "/community-guidelines" },
    ],
  },
  {
    heading: "Company",
    links: [
      { label: "About Us",   href: "/about" },
      { label: "Contact",    href: "/contact" },
      { label: "Support Us", href: "/support" },
    ],
  },
];

const SOCIAL_LINKS = [
  { label: "X (Twitter)", href: "https://twitter.com/zuralog", icon: FaXTwitter },
  { label: "Instagram", href: "https://instagram.com/zuralog", icon: FaInstagram },
  { label: "LinkedIn", href: "https://www.linkedin.com/company/112446156/", icon: FaLinkedinIn },
  { label: "TikTok", href: "https://www.tiktok.com/@zuralog", icon: FaTiktok },
];

export function Footer() {
  const currentYear = new Date().getFullYear();
  const { playSound } = useSoundContext();

  const handleHover = () => playSound("tick");
  const handleClick = () => playSound("click");

  return (
    <footer
      aria-label="Site footer"
      className="relative font-jakarta"
      style={{ backgroundColor: "#F0EEE9" }}
    >
      {/* Top accent line */}
      <div
        aria-hidden="true"
        className="absolute inset-x-0 top-0 h-px"
        style={{
          background: "linear-gradient(to right, transparent 0%, rgba(52,78,65,0.08) 15%, rgba(207,225,185,0.5) 40%, rgba(207,225,185,0.5) 60%, rgba(52,78,65,0.08) 85%, transparent 100%)",
        }}
      />

      {/* Subtle topo pattern */}
      <div
        aria-hidden="true"
        className="absolute inset-0 pointer-events-none"
        style={{
          backgroundImage: "url(/pattern-sm.jpg)",
          backgroundSize: "400px auto",
          backgroundRepeat: "repeat",
          opacity: 0.025,
        }}
      />

      <div className="relative mx-auto max-w-[1280px] px-6 md:px-8 lg:px-12">
        {/* Top grid */}
        <div className="grid grid-cols-1 gap-12 py-16 sm:grid-cols-2 lg:grid-cols-[2fr_1fr_1fr_1fr]">
          {/* Brand column */}
          <div className="flex flex-col gap-5">
            <Link
              href="/"
              className="inline-flex items-center gap-2 transition-opacity duration-300 hover:opacity-80"
              aria-label="ZuraLog home"
              onMouseEnter={handleHover}
            >
              <img src="/logo/ZuraLog-Forest-Green.svg" alt="ZuraLog logo" width={28} height={28} className="object-contain" />
              <span className="text-sm font-semibold tracking-tight" style={{ color: "#344E41" }}>
                ZuraLog
              </span>
            </Link>

            <p className="text-xs font-semibold uppercase tracking-[0.22em]" style={{ color: "#1A2E22" }}>
              Unified Health. Made Smart.
            </p>

            <p className="max-w-xs text-sm leading-relaxed" style={{ color: "rgba(52, 78, 65, 0.50)" }}>
              The AI that connects your fitness apps and actually thinks — so
              your health data finally works for you.
            </p>

            {/* App store badges */}
            <div className="flex flex-col gap-2 pt-1">
              <div
                aria-label="App Store — coming soon"
                title="Coming soon"
                className="inline-flex w-fit cursor-not-allowed select-none items-center gap-2.5 rounded-xl px-3.5 py-2.5 opacity-50"
                style={{ backgroundColor: "rgba(52, 78, 65, 0.04)", border: "1px solid rgba(52, 78, 65, 0.08)" }}
              >
                <FaAppStoreIos className="h-4 w-4 shrink-0 text-[#344E41]" />
                <div className="leading-none">
                  <div className="text-[8px] font-medium uppercase tracking-widest" style={{ color: "rgba(52, 78, 65, 0.40)" }}>Download on the</div>
                  <div className="text-[12px] font-semibold" style={{ color: "#1A2E22" }}>App Store</div>
                </div>
                <span className="ml-1 text-[10px]" style={{ color: "rgba(52, 78, 65, 0.25)" }}>Soon</span>
              </div>

              <div
                aria-label="Google Play — coming soon"
                title="Coming soon"
                className="inline-flex w-fit cursor-not-allowed select-none items-center gap-2.5 rounded-xl px-3.5 py-2.5 opacity-50"
                style={{ backgroundColor: "rgba(52, 78, 65, 0.04)", border: "1px solid rgba(52, 78, 65, 0.08)" }}
              >
                <FaGooglePlay className="h-3.5 w-3.5 shrink-0 text-[#344E41]" />
                <div className="leading-none">
                  <div className="text-[8px] font-medium uppercase tracking-widest" style={{ color: "rgba(52, 78, 65, 0.40)" }}>Get it on</div>
                  <div className="text-[12px] font-semibold" style={{ color: "#1A2E22" }}>Google Play</div>
                </div>
                <span className="ml-1 text-[10px]" style={{ color: "rgba(52, 78, 65, 0.25)" }}>Soon</span>
              </div>
            </div>

            {/* Support email */}
            <a
              href="mailto:support@zuralog.com"
              onMouseEnter={handleHover}
              className="inline-flex items-center gap-1.5 text-xs font-medium transition-colors duration-300"
              style={{ color: "rgba(52, 78, 65, 0.40)" }}
              onMouseOver={(e) => { e.currentTarget.style.color = "#344E41"; }}
              onMouseOut={(e) => { e.currentTarget.style.color = "rgba(52, 78, 65, 0.40)"; }}
            >
              <svg aria-hidden="true" viewBox="0 0 16 16" fill="none" className="h-3.5 w-3.5 shrink-0" stroke="currentColor" strokeWidth="1.5">
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
                  onMouseEnter={handleHover}
                  onClick={handleClick}
                  className="flex h-8 w-8 items-center justify-center rounded-full transition-all duration-300 hover:border-[#344E41]/30 hover:bg-[#344E41]/8 hover:text-[#344E41]"
                  style={{
                    border: "1px solid rgba(52, 78, 65, 0.10)",
                    backgroundColor: "rgba(52, 78, 65, 0.03)",
                    color: "rgba(52, 78, 65, 0.40)",
                  }}
                >
                  <Icon className="h-3.5 w-3.5" />
                </a>
              ))}
            </div>
          </div>

          {/* Nav columns */}
          {NAV_COLUMNS.map((col) => (
            <div key={col.heading} className="flex flex-col gap-4">
              <h3 className="text-[10px] font-semibold uppercase tracking-[0.22em]" style={{ color: "rgba(52, 78, 65, 0.35)" }}>
                {col.heading}
              </h3>
              <ul className="flex flex-col gap-3">
                {col.links.map(({ label, href }) => (
                  <li key={label}>
                    <Link
                      href={href}
                      onMouseEnter={handleHover}
                      className="text-sm font-medium transition-colors duration-300"
                      style={{ color: "rgba(52, 78, 65, 0.50)" }}
                      onMouseOver={(e) => { e.currentTarget.style.color = "#344E41"; }}
                      onMouseOut={(e) => { e.currentTarget.style.color = "rgba(52, 78, 65, 0.50)"; }}
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
        <div className="h-px" style={{ backgroundColor: "rgba(52, 78, 65, 0.06)" }} />

        {/* Bottom bar */}
        <div className="flex flex-col items-center justify-between gap-4 py-6 sm:flex-row">
          <p className="text-xs" style={{ color: "rgba(52, 78, 65, 0.30)" }}>
            &copy; {currentYear} ZuraLog. All rights reserved.
          </p>

          <nav aria-label="Legal navigation" className="flex flex-wrap items-center gap-x-3 gap-y-1 sm:gap-x-5">
            {[
              { label: "Privacy Policy", href: "/privacy-policy" },
              { label: "Terms of Service", href: "/terms-of-service" },
              { label: "Cookie Policy", href: "/cookie-policy" },
              { label: "Community Guidelines", href: "/community-guidelines" },
            ].map(({ label, href }, i, arr) => (
              <span key={label} className="inline-flex items-center gap-x-3 sm:gap-x-5">
                <Link
                  href={href}
                  onMouseEnter={handleHover}
                  className="text-xs font-medium transition-colors duration-300"
                  style={{ color: "rgba(52, 78, 65, 0.30)" }}
                  onMouseOver={(e) => { e.currentTarget.style.color = "#344E41"; }}
                  onMouseOut={(e) => { e.currentTarget.style.color = "rgba(52, 78, 65, 0.30)"; }}
                >
                  {label}
                </Link>
                {i < arr.length - 1 && (
                  <span aria-hidden="true" style={{ color: "rgba(52, 78, 65, 0.15)" }}>·</span>
                )}
              </span>
            ))}
            <span aria-hidden="true" style={{ color: "rgba(52, 78, 65, 0.15)" }}>·</span>
            <ManageCookiesButton />
          </nav>
        </div>
      </div>
    </footer>
  );
}
