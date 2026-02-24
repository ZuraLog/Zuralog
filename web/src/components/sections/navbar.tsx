/**
 * Navbar — always-visible top navigation for the Zuralog landing page.
 *
 * Design: Light-theme bar that is visible from page load on the cream hero.
 * Two visual states:
 *   - Transparent: fully transparent background at top of page.
 *   - Frosted: cream glassmorphism with backdrop-blur when scrolled > 60px.
 *
 * No theme toggle — the site uses explicit section backgrounds, not theme switching.
 */
'use client';

import { useEffect, useState, useCallback } from 'react';
import { motion } from 'framer-motion';
import Image from 'next/image';
import { Button } from '@/components/ui/button';

/** Nav link definitions */
const NAV_LINKS = [
  { label: 'Features', id: 'features' },
  { label: 'How It Works', id: 'how-it-works' },
  { label: 'Community', id: 'waitlist' },
] as const;

/**
 * Always-visible sticky navbar that transitions between transparent and frosted
 * cream glass states based on scroll position.
 */
export function Navbar() {
  const [scrolled, setScrolled] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);

  /** Track whether the user has scrolled past the threshold. */
  useEffect(() => {
    const handler = () => setScrolled(window.scrollY > 60);
    // Run once on mount to set initial state (e.g. if page loads mid-scroll).
    handler();
    window.addEventListener('scroll', handler, { passive: true });
    return () => window.removeEventListener('scroll', handler);
  }, []);

  /**
   * Smoothly scrolls to a section by ID and closes the mobile menu.
   * @param id - The element ID to scroll to.
   */
  const handleNav = useCallback((id: string) => {
    setMenuOpen(false);
    document.getElementById(id)?.scrollIntoView({ behavior: 'smooth' });
  }, []);

  return (
    /* Mount animation: fade in + slide down from -8px */
    <motion.header
      initial={{ opacity: 0, y: -8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.4, ease: 'easeOut' }}
      className="fixed inset-x-0 top-0 z-50"
    >
      {/* ── Main bar ── */}
      <div
        className="transition-all duration-300"
        style={{
          background: scrolled ? 'rgba(250, 250, 245, 0.85)' : 'transparent',
          backdropFilter: scrolled ? 'blur(24px)' : 'none',
          WebkitBackdropFilter: scrolled ? 'blur(24px)' : 'none',
          borderBottom: scrolled ? '1px solid var(--border-light)' : '1px solid transparent',
        }}
      >
        <div
          className="mx-auto flex h-16 items-center justify-between"
          style={{ maxWidth: '1280px', padding: '0 clamp(1.5rem, 4vw, 3rem)' }}
        >
          {/* ── Logo (left) ── */}
          <button
            onClick={() => window.scrollTo({ top: 0, behavior: 'smooth' })}
            className="flex items-center gap-2.5 transition-opacity hover:opacity-70"
            aria-label="Back to top"
          >
            <Image
              src="/logo.png"
              alt="Zuralog"
              width={32}
              height={32}
              className="object-contain"
              priority
            />
            <span
              className="font-semibold"
              style={{
                color: 'var(--text-primary)',
                fontFamily: 'Satoshi, sans-serif',
                fontSize: '15px',
              }}
            >
              Zuralog
            </span>
          </button>

          {/* ── Desktop nav links (center) ── */}
          <nav className="hidden items-center gap-8 md:flex" aria-label="Main navigation">
            {NAV_LINKS.map(({ label, id }) => (
              <button
                key={id}
                onClick={() => handleNav(id)}
                className="transition-colors duration-200"
                style={{
                  color: 'var(--text-secondary)',
                  fontFamily: 'Inter, sans-serif',
                  fontSize: '14px',
                  fontWeight: 500,
                }}
                onMouseEnter={(e) => {
                  (e.currentTarget as HTMLButtonElement).style.color = 'var(--text-primary)';
                }}
                onMouseLeave={(e) => {
                  (e.currentTarget as HTMLButtonElement).style.color = 'var(--text-secondary)';
                }}
              >
                {label}
              </button>
            ))}
          </nav>

          {/* ── Right zone: CTA + hamburger ── */}
          <div className="flex items-center gap-3">
            {/* Desktop CTA */}
            <Button
              variant="pill"
              size="pill-sm"
              className="hidden animate-pulse-glow md:inline-flex"
              style={{ animationDelay: '2000ms' }}
              onClick={() => handleNav('waitlist')}
            >
              Join Waitlist
            </Button>

            {/* Mobile hamburger */}
            <button
              className="flex flex-col gap-[5px] p-1 md:hidden"
              onClick={() => setMenuOpen((open) => !open)}
              aria-label={menuOpen ? 'Close menu' : 'Open menu'}
              aria-expanded={menuOpen}
            >
              <span
                className="block h-px w-5 transition-transform duration-200"
                style={{
                  backgroundColor: 'var(--text-primary)',
                  transform: menuOpen ? 'translateY(6px) rotate(45deg)' : 'none',
                }}
              />
              <span
                className="block h-px w-5 transition-opacity duration-200"
                style={{
                  backgroundColor: 'var(--text-primary)',
                  opacity: menuOpen ? 0 : 1,
                }}
              />
              <span
                className="block h-px w-5 transition-transform duration-200"
                style={{
                  backgroundColor: 'var(--text-primary)',
                  transform: menuOpen ? 'translateY(-8px) rotate(-45deg)' : 'none',
                }}
              />
            </button>
          </div>
        </div>
      </div>

      {/* ── Mobile menu panel ── */}
      {menuOpen && (
        <motion.div
          initial={{ opacity: 0, height: 0 }}
          animate={{ opacity: 1, height: 'auto' }}
          exit={{ opacity: 0, height: 0 }}
          transition={{ duration: 0.2, ease: 'easeOut' }}
          className="overflow-hidden border-b backdrop-blur-xl md:hidden"
          style={{
            backgroundColor: 'rgba(250, 250, 245, 0.95)',
            borderColor: 'var(--border-light)',
          }}
        >
          <nav
            className="flex flex-col gap-1 p-4"
            aria-label="Mobile navigation"
          >
            {NAV_LINKS.map(({ label, id }) => (
              <button
                key={id}
                onClick={() => handleNav(id)}
                className="rounded-xl px-4 py-3 text-left text-sm font-medium transition-colors duration-150 hover:bg-black/5"
                style={{ color: 'var(--text-primary)' }}
              >
                {label}
              </button>
            ))}

            {/* Mobile CTA */}
            <Button
              variant="pill"
              size="pill-sm"
              className="mt-2 w-full animate-pulse-glow"
              style={{ animationDelay: '2000ms' }}
              onClick={() => handleNav('waitlist')}
            >
              Join Waitlist
            </Button>
          </nav>
        </motion.div>
      )}
    </motion.header>
  );
}
