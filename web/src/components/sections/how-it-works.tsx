/**
 * How It Works section — 3-step sequential reveal.
 *
 * Each step has a rich visual mockup:
 *   Step 1 — Connect: App connection flow with real OAuth-style UI
 *   Step 2 — Learn: AI pattern discovery visualization
 *   Step 3 — Act: Mobile morning briefing mockup
 *
 * GSAP ScrollTrigger animations with connector line reveals.
 */
'use client';

import { useRef } from 'react';
import { useGSAP } from '@gsap/react';
import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { motion } from 'framer-motion';
import {
  SiStrava,
  SiApple,
  SiGarmin,
  SiFitbit,
} from '@icons-pack/react-simple-icons';
import { Link2, Sparkles, Zap } from 'lucide-react';

gsap.registerPlugin(ScrollTrigger);

// ─── Step Visual 1: Connect ───────────────────────────────────────────────────

function ConnectVisual() {
  const apps = [
    { Icon: SiStrava, color: '#FC4C02', label: 'Strava', connected: true, delay: 0 },
    { Icon: SiApple, color: '#e8e8e8', label: 'Apple Health', connected: true, delay: 0.3 },
    { Icon: SiGarmin, color: '#007CC3', label: 'Garmin', connected: true, delay: 0.6 },
    { Icon: SiFitbit, color: '#00B0B9', label: 'Fitbit', connected: false, delay: 0.9 },
    { letter: 'O', color: '#9B8EFF', label: 'Oura Ring', connected: false, delay: 1.2 },
    { letter: 'W', color: '#3DFF54', label: 'WHOOP', connected: false, delay: 1.5 },
  ];

  return (
    <div className="flex h-full flex-col p-5">
      <div className="mb-3 flex items-center gap-2">
        <Link2 className="h-3.5 w-3.5 text-sage" />
        <span className="text-[10px] font-semibold uppercase tracking-wider text-zinc-400">
          Connect your apps
        </span>
        <span className="ml-auto rounded-full border border-sage/20 bg-sage/8 px-2 py-0.5 text-[9px] text-sage">
          3 / 6 connected
        </span>
      </div>

      <div className="flex flex-col gap-2 flex-1">
        {apps.map((app, i) => (
          <motion.div
            key={app.label}
            className={`flex items-center gap-3 rounded-xl border px-3 py-2.5 ${
              app.connected
                ? 'border-sage/20 bg-sage/6'
                : 'border-white/6 bg-white/3 opacity-60'
            }`}
            initial={{ opacity: 0, x: -20 }}
            animate={{ opacity: app.connected ? 1 : 0.6, x: 0 }}
            transition={{ delay: i * 0.12, duration: 0.5 }}
          >
            <div className="flex h-8 w-8 items-center justify-center rounded-lg border border-white/10 bg-black/40">
              {'Icon' in app && app.Icon ? (
                <app.Icon size={14} color={app.color} />
              ) : (
                <span className="text-[11px] font-bold" style={{ color: app.color }}>{app.letter}</span>
              )}
            </div>
            <div className="flex-1">
              <p className="text-[11px] font-medium text-white/85">{app.label}</p>
            </div>
            <div>
              {app.connected ? (
                <motion.div
                  className="flex items-center gap-1 rounded-full border border-sage/30 bg-sage/10 px-2 py-0.5"
                  initial={{ scale: 0.5, opacity: 0 }}
                  animate={{ scale: 1, opacity: 1 }}
                  transition={{ delay: app.delay + 0.3, type: 'spring', stiffness: 300 }}
                >
                  <div className="h-1.5 w-1.5 rounded-full bg-sage" />
                  <span className="text-[9px] font-semibold text-sage">Connected</span>
                </motion.div>
              ) : (
                <button className="rounded-full border border-white/10 bg-white/5 px-2.5 py-0.5 text-[9px] text-zinc-400 hover:border-sage/20 hover:text-sage transition-colors">
                  Connect
                </button>
              )}
            </div>
          </motion.div>
        ))}
      </div>

      <div className="mt-3 rounded-xl border border-sage/15 bg-sage/5 px-3 py-2 text-center">
        <p className="text-[10px] text-zinc-400">
          One tap. Automatic from here on.
        </p>
      </div>
    </div>
  );
}

