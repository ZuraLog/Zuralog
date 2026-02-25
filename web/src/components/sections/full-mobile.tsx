/**
 * Full Mobile section — "Your Gateway To Health Excellence"
 *
 * Lime-background (#E8F5A8) section showcasing the Zuralog mobile experience.
 * Three-column asymmetric layout:
 *   - Left  (28%): Scroll-animated headline
 *   - Center (44%): CSS phone mockup with dashboard/chat toggle
 *   - Right (28%): Scroll-animated description + stat pills
 *
 * Mobile: single-column stacked (phone → headline → description).
 *
 * Key design decisions:
 *   - NO HeroSceneLoader / React Three Fiber — uses a pure CSS phone mockup
 *   - Mouse parallax via JS event listener (±3° max tilt)
 *   - Framer Motion for text entrance + toggle spring transitions
 *   - ScrollReveal wraps the left/right columns and the phone
 */
'use client';

import { useState, useRef, useCallback, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { ScrollReveal } from '@/components/scroll-reveal';

// ─── Types ────────────────────────────────────────────────────────────────────

type ViewMode = 'dashboard' | 'chat';

// ─── Phone screen content ─────────────────────────────────────────────────────

/** Dashboard view: header + 3 metric cards + icon dock */
function DashboardScreen() {
  return (
    <motion.div
      key="dashboard"
      className="flex h-full flex-col"
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -8 }}
      transition={{ duration: 0.28, ease: 'easeOut' }}
    >
      {/* App header bar */}
      <div className="flex items-center gap-1.5 px-3 pt-2 pb-1.5">
        <div className="h-2 w-2 rounded-full bg-[#CFE1B9]" />
        <span
          className="text-[11px] font-bold tracking-tight text-white"
          style={{ fontFamily: 'var(--font-satoshi, system-ui)' }}
        >
          Zuralog
        </span>
        <span className="ml-auto text-[9px] text-white/40">Today</span>
      </div>

      {/* Greeting */}
      <div className="px-3 pb-1.5">
        <p className="text-[9px] text-white/40 leading-tight">Good morning, Alex</p>
        <p className="text-[11px] font-semibold text-white leading-tight">Your Health Score</p>
        <div className="mt-0.5 flex items-baseline gap-1">
          <span className="text-xl font-bold text-[#CFE1B9] leading-none">87</span>
          <span className="text-[9px] text-white/40">/100</span>
          <span className="ml-1 text-[9px] text-[#CFE1B9]">↑ 4pts</span>
        </div>
      </div>

      {/* Metric cards grid */}
      <div className="flex flex-col gap-1 px-2 pb-1">
        {/* Steps */}
        <div className="flex items-center justify-between rounded-[6px] bg-white/8 px-2 py-1.5">
          <div className="flex items-center gap-1.5">
            <span className="text-xs">👟</span>
            <div>
              <p className="text-[8px] text-white/40 leading-none">Steps</p>
              <p className="text-[11px] font-bold text-white leading-tight">8,432</p>
            </div>
          </div>
          <div className="h-5 w-8 overflow-hidden">
            {/* Mini sparkline */}
            <svg viewBox="0 0 32 20" className="h-full w-full">
              <polyline
                points="0,14 5,10 10,12 15,6 20,8 25,4 32,2"
                fill="none"
                stroke="#CFE1B9"
                strokeWidth="1.5"
                strokeLinejoin="round"
              />
            </svg>
          </div>
        </div>

        {/* Heart Rate */}
        <div className="flex items-center justify-between rounded-[6px] bg-white/8 px-2 py-1.5">
          <div className="flex items-center gap-1.5">
            <span className="text-xs">❤️</span>
            <div>
              <p className="text-[8px] text-white/40 leading-none">Heart Rate</p>
              <p className="text-[11px] font-bold text-white leading-tight">72 bpm</p>
            </div>
          </div>
          <span className="text-[9px] text-white/40">Resting</span>
        </div>

        {/* Sleep */}
        <div className="flex items-center justify-between rounded-[6px] bg-white/8 px-2 py-1.5">
          <div className="flex items-center gap-1.5">
            <span className="text-xs">🌙</span>
            <div>
              <p className="text-[8px] text-white/40 leading-none">Sleep</p>
              <p className="text-[11px] font-bold text-white leading-tight">7h 23m</p>
            </div>
          </div>
          <span className="text-[9px] text-[#CFE1B9]">+12%</span>
        </div>
      </div>

      {/* App icon dock */}
      <div className="mt-auto flex items-center justify-around border-t border-white/8 px-4 pt-1.5 pb-2">
        {['🏃', '🍎', '💤', '🧠'].map((emoji, i) => (
          <div
            key={i}
            className="flex h-7 w-7 items-center justify-center rounded-[8px] bg-white/10"
            style={{ fontSize: 12 }}
          >
            {emoji}
          </div>
        ))}
      </div>
    </motion.div>
  );
}

