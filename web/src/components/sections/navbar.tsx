/**
 * Navbar — sticky top navigation for the ZuraLog landing page.
 *
 * Design: Minimal glassmorphism bar that appears after scrolling 80px.
 * Contains logo image, nav links, a light/dark toggle, and a CTA button.
 */
'use client';

import { useEffect, useState, useCallback } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { useTheme } from 'next-themes';
import Image from 'next/image';
import { Button } from '@/components/ui/button';

/**
 * Smoothly scrolls to the waitlist signup section.
 */
function scrollToSignup() {
  document.getElementById('waitlist')?.scrollIntoView({ behavior: 'smooth' });
}

/**
 * Sun/Moon icon toggle for light/dark mode.
 */
function ThemeToggle() {
  const { theme, setTheme } = useTheme();
  const [mounted, setMounted] = useState(false);

  useEffect(() => setMounted(true), []);
  if (!mounted) return <div className="h-8 w-8" />;

  const isDark = theme === 'dark';
  return (
    <button
      onClick={() => setTheme(isDark ? 'light' : 'dark')}
      aria-label="Toggle theme"
      className="flex h-8 w-8 items-center justify-center rounded-full text-muted-foreground transition-colors hover:bg-white/10 hover:text-foreground"
    >
      {isDark ? (
        /* Sun */
        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <circle cx="12" cy="12" r="4"/>
          <path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M6.34 17.66l-1.41 1.41M19.07 4.93l-1.41 1.41"/>
        </svg>
      ) : (
        /* Moon */
        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z"/>
        </svg>
      )}
    </button>
  );
}

/**
 * Sticky glassmorphism navbar that fades in on scroll.
 */
export function Navbar() {
  const [visible, setVisible] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);

  useEffect(() => {
    const handler = () => setVisible(window.scrollY > 80);
    window.addEventListener('scroll', handler, { passive: true });
    return () => window.removeEventListener('scroll', handler);
  }, []);

  const handleNav = useCallback((id: string) => {
    setMenuOpen(false);
    document.getElementById(id)?.scrollIntoView({ behavior: 'smooth' });
  }, []);

  return (
    <AnimatePresence>
      {visible && (
        <motion.header
          initial={{ opacity: 0, y: -16 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: -16 }}
          transition={{ duration: 0.3, ease: 'easeOut' }}
          className="fixed inset-x-0 top-0 z-50"
        >
          <div className="mx-auto flex max-w-6xl items-center justify-between px-6 py-4">
            {/* Glass pill container */}
            <div className="flex w-full items-center justify-between rounded-2xl border border-white/8 bg-black/60 px-5 py-3 backdrop-blur-xl dark:bg-black/60 light:bg-white/70">
              {/* Logo */}
              <button
                onClick={() => window.scrollTo({ top: 0, behavior: 'smooth' })}
                className="flex items-center transition-opacity hover:opacity-70"
                aria-label="Back to top"
              >
                <Image
                  src="/logo.png"
                  alt="ZuraLog"
                  width={32}
                  height={32}
                  className="object-contain"
                  priority
                />
              </button>

              {/* Desktop nav */}
              <nav className="hidden items-center gap-8 md:flex">
                {[
                  { label: 'Problem', id: 'problem' },
                  { label: 'Features', id: 'features' },
                  { label: 'How it works', id: 'how-it-works' },
                ].map(({ label, id }) => (
                  <button
                    key={id}
                    onClick={() => handleNav(id)}
                    className="text-sm text-muted-foreground transition-colors hover:text-foreground"
                  >
                    {label}
                  </button>
                ))}
              </nav>

              {/* CTA + theme toggle */}
              <div className="flex items-center gap-3">
                <ThemeToggle />
                <Button
                  size="sm"
                  className="hidden rounded-full bg-sage px-5 text-sm font-semibold text-black hover:bg-sage/90 md:inline-flex"
                  onClick={scrollToSignup}
                >
                  Join Waitlist
                </Button>

                {/* Mobile hamburger */}
                <button
                  className="flex flex-col gap-1.5 p-1 md:hidden"
                  onClick={() => setMenuOpen((o) => !o)}
                  aria-label="Toggle menu"
                >
                  <span
                    className={`block h-px w-5 bg-foreground transition-transform ${menuOpen ? 'translate-y-1.5 rotate-45' : ''}`}
                  />
                  <span
                    className={`block h-px w-5 bg-foreground transition-opacity ${menuOpen ? 'opacity-0' : ''}`}
                  />
                  <span
                    className={`block h-px w-5 bg-foreground transition-transform ${menuOpen ? '-translate-y-2 -rotate-45' : ''}`}
                  />
                </button>
              </div>
            </div>
          </div>

          {/* Mobile menu */}
          <AnimatePresence>
            {menuOpen && (
              <motion.div
                initial={{ opacity: 0, height: 0 }}
                animate={{ opacity: 1, height: 'auto' }}
                exit={{ opacity: 0, height: 0 }}
                className="mx-6 overflow-hidden rounded-b-2xl border border-t-0 border-white/8 bg-black/90 backdrop-blur-xl md:hidden"
              >
                <nav className="flex flex-col gap-1 p-4">
                  {[
                    { label: 'Problem', id: 'problem' },
                    { label: 'Features', id: 'features' },
                    { label: 'How it works', id: 'how-it-works' },
                  ].map(({ label, id }) => (
                    <button
                      key={id}
                      onClick={() => handleNav(id)}
                      className="rounded-xl px-4 py-3 text-left text-sm text-muted-foreground hover:bg-white/5 hover:text-foreground"
                    >
                      {label}
                    </button>
                  ))}
                  <Button
                    className="mt-2 w-full rounded-full bg-sage font-semibold text-black"
                    onClick={scrollToSignup}
                  >
                    Join Waitlist
                  </Button>
                </nav>
              </motion.div>
            )}
          </AnimatePresence>
        </motion.header>
      )}
    </AnimatePresence>
  );
}