// ─── Step Visual 2: Learn ─────────────────────────────────────────────────────

function LearnVisual() {
  const insights = [
    {
      label: 'Sleep → Performance',
      detail: 'Run pace improves 8% after 8h+ sleep',
      confidence: 94,
      color: '#38BDF8',
      icon: '💤',
    },
    {
      label: 'Late eating → HRV',
      detail: 'HRV drops 23% when eating past 9 PM',
      confidence: 87,
      color: '#9B8EFF',
      icon: '🍽️',
    },
    {
      label: 'Recovery → Training',
      detail: 'Best workouts when recovery ≥ 80%',
      confidence: 91,
      color: '#10B981',
      icon: '⚡',
    },
  ];

  return (
    <div className="flex h-full flex-col p-5">
      <div className="mb-3 flex items-center gap-2">
        <Sparkles className="h-3.5 w-3.5 text-sage" />
        <span className="text-[10px] font-semibold uppercase tracking-wider text-zinc-400">
          Pattern Discovery
        </span>
        <span className="ml-auto text-[9px] text-zinc-600">14-day analysis</span>
      </div>

      {/* Pattern discovery visualization */}
      <div className="mb-3 rounded-xl border border-white/8 bg-black/40 p-3">
        <p className="mb-2 text-[9px] text-zinc-500">Correlating across all your data…</p>
        <div className="flex items-end gap-1 h-10">
          {Array.from({ length: 14 }, (_, i) => (
            <motion.div
              key={i}
              className="flex-1 rounded-sm bg-sage/20"
              style={{ minHeight: 2 }}
              animate={{ height: `${20 + Math.sin(i * 0.8) * 14 + 14}px` }}
              transition={{ delay: i * 0.06, duration: 0.5 }}
            />
          ))}
        </div>
        <p className="mt-1 text-[8px] text-zinc-600">14 days of cross-app patterns</p>
      </div>

      {/* Discovered correlations */}
      <div className="flex flex-1 flex-col gap-2">
        {insights.map((insight, i) => (
          <motion.div
            key={insight.label}
            className="rounded-xl border border-white/6 bg-white/3 p-2.5"
            initial={{ opacity: 0, y: 12 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: i * 0.25 + 0.4, duration: 0.5 }}
          >
            <div className="flex items-start justify-between gap-2">
              <div className="flex items-start gap-2 flex-1 min-w-0">
                <span className="text-sm">{insight.icon}</span>
                <div>
                  <p className="text-[10px] font-semibold text-white/90">{insight.label}</p>
                  <p className="text-[9px] text-zinc-500">{insight.detail}</p>
                </div>
              </div>
              <div className="flex flex-col items-end shrink-0">
                <span className="text-[10px] font-bold" style={{ color: insight.color }}>
                  {insight.confidence}%
                </span>
                <span className="text-[8px] text-zinc-600">confidence</span>
              </div>
            </div>
            <div className="mt-2 h-1 w-full overflow-hidden rounded-full bg-white/5">
              <motion.div
                className="h-full rounded-full"
                style={{ backgroundColor: insight.color }}
                initial={{ width: 0 }}
                animate={{ width: `${insight.confidence}%` }}
                transition={{ delay: i * 0.25 + 0.8, duration: 0.8, ease: 'easeOut' }}
              />
            </div>
          </motion.div>
        ))}
      </div>
    </div>
  );
}

// ─── Step Visual 3: Act ───────────────────────────────────────────────────────