/** Chat view: AI conversation UI */
function ChatScreen() {
  return (
    <motion.div
      key="chat"
      className="flex h-full flex-col"
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -8 }}
      transition={{ duration: 0.28, ease: 'easeOut' }}
    >
      {/* Chat header */}
      <div className="flex items-center gap-1.5 border-b border-white/8 px-3 pt-2 pb-1.5">
        <div className="flex h-5 w-5 items-center justify-center rounded-full bg-[#CFE1B9]/20">
          <span className="text-[9px]">🧠</span>
        </div>
        <span
          className="text-[11px] font-bold text-white"
          style={{ fontFamily: 'var(--font-satoshi, system-ui)' }}
        >
          Zura AI
        </span>
        <div className="ml-auto flex items-center gap-1">
          <motion.div
            className="h-1.5 w-1.5 rounded-full bg-[#CFE1B9]"
            animate={{ opacity: [1, 0.3, 1] }}
            transition={{ duration: 1.5, repeat: Infinity }}
          />
          <span className="text-[8px] text-white/40">online</span>
        </div>
      </div>

      {/* Messages */}
      <div className="flex flex-1 flex-col justify-end gap-2 px-2.5 py-2">
        {/* User message */}
        <div className="flex justify-end">
          <div className="max-w-[75%] rounded-[10px] rounded-br-[3px] bg-[#CFE1B9] px-2.5 py-1.5">
            <p className="text-[9px] font-medium leading-snug text-black">
              How did I sleep last week?
            </p>
          </div>
        </div>

        {/* AI response */}
        <div className="flex justify-start">
          <div className="max-w-[82%] rounded-[10px] rounded-bl-[3px] bg-white/10 px-2.5 py-1.5">
            <p className="text-[9px] leading-snug text-white/80">
              Your average sleep last week was{' '}
              <span className="font-bold text-[#CFE1B9]">7h 14m</span>, up{' '}
              <span className="font-bold text-[#CFE1B9]">18%</span> from the
              previous week. 🎉
            </p>
          </div>
        </div>

        {/* Follow-up prompt chips */}
        <div className="flex flex-wrap gap-1 pt-0.5">
          {['What improved?', 'Show trend'].map((chip) => (
            <div
              key={chip}
              className="rounded-full border border-white/15 px-2 py-0.5"
            >
              <span className="text-[8px] text-white/50">{chip}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Input bar */}
      <div className="flex items-center gap-1.5 border-t border-white/8 px-2.5 pb-2 pt-1.5">
        <div className="flex-1 rounded-full bg-white/8 px-2.5 py-1">
          <span className="text-[9px] text-white/25">Ask anything…</span>
        </div>
        <div className="flex h-5 w-5 items-center justify-center rounded-full bg-[#CFE1B9]">
          <span className="text-[9px]">↑</span>
        </div>
      </div>
    </motion.div>
  );
}

// ─── CSS Phone Mockup ─────────────────────────────────────────────────────────

/**
 * Renders a premium CSS phone mockup with parallax tilt on mouse move.
 *
 * @param viewMode - Which screen content to display ('dashboard' | 'chat')
 */
