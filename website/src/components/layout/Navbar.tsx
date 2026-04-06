"use client";

/**
 * Navbar — premium frosted-cream navigation for the ZuraLog marketing site.
 *
 * Light mode design:
 *   - Transparent at top, frosted cream glassmorphism on scroll.
 *   - Deep Forest text with sage accents.
 *   - Sage pattern-filled CTA button.
 *   - Subtle sound effects on interactions.
 */

import { useEffect, useState, useCallback, useRef } from "react";
import { usePathname, useRouter } from "next/navigation";
import { motion, AnimatePresence } from "framer-motion";
import Link from "next/link";
import { playTick, playClick, playWhoosh } from "@/lib/sounds";

const SCROLL_LINKS = [
  { label: "How It Works", id: "mobile-section" },
  { label: "Features", id: "bento-section" },
] as const;

const PAGE_LINKS = [
  { label: "About", href: "/about" },
  { label: "Contact", href: "/contact" },
  { label: "Support Us", href: "/support" },
] as const;

const EXPO_OUT = [0.16, 1, 0.3, 1] as const;

export function Navbar() {
  const [scrolled, setScrolled] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const pathname = usePathname();
  const router = useRouter();
  const hasInteracted = useRef(false);

  useEffect(() => {
    const handler = () => setScrolled(window.scrollY > 40);
    handler();
    window.addEventListener("scroll", handler, { passive: true });
    return () => window.removeEventListener("scroll", handler);
  }, []);

  useEffect(() => {
    const unlock = () => { hasInteracted.current = true; };
    window.addEventListener("click", unlock, { once: true });
    window.addEventListener("touchstart", unlock, { once: true });
    return () => {
      window.removeEventListener("click", unlock);
      window.removeEventListener("touchstart", unlock);
    };
  }, []);

  const handleNav = useCallback(
    (id: string) => {
      setMenuOpen(false);
      if (pathname !== "/") { router.push(`/#${id}`); return; }
      document.getElementById(id)?.scrollIntoView({ behavior: "smooth" });
    },
    [pathname, router]
  );

  const handleLinkHover = () => { if (hasInteracted.current) playTick(); };
  const handleCtaClick = (id: string) => { if (hasInteracted.current) playClick(); handleNav(id); };
  const handleMenuToggle = () => { if (hasInteracted.current) playWhoosh(); setMenuOpen((o) => !o); };

  return (
    <motion.header
      initial={{ opacity: 0, y: -6 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.4, ease: EXPO_OUT }}
      className="fixed inset-x-0 top-0 z-50"
    >
      <div
        className="transition-all duration-500"
        style={{
          background: scrolled ? "rgba(250, 250, 245, 0.80)" : "transparent",
          backdropFilter: scrolled ? "blur(20px)" : "none",
          WebkitBackdropFilter: scrolled ? "blur(20px)" : "none",
          borderBottom: scrolled
            ? "1px solid rgba(52, 78, 65, 0.06)"
            : "1px solid transparent",
        }}
      >
        <div
          className="mx-auto flex h-12 items-center justify-between"
          style={{ maxWidth: "1280px", padding: "0 clamp(1rem, 3vw, 2.5rem)" }}
        >
          {/* Logo */}
          <Link
            href="/"
            className="flex items-center gap-2 transition-opacity duration-300 hover:opacity-80"
            aria-label="ZuraLog home"
            onMouseEnter={handleLinkHover}
          >
            <img src="/logo/ZuraLog-Forest-Green.svg" alt="ZuraLog" width={22} height={22} className="object-contain" />
            <span className="font-semibold tracking-tight" style={{ color: "#344E41", fontSize: "13px" }}>
              ZuraLog
            </span>
          </Link>

          {/* Desktop nav links */}
          <nav className="hidden items-center gap-7 md:flex" aria-label="Main navigation">
            {SCROLL_LINKS.map(({ label, id }) => (
              <button
                key={id}
                onClick={() => { handleLinkHover(); handleNav(id); }}
                onMouseEnter={handleLinkHover}
                className="nav-link-underline text-xs font-medium transition-colors duration-300"
                style={{ color: "var(--text-secondary)" }}
                onMouseOver={(e) => { e.currentTarget.style.color = "#344E41"; }}
                onMouseOut={(e) => { e.currentTarget.style.color = "var(--text-secondary)"; }}
              >
                {label}
              </button>
            ))}
            {PAGE_LINKS.map(({ label, href }) => (
              <Link
                key={href}
                href={href}
                onMouseEnter={handleLinkHover}
                className="nav-link-underline text-xs font-medium transition-colors duration-300"
                style={{ color: "var(--text-secondary)" }}
                onMouseOver={(e) => { e.currentTarget.style.color = "#344E41"; }}
                onMouseOut={(e) => { e.currentTarget.style.color = "var(--text-secondary)"; }}
              >
                {label}
              </Link>
            ))}
          </nav>

          {/* Right: CTA + hamburger */}
          <div className="flex items-center gap-3">
            <button
              onClick={() => handleCtaClick("waitlist")}
              className="btn-pattern-light hidden md:inline-flex items-center justify-center rounded-full text-xs font-semibold animate-sage-glow transition-all duration-300 hover:scale-[1.03] active:scale-[0.97]"
              style={{
                background: "#CFE1B9",
                color: "#141E18",
                padding: "7px 18px",
                boxShadow: "0 2px 12px rgba(207, 225, 185, 0.4)",
              }}
            >
              <span className="relative z-2">Join Waitlist</span>
            </button>

            <button
              className="flex flex-col gap-[4px] p-1.5 md:hidden"
              onClick={handleMenuToggle}
              aria-label={menuOpen ? "Close menu" : "Open menu"}
              aria-expanded={menuOpen}
            >
              {[0, 1, 2].map((i) => (
                <span
                  key={i}
                  className="block h-px w-4 transition-all duration-300"
                  style={{
                    backgroundColor: "var(--text-primary)",
                    ...(i === 0 && menuOpen ? { transform: "translateY(5px) rotate(45deg)" } : {}),
                    ...(i === 1 ? { opacity: menuOpen ? 0 : 1 } : {}),
                    ...(i === 2 && menuOpen ? { transform: "translateY(-7px) rotate(-45deg)" } : {}),
                  }}
                />
              ))}
            </button>
          </div>
        </div>
      </div>

      {/* Mobile dropdown — frosted cream */}
      <AnimatePresence>
        {menuOpen && (
          <motion.div
            key="mobile-menu"
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: "auto" }}
            exit={{ opacity: 0, height: 0 }}
            transition={{ duration: 0.3, ease: EXPO_OUT }}
            className="overflow-hidden md:hidden"
            style={{
              backgroundColor: "rgba(250, 250, 245, 0.96)",
              backdropFilter: "blur(20px)",
              WebkitBackdropFilter: "blur(20px)",
              borderBottom: "1px solid rgba(52, 78, 65, 0.06)",
            }}
          >
            <nav className="flex flex-col gap-0.5 px-4 py-4" aria-label="Mobile navigation">
              {SCROLL_LINKS.map(({ label, id }, i) => (
                <motion.button
                  key={id}
                  initial={{ opacity: 0, x: -12 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ delay: i * 0.06, duration: 0.35, ease: EXPO_OUT }}
                  onClick={() => { handleLinkHover(); handleNav(id); }}
                  className="rounded-lg px-3 py-2.5 text-left text-xs font-medium transition-colors duration-200 hover:bg-black/5"
                  style={{ color: "var(--text-primary)" }}
                >
                  {label}
                </motion.button>
              ))}
              {PAGE_LINKS.map(({ label, href }, i) => (
                <motion.div
                  key={href}
                  initial={{ opacity: 0, x: -12 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ delay: (SCROLL_LINKS.length + i) * 0.06, duration: 0.35, ease: EXPO_OUT }}
                >
                  <Link
                    href={href}
                    onClick={() => { handleLinkHover(); setMenuOpen(false); }}
                    className="block rounded-lg px-3 py-2.5 text-left text-xs font-medium transition-colors duration-200 hover:bg-black/5"
                    style={{ color: "var(--text-primary)" }}
                  >
                    {label}
                  </Link>
                </motion.div>
              ))}
              <motion.button
                initial={{ opacity: 0, y: 8 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: (SCROLL_LINKS.length + PAGE_LINKS.length) * 0.06 + 0.05, duration: 0.4, ease: EXPO_OUT }}
                onClick={() => handleCtaClick("waitlist")}
                className="btn-pattern-light mt-2 w-full rounded-full px-4 py-2.5 text-xs font-semibold transition-all duration-300 hover:scale-[1.02] active:scale-[0.98]"
                style={{ background: "#CFE1B9", color: "#141E18" }}
              >
                <span className="relative z-2">Join Waitlist</span>
              </motion.button>
            </nav>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.header>
  );
}