function ActVisual() {
  return (
    <div className="flex h-full flex-col p-5">
      <div className="mb-3 flex items-center gap-2">
        <Zap className="h-3.5 w-3.5 text-sage" />
        <span className="text-[10px] font-semibold uppercase tracking-wider text-zinc-400">
          Your Morning Briefing
        </span>
        <span className="ml-auto text-[9px] text-zinc-600">6:45 AM</span>
      </div>

      {/* Phone-style notification panel */}
      <div className="flex flex-1 flex-col gap-2">
        {/* Main briefing card */}
        <motion.div
          className="rounded-2xl border border-sage/25 bg-sage/8 p-4"
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
        >
          <p className="text-[10px] text-zinc-400 mb-1">Good morning, Alex 👋</p>
          <p className="text-sm font-semibold text-white leading-snug">
            Your recovery is <span className="text-sage">91%</span>. Today is a great day for intensity.
          </p>
        </motion.div>

        {/* Today's plan */}
        <motion.div
          className="rounded-xl border border-white/8 bg-black/40 p-3"
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2, duration: 0.5 }}
        >
          <p className="mb-2 text-[9px] font-semibold uppercase tracking-wider text-zinc-500">Today&apos;s plan</p>
          <div className="flex flex-col gap-1.5">
            {[
              { icon: '🏃', text: 'Zone 2 run — 45 min @ 5:30/km', time: '7:00 AM' },
              { icon: '🥗', text: 'High-protein breakfast (40g target)', time: 'After run' },
              { icon: '💧', text: 'Hydration: 2.8L goal today', time: 'All day' },
            ].map((item, i) => (
              <motion.div
                key={item.text}
                className="flex items-center gap-2 rounded-lg bg-white/3 px-2.5 py-1.5"
                initial={{ opacity: 0, x: -10 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: i * 0.15 + 0.4 }}
              >
                <span className="text-sm">{item.icon}</span>
                <p className="flex-1 text-[10px] text-white/80">{item.text}</p>
                <span className="text-[9px] text-zinc-600 shrink-0">{item.time}</span>
              </motion.div>
            ))}
          </div>
        </motion.div>

        {/* Quick action buttons */}
        <motion.div
          className="grid grid-cols-3 gap-1.5 sm:gap-2"
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.7, duration: 0.5 }}
        >
          {[
            { icon: '▶', label: 'Start Run', primary: true },
            { icon: '📝', label: 'Log Meal', primary: false },
            { icon: '📊', label: 'Full Report', primary: false },
          ].map((btn) => (
            <button
              key={btn.label}
              className={`flex flex-col items-center gap-1 rounded-xl border py-2.5 text-center transition-colors ${
                btn.primary
                  ? 'border-sage/30 bg-sage/12 text-sage hover:bg-sage/20'
                  : 'border-white/8 bg-white/3 text-zinc-400 hover:border-white/15'
              }`}
            >
              <span className="text-sm">{btn.icon}</span>
              <span className="text-[9px] font-medium">{btn.label}</span>
            </button>
          ))}
        </motion.div>

        {/* Recovery ring */}
        <div className="flex items-center gap-3 rounded-xl border border-white/6 bg-white/3 px-3 py-2">
          <svg width="32" height="32" viewBox="0 0 32 32">
            <circle cx="16" cy="16" r="12" fill="none" stroke="rgba(255,255,255,0.08)" strokeWidth="3" />
            <circle
              cx="16" cy="16" r="12"
              fill="none"
              stroke="#10B981"
              strokeWidth="3"
              strokeDasharray={`${(91 / 100) * 75.4} 75.4`}
              strokeLinecap="round"
              transform="rotate(-90 16 16)"
            />
            <text x="16" y="20" textAnchor="middle" fill="white" fontSize="8" fontWeight="bold">91</text>
          </svg>
          <div>
            <p className="text-[10px] font-semibold text-white">Recovery Score</p>
            <p className="text-[9px] text-zinc-500">Highest in 2 weeks</p>
          </div>
        </div>
      </div>
    </div>
  );
}

// ─── Section ──────────────────────────────────────────────────────────────────

const STEPS = [
  {
    number: '01',
    icon: Link2,
    title: 'Connect',
    body: 'Link your fitness apps in seconds. One tap per app. ZuraLog handles the rest — no manual imports, no CSV uploads, no friction.',
    Visual: ConnectVisual,
    accent: '#CFE1B9',
  },
  {
    number: '02',
    icon: Sparkles,
    title: 'Learn',
    body: "ZuraLog's AI studies your patterns across all connected apps. It discovers what actually works for YOUR body — correlations that no single app can see.",
    Visual: LearnVisual,
    accent: '#9B8EFF',
  },
  {
    number: '03',
    icon: Zap,
    title: 'Act',
    body: 'Wake up to a personalized briefing. Get AI-adjusted training plans, automated meal logging, and real insights — all in one place, every single day.',
    Visual: ActVisual,
    accent: '#A8D8A8',
  },
];