function PhoneMockup({ viewMode }: { viewMode: ViewMode }) {
  const phoneRef = useRef<HTMLDivElement>(null);
  const rafRef = useRef<number | null>(null);

  /** Smooth mouse parallax — ±3° tilt on both axes */
  const handleMouseMove = useCallback((e: MouseEvent) => {
    if (!phoneRef.current) return;

    if (rafRef.current) cancelAnimationFrame(rafRef.current);

    rafRef.current = requestAnimationFrame(() => {
      if (!phoneRef.current) return;
      const rect = phoneRef.current.getBoundingClientRect();
      const cx = rect.left + rect.width / 2;
      const cy = rect.top + rect.height / 2;
      const dx = (e.clientX - cx) / (window.innerWidth / 2);
      const dy = (e.clientY - cy) / (window.innerHeight / 2);

      const rotateY = dx * 3;   // ±3° max
      const rotateX = -dy * 3;  // ±3° max (inverted Y for natural tilt)

      phoneRef.current.style.transform = `perspective(1000px) rotateX(${rotateX}deg) rotateY(${rotateY}deg)`;
    });
  }, []);

  const handleMouseLeave = useCallback(() => {
    if (!phoneRef.current) return;
    phoneRef.current.style.transform = 'perspective(1000px) rotateX(0deg) rotateY(0deg)';
  }, []);

  useEffect(() => {
    window.addEventListener('mousemove', handleMouseMove);
    window.addEventListener('mouseleave', handleMouseLeave);
    return () => {
      window.removeEventListener('mousemove', handleMouseMove);
      window.removeEventListener('mouseleave', handleMouseLeave);
      if (rafRef.current) cancelAnimationFrame(rafRef.current);
    };
  }, [handleMouseMove, handleMouseLeave]);

  return (
    <div
      ref={phoneRef}
      className="animate-float-gentle shadow-2xl"
      style={{
        width: 220,
        height: 440,
        borderRadius: '2.5rem',
        backgroundColor: '#1a1a1a',
        transition: 'transform 0.12s ease-out',
        willChange: 'transform',
        position: 'relative',
        overflow: 'hidden',
      }}
    >
      {/* Subtle outer ring highlight (titanium edge) */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          borderRadius: '2.5rem',
          boxShadow: 'inset 0 0 0 1px rgba(255,255,255,0.12), inset 0 1px 0 rgba(255,255,255,0.2)',
          zIndex: 10,
          pointerEvents: 'none',
        }}
      />

      {/* Dynamic island / notch */}
      <div
        style={{
          position: 'absolute',
          top: 10,
          left: '50%',
          transform: 'translateX(-50%)',
          width: 72,
          height: 20,
          borderRadius: 999,
          backgroundColor: '#1a1a1a',
          zIndex: 20,
        }}
      />

      {/* Screen inset */}
      <div
        style={{
          position: 'absolute',
          inset: 4,
          borderRadius: 'calc(2.5rem - 4px)',
          backgroundColor: '#0f0f10',
          overflow: 'hidden',
        }}
      >
        {/* Status bar spacer */}
        <div style={{ height: 32 }} />

        {/* Screen content */}
        <div style={{ position: 'absolute', inset: 0, top: 32, overflow: 'hidden' }}>
          <AnimatePresence mode="wait">
            {viewMode === 'dashboard' ? (
              <DashboardScreen key="dashboard" />
            ) : (
              <ChatScreen key="chat" />
            )}
          </AnimatePresence>
        </div>
      </div>

      {/* Bottom home bar */}
      <div
        style={{
          position: 'absolute',
          bottom: 8,
          left: '50%',
          transform: 'translateX(-50%)',
          width: 100,
          height: 4,
          borderRadius: 999,
          backgroundColor: 'rgba(255,255,255,0.2)',
          zIndex: 20,
        }}
      />
    </div>
  );
}

// ─── Left Column — Headline ───────────────────────────────────────────────────

function HeadlineColumn() {
  return (
    <motion.div
      className="flex flex-col gap-0 text-center md:text-left"
      initial={{ opacity: 0, x: -30 }}
      whileInView={{ opacity: 1, x: 0 }}
      viewport={{ once: true, margin: '-80px' }}
      transition={{ duration: 0.8, ease: [0.16, 1, 0.3, 1] }}
    >
      <h2
        className="text-display-section text-[var(--text-primary)] leading-[1.08]"
        style={{ fontWeight: 400 }}
      >
        <span className="block">Your Gateway</span>
        <span className="block">To Health</span>
        <span className="block font-bold">Excellence</span>
      </h2>
    </motion.div>
  );
}

