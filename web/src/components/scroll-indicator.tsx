/**
 * ScrollIndicator — top progress bar + side dot nav.
 *
 * Progress bar: thin sage-green line at the top that fills as you scroll.
 * Dot nav: small dots on the right side, one per section, highlighting active.
 */
'use client';

import { useEffect, useState, useCallback } from 'react';

const SECTIONS = [
  { id: 'hero', label: 'Hero' },
  { id: 'problem', label: 'Problem' },
  { id: 'features', label: 'Features' },
  { id: 'how-it-works', label: 'How it works' },
  { id: 'waitlist', label: 'Waitlist' },
] as const;

/**
 * Renders a top scroll progress bar and a side dot navigation
 * that tracks which section is currently in view.
 */
export function ScrollIndicator() {
  const [progress, setProgress] = useState(0);
  const [activeSection, setActiveSection] = useState(0);
  const [visible, setVisible] = useState(false);

  const handleScroll = useCallback(() => {
    const scrollTop = window.scrollY;
    const docHeight = document.documentElement.scrollHeight - window.innerHeight;
    const scrolled = docHeight > 0 ? scrollTop / docHeight : 0;
    setProgress(scrolled);
    setVisible(scrollTop > 100);

    // Determine active section based on which is most in view
    let current = 0;
    for (let i = SECTIONS.length - 1; i >= 0; i--) {
      const el = document.getElementById(SECTIONS[i].id);
      if (el) {
        const rect = el.getBoundingClientRect();
        if (rect.top <= window.innerHeight * 0.4) {
          current = i;
          break;
        }
      }
    }
    setActiveSection(current);
  }, []);

  useEffect(() => {
    handleScroll();
    window.addEventListener('scroll', handleScroll, { passive: true });
    return () => window.removeEventListener('scroll', handleScroll);
  }, [handleScroll]);

  const scrollTo = (id: string) => {
    document.getElementById(id)?.scrollIntoView({ behavior: 'smooth' });
  };

  return (
    <>
      {/* Top progress bar */}
      <div
        className="fixed top-0 left-0 z-50 h-[2px] w-full transition-opacity duration-300"
        style={{ opacity: visible ? 1 : 0 }}
      >
        <div
          className="h-full bg-sage/70"
          style={{
            width: `${progress * 100}%`,
            boxShadow: '0 0 8px oklch(0.84 0.07 140 / 50%)',
            transition: 'width 50ms linear',
          }}
        />
      </div>

      {/* Side dot nav */}
      <nav
        className="fixed right-2 top-1/2 z-50 hidden -translate-y-1/2 transition-opacity duration-300 md:block md:right-4"
        style={{ opacity: visible ? 1 : 0 }}
        aria-label="Section navigation"
      >
        <ul className="flex flex-col items-center gap-4">
          {SECTIONS.map((section, i) => (
            <li key={section.id} className="group relative">
              <button
                onClick={() => scrollTo(section.id)}
                aria-label={`Scroll to ${section.label}`}
                className="flex items-center justify-center p-1"
              >
                <span
                  className="block rounded-full transition-all duration-300"
                  style={{
                    width: activeSection === i ? 8 : 5,
                    height: activeSection === i ? 8 : 5,
                    backgroundColor:
                      activeSection === i
                        ? 'oklch(0.84 0.07 140)'
                        : 'oklch(1 0 0 / 20%)',
                    boxShadow:
                      activeSection === i
                        ? '0 0 6px oklch(0.84 0.07 140 / 50%)'
                        : 'none',
                  }}
                />
              </button>
              {/* Tooltip */}
              <span className="pointer-events-none absolute right-8 top-1/2 -translate-y-1/2 whitespace-nowrap rounded-md bg-surface-elevated px-2 py-1 text-xs text-foreground opacity-0 transition-opacity duration-200 group-hover:opacity-100">
                {section.label}
              </span>
            </li>
          ))}
        </ul>
      </nav>
    </>
  );
}