/**
 * Renders the 3-step How It Works section with immersive step panels.
 */
export function HowItWorksSection() {
  const sectionRef = useRef<HTMLElement>(null);
  const stepsRef = useRef<HTMLDivElement>(null);

  useGSAP(
    () => {
      if (!stepsRef.current) return;

      gsap.fromTo(
        stepsRef.current.querySelectorAll('.step-item'),
        { opacity: 0, y: 50 },
        {
          opacity: 1,
          y: 0,
          duration: 0.8,
          ease: 'power3.out',
          stagger: 0.2,
          scrollTrigger: {
            trigger: stepsRef.current,
            start: 'top 75%',
          },
        },
      );

      gsap.fromTo(
        '.connector-line',
        { scaleX: 0, transformOrigin: 'left center' },
        {
          scaleX: 1,
          duration: 0.6,
          ease: 'power2.out',
          stagger: 0.2,
          scrollTrigger: {
            trigger: stepsRef.current,
            start: 'top 75%',
          },
        },
      );
    },
    { scope: sectionRef },
  );

  return (
    <section ref={sectionRef} className="relative overflow-hidden py-28 md:py-40" id="how-it-works">
      <div className="pointer-events-none absolute inset-0">
        <div className="absolute right-0 top-1/2 h-[500px] w-[500px] -translate-y-1/2 rounded-full bg-sage/3 blur-[100px]" />
      </div>

      <div className="relative mx-auto max-w-6xl px-4">
        <div className="mb-12 text-center md:mb-20">
          <p className="mb-4 text-xs font-semibold uppercase tracking-[0.2em] text-sage">How It Works</p>
          <h2 className="font-display text-4xl font-bold tracking-tight md:text-5xl">
            Three steps to your AI health hub
          </h2>
          <p className="mx-auto mt-4 max-w-lg text-lg text-muted-foreground">
            From scattered apps to unified intelligence in under 2 minutes.
          </p>
        </div>

        <div ref={stepsRef} className="flex flex-col gap-16 md:gap-20">
          {STEPS.map((step, i) => {
            const Icon = step.icon;
            const { Visual } = step;
            const isReversed = i % 2 === 1;

            return (
              <div
                key={step.number}
                className={`step-item grid items-center gap-6 md:gap-10 md:grid-cols-2 ${isReversed ? 'md:[&>*:first-child]:order-2' : ''}`}
              >
                {/* Text */}
                <div className="space-y-5">
                  {/* Step badge */}
                  <div className="flex items-center gap-4">
                    <div className="relative flex h-14 w-14 items-center justify-center rounded-2xl border bg-surface"
                      style={{ borderColor: `${step.accent}40` }}
                    >
                      <Icon className="h-6 w-6" style={{ color: step.accent }} />
                      <span
                        className="absolute -right-2 -top-2 flex h-5 w-5 items-center justify-center rounded-full text-[10px] font-bold text-background"
                        style={{ backgroundColor: step.accent }}
                      >
                        {i + 1}
                      </span>
                    </div>
                    <div className="h-px flex-1 bg-gradient-to-r from-border/40 to-transparent" />
                    <span
                      className="text-xs font-bold uppercase tracking-[0.15em]"
                      style={{ color: step.accent }}
                    >
                      Step {step.number}
                    </span>
                  </div>

                  <h3 className="font-display text-2xl font-bold leading-tight tracking-tight sm:text-3xl md:text-4xl">
                    {step.title}
                  </h3>
                  <p className="text-base leading-relaxed text-muted-foreground md:text-lg">{step.body}</p>
                </div>

                {/* Visual mockup */}
                <div
                  className="h-[22rem] overflow-hidden rounded-2xl border border-border/20 bg-black/60 backdrop-blur-sm sm:h-80 sm:rounded-3xl md:h-[400px]"
                  style={{
                    boxShadow: `0 0 80px rgba(0,0,0,0.5), 0 0 30px ${step.accent}0a`,
                  }}
                >
                  <Visual />
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
}