// ─── Right Column — Description + Stat Pills ──────────────────────────────────

const STAT_PILLS = [
  '50+ Apps Connected',
  'AI-Powered Insights',
  'Zero Manual Logging',
] as const;

function DescriptionColumn() {
  return (
    <motion.div
      className="flex flex-col items-center gap-6 text-center md:items-end md:text-right"
      initial={{ opacity: 0, x: 30 }}
      whileInView={{ opacity: 1, x: 0 }}
      viewport={{ once: true, margin: '-80px' }}
      transition={{ duration: 0.8, delay: 0.2, ease: [0.16, 1, 0.3, 1] }}
    >
      <p className="text-body-lg max-w-xs text-[var(--text-secondary)]">
        Zuralog unifies your health data from Apple Health, Google Fit, and 50+
        fitness apps into one intelligent dashboard.
      </p>

      {/* Stat pills */}
      <div className="flex flex-wrap justify-center gap-2 md:justify-end">
        {STAT_PILLS.map((label) => (
          <span
            key={label}
            className="rounded-full bg-white px-4 py-1.5 text-body-sm font-medium text-[var(--text-primary)] shadow-sm"
          >
            {label}
          </span>
        ))}
      </div>
    </motion.div>
  );
}

// ─── View Toggle ──────────────────────────────────────────────────────────────

interface ViewToggleProps {
  value: ViewMode;
  onChange: (v: ViewMode) => void;
}

function ViewToggle({ value, onChange }: ViewToggleProps) {
  const options: { id: ViewMode; label: string }[] = [
    { id: 'dashboard', label: 'Dashboard' },
    { id: 'chat', label: 'Chat' },
  ];

  return (
    <div className="flex flex-col items-center gap-2">
      <span className="text-body-sm text-[var(--text-secondary)]">Switch view:</span>
      <div className="flex rounded-full bg-black/10 p-1">
        {options.map(({ id, label }) => {
          const isActive = value === id;
          return (
            <button
              key={id}
              onClick={() => onChange(id)}
              className="relative rounded-full px-5 py-1.5 text-body-sm font-medium transition-colors"
              style={{
                color: isActive ? 'white' : 'var(--text-secondary)',
              }}
              aria-pressed={isActive}
            >
              {isActive && (
                <motion.div
                  layoutId="toggle-pill"
                  className="absolute inset-0 rounded-full"
                  style={{ backgroundColor: 'var(--text-primary)' }}
                  transition={{ type: 'spring', stiffness: 400, damping: 30 }}
                />
              )}
              <span className="relative z-10">{label}</span>
            </button>
          );
        })}
      </div>
    </div>
  );
}

// ─── Full Mobile Section ──────────────────────────────────────────────────────

/**
 * FullMobileSection — showcases the Zuralog mobile experience.
 *
 * Placed directly after <Hero /> and before <ProblemSection /> in page.tsx.
 * Uses the lime section background (#E8F5A8) from the design system.
 */
export function FullMobileSection() {
  const [viewMode, setViewMode] = useState<ViewMode>('dashboard');

  return (
    <section
      id="your-gateway"
      className="bg-[var(--section-lime)] section-padding"
    >
      <div className="section-container">
        {/* ── 3-Column Grid ── */}
        <div className="grid grid-cols-1 items-center gap-12 md:grid-cols-[28fr_44fr_28fr] md:gap-8">

          {/* Left: Headline — HeadlineColumn owns its own whileInView animation */}
          <div className="flex items-center justify-center md:justify-start">
            <HeadlineColumn />
          </div>

          {/* Center: Phone mockup — ScrollReveal adds a gentle y-entrance */}
          <ScrollReveal
            y={20}
            delay={0.15}
            className="order-first flex items-center justify-center md:order-none"
          >
            <PhoneMockup viewMode={viewMode} />
          </ScrollReveal>

          {/* Right: Description — DescriptionColumn owns its own whileInView animation */}
          <div className="flex items-center justify-center md:justify-end">
            <DescriptionColumn />
          </div>
        </div>

        {/* ── Toggle ── */}
        <div className="mt-16 flex justify-center">
          <ViewToggle value={viewMode} onChange={setViewMode} />
        </div>
      </div>
    </section>
  );
}
