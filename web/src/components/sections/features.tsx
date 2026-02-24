/**
 * Features Showcase section — 4 rich product visuals showing ZuraLog in action.
 *
 * Each feature has a detailed, accurate visual mockup:
 *   1. AI Reasoning    — cross-app AI chat insight panel
 *   2. Autonomous Actions — action feed with live status
 *   3. Zero-Friction Logging — multi-source data flow hub
 *   4. One Dashboard   — full metric dashboard with trend lines
 *
 * GSAP ScrollTrigger reveal with alternating text/visual layout.
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
} from '@icons-pack/react-simple-icons';
import { Brain, Zap, PenLine, LayoutDashboard } from 'lucide-react';

gsap.registerPlugin(ScrollTrigger);

// ─── Feature Visual 1: AI Reasoning / Cross-App Intelligence ────────────────

function NeuralVisual() {
  const sources = [
    { label: 'Oura Ring', color: '#9B8EFF', value: 'HRV: 52ms ↓', icon: 'O' },
    { label: 'Strava', color: '#FC4C02', value: 'Run: 10k yesterday', Icon: SiStrava },
    { label: 'CalAI', color: '#10B981', value: 'Ate late 9:48 PM', icon: 'C' },
  ];

  return (
    <div className="flex h-full flex-col gap-3 p-5">
      {/* AI insight header */}
      <div className="flex items-center gap-2 rounded-xl border border-sage/20 bg-sage/5 px-3 py-2">
        <div className="flex h-6 w-6 items-center justify-center rounded-full bg-sage/20">
          <Brain className="h-3 w-3 text-sage" />
        </div>
        <span className="text-[10px] font-semibold uppercase tracking-wider text-sage">ZuraLog AI</span>
        <span className="ml-auto flex items-center gap-1">
          <motion.div
            className="h-1.5 w-1.5 rounded-full bg-sage"
            animate={{ opacity: [1, 0.3, 1] }}
            transition={{ duration: 1.5, repeat: Infinity }}
          />
          <span className="text-[9px] text-sage/70">Analyzing</span>
        </span>
      </div>

      {/* Data sources flowing in */}
      <div className="grid grid-cols-3 gap-2">
        {sources.map((src, i) => (
          <motion.div
            key={src.label}
            className="flex flex-col gap-1 rounded-lg border border-white/8 bg-black/40 p-2"
            animate={{ borderColor: [`rgba(255,255,255,0.08)`, `${src.color}40`, `rgba(255,255,255,0.08)`] }}
            transition={{ duration: 2.5, delay: i * 0.8, repeat: Infinity }}
          >
            <div className="flex items-center gap-1.5">
              {'Icon' in src && src.Icon ? (
                <src.Icon size={10} color={src.color} />
              ) : (
                <span className="text-[9px] font-bold" style={{ color: src.color }}>{src.icon}</span>
              )}
              <span className="text-[9px] text-zinc-400">{src.label}</span>
            </div>
            <p className="text-[9px] font-medium text-white/80">{src.value}</p>
          </motion.div>
        ))}
      </div>

      {/* Arrow down */}
      <div className="flex justify-center">
        <motion.div
          animate={{ y: [0, 4, 0] }}
          transition={{ duration: 1.5, repeat: Infinity }}
          className="text-sage/40"
        >
          ▼
        </motion.div>
      </div>

      {/* AI insight bubble */}
      <motion.div
        className="rounded-2xl border border-sage/25 bg-sage/8 p-4"
        initial={{ opacity: 0, y: 10 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.8, delay: 1.2, repeat: 0 }}
      >
        <p className="text-xs leading-relaxed text-white/90">
          📊 <span className="font-semibold text-sage">Pattern detected:</span> Your HRV drops 23% after eating past 9 PM. Yesterday&apos;s late dinner likely impacted this morning&apos;s readiness.
        </p>
        <div className="mt-3 flex gap-2">
          <button className="rounded-full border border-sage/30 bg-sage/10 px-3 py-1 text-[10px] font-semibold text-sage">
            Adjust tomorrow
          </button>
          <button className="rounded-full border border-white/10 px-3 py-1 text-[10px] text-zinc-400">
            Show more
          </button>
        </div>
      </motion.div>

      {/* Correlation badge */}
      <div className="flex items-center gap-2 rounded-lg border border-purple-500/15 bg-purple-950/20 px-3 py-2">
        <span className="text-xs">🔗</span>
        <span className="text-[10px] text-purple-300/80">
          Correlating 3 data sources · 14-day pattern
        </span>
      </div>
    </div>
  );
}

// ─── Feature Visual 2: Autonomous Actions ────────────────────────────────────

function ActionsVisual() {
  const actions = [
    {
      time: '06:32 AM',
      icon: '🏃',
      title: 'Training load reduced by 20%',
      detail: 'HRV trending low (3 consecutive days)',
      status: 'done',
      statusLabel: 'Applied',
    },
    {
      time: '08:15 AM',
      icon: '🥗',
      title: 'Recovery meal suggested',
      detail: 'Greek yogurt + banana — optimal post-run',
      status: 'done',
      statusLabel: 'Logged',
    },
    {
      time: '09:00 AM',
      icon: '📊',
      title: 'Morning readiness report sent',
      detail: 'Shared with your coach · Recovery: 74%',
      status: 'progress',
      statusLabel: 'Sent',
    },
    {
      time: '02:30 PM',
      icon: '⚡',
      title: 'Strava sync → Dashboard updated',
      detail: '7.4km tempo · 2,180 kcal updated',
      status: 'done',
      statusLabel: 'Synced',
    },
    {
      time: '10:00 PM',
      icon: '🌙',
      title: 'Sleep optimization alert',
      detail: 'Wind down now — 7h target requires 10 PM bed',
      status: 'scheduled',
      statusLabel: 'Tonight',
    },
  ];

  const statusColors: Record<string, string> = {
    done: '#10B981',
    progress: '#F59E0B',
    scheduled: '#8B5CF6',
  };

  return (
    <div className="flex h-full flex-col p-5">
      <div className="mb-3 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Zap className="h-3.5 w-3.5 text-sage" />
          <span className="text-[10px] font-semibold uppercase tracking-wider text-zinc-400">
            AI Action Feed
          </span>
        </div>
        <span className="text-[9px] text-zinc-600">Today</span>
      </div>

      <div className="flex flex-col gap-2 overflow-hidden">
        {actions.map((action, i) => (
          <motion.div
            key={action.title}
            className="flex items-start gap-3 rounded-xl border border-white/6 bg-white/3 px-3 py-2.5"
            initial={{ opacity: 0, x: -16 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: i * 0.15, duration: 0.5 }}
          >
            <span className="mt-0.5 text-base">{action.icon}</span>
            <div className="min-w-0 flex-1">
              <p className="text-[10px] font-semibold text-white/90 leading-snug">{action.title}</p>
              <p className="text-[9px] text-zinc-500 leading-snug mt-0.5">{action.detail}</p>
            </div>
            <div className="flex flex-col items-end gap-0.5 shrink-0">
              <span
                className="rounded-full px-1.5 py-0.5 text-[8px] font-bold uppercase tracking-wide"
                style={{
                  backgroundColor: `${statusColors[action.status]}20`,
                  color: statusColors[action.status],
                }}
              >
                {action.statusLabel}
              </span>
              <span className="text-[8px] text-zinc-600">{action.time}</span>
            </div>
          </motion.div>
        ))}
      </div>
    </div>
  );
}

// ─── Feature Visual 3: Zero-Friction Logging ─────────────────────────────────
// Vertical top-to-bottom data flow: inputs → ZuraLog engine → unified result.
// Arrow direction is always downward, making the flow unambiguous.

function LoggingVisual() {
  const manualSources = [
    { label: 'Photo taken', sublabel: 'Chicken rice bowl', icon: '📸', delay: 0 },
    { label: 'Voice note', sublabel: '"Had a green salad"', icon: '🎙️', delay: 0.4 },
  ];

  const autoSources = [
    { label: 'Strava', sublabel: '8.2km · 5:12 pace', color: '#FC4C02', Icon: SiStrava, delay: 0.2 },
    { label: 'Apple Health', sublabel: '9,820 steps · 620 kcal', color: '#e8e8e8', Icon: SiApple, delay: 0.6 },
  ];

  return (
    <div className="flex h-full flex-col justify-between p-4 gap-2">
      {/* ── Row 1: Input sources side by side ── */}
      <div className="grid grid-cols-2 gap-2">
        {/* Manual inputs — left half */}
        <div className="flex flex-col gap-1.5">
          <div className="flex items-center gap-1.5 mb-0.5">
            <span className="text-[8px] font-bold uppercase tracking-widest text-zinc-500">You log</span>
            <span className="h-px flex-1 bg-zinc-800" />
          </div>
          {manualSources.map((src) => (
            <motion.div
              key={src.label}
              className="flex items-center gap-2 rounded-xl border border-white/8 bg-white/3 px-2.5 py-2"
              animate={{ y: [0, -2, 0] }}
              transition={{ duration: 3 + src.delay, repeat: Infinity, delay: src.delay, ease: 'easeInOut' }}
            >
              <span className="text-sm leading-none">{src.icon}</span>
              <div className="min-w-0">
                <p className="text-[9px] font-semibold text-white/85 truncate">{src.label}</p>
                <p className="text-[8px] text-zinc-500 truncate">{src.sublabel}</p>
              </div>
            </motion.div>
          ))}
        </div>

        {/* Auto-synced — right half */}
        <div className="flex flex-col gap-1.5">
          <div className="flex items-center gap-1.5 mb-0.5">
            <span className="text-[8px] font-bold uppercase tracking-widest text-zinc-500">Auto-synced</span>
            <span className="h-px flex-1 bg-zinc-800" />
          </div>
          {autoSources.map((src) => (
            <motion.div
              key={src.label}
              className="flex items-center gap-2 rounded-xl border border-white/8 bg-white/3 px-2.5 py-2"
              animate={{ y: [0, -2, 0] }}
              transition={{ duration: 3 + src.delay, repeat: Infinity, delay: src.delay, ease: 'easeInOut' }}
            >
              <src.Icon size={13} color={src.color} />
              <div className="min-w-0">
                <p className="text-[9px] font-semibold text-white/85 truncate">{src.label}</p>
                <p className="text-[8px] text-zinc-500 truncate">{src.sublabel}</p>
              </div>
            </motion.div>
          ))}
        </div>
      </div>

      {/* ── Row 2: Converging flow lines + hub ── */}
      <div className="relative flex flex-col items-center">
        {/* Animated SVG flow lines converging downward into the hub */}
        <svg
          viewBox="0 0 240 48"
          className="w-full"
          style={{ height: 48, overflow: 'visible' }}
          aria-hidden="true"
        >
          {/* Left branch: from left-quarter down and right to center */}
          <motion.path
            d="M 60 0 L 60 24 L 120 48"
            fill="none"
            stroke="rgba(207,225,185,0.35)"
            strokeWidth="1.5"
            strokeDasharray="6 4"
            animate={{ strokeDashoffset: [24, 0] }}
            transition={{ duration: 1.2, repeat: Infinity, ease: 'linear' }}
          />
          {/* Right branch: from right-quarter down and left to center */}
          <motion.path
            d="M 180 0 L 180 24 L 120 48"
            fill="none"
            stroke="rgba(207,225,185,0.25)"
            strokeWidth="1.5"
            strokeDasharray="6 4"
            animate={{ strokeDashoffset: [24, 0] }}
            transition={{ duration: 1.2, repeat: Infinity, ease: 'linear', delay: 0.4 }}
          />
          {/* Center straight line from midpoint to hub entry */}
          <motion.line
            x1="120" y1="0" x2="120" y2="48"
            stroke="rgba(207,225,185,0.5)"
            strokeWidth="1.5"
            strokeDasharray="6 4"
            animate={{ strokeDashoffset: [24, 0] }}
            transition={{ duration: 1.0, repeat: Infinity, ease: 'linear', delay: 0.2 }}
          />
        </svg>

        {/* ZuraLog processing hub */}
        <motion.div
          className="flex w-full items-center justify-center gap-2 rounded-2xl border border-sage/30 bg-sage/8 px-4 py-2.5"
          animate={{ borderColor: ['rgba(207,225,185,0.3)', 'rgba(207,225,185,0.6)', 'rgba(207,225,185,0.3)'] }}
          transition={{ duration: 2, repeat: Infinity, ease: 'easeInOut' }}
        >
          <motion.div
            className="h-1.5 w-1.5 rounded-full bg-sage"
            animate={{ opacity: [1, 0.3, 1], scale: [1, 0.8, 1] }}
            transition={{ duration: 1.2, repeat: Infinity }}
          />
          <span className="text-[10px] font-semibold uppercase tracking-widest text-sage">
            ZuraLog · Processing
          </span>
          <motion.div
            className="h-1.5 w-1.5 rounded-full bg-sage"
            animate={{ opacity: [1, 0.3, 1], scale: [1, 0.8, 1] }}
            transition={{ duration: 1.2, repeat: Infinity, delay: 0.6 }}
          />
        </motion.div>

        {/* Arrow pointing down from hub to result */}
        <motion.div
          className="mt-1 flex flex-col items-center"
          animate={{ y: [0, 2, 0] }}
          transition={{ duration: 1.5, repeat: Infinity, ease: 'easeInOut' }}
        >
          <div className="h-3 w-px bg-sage/40" />
          <div
            className="h-0 w-0"
            style={{
              borderLeft: '5px solid transparent',
              borderRight: '5px solid transparent',
              borderTop: '6px solid rgba(207,225,185,0.4)',
            }}
          />
        </motion.div>
      </div>

      {/* ── Row 3: Unified result ── */}
      <motion.div
        className="rounded-xl border border-sage/25 bg-sage/5 p-3"
        animate={{ opacity: [0.75, 1, 0.75] }}
        transition={{ duration: 3, repeat: Infinity }}
      >
        <p className="mb-2 text-[9px] font-semibold text-sage">✓ Unified for today</p>
        <div className="grid grid-cols-3 gap-2 text-center">
          {[
            { label: 'Total kcal', value: '2,340' },
            { label: 'Active', value: '78 min' },
            { label: 'Steps', value: '9,820' },
          ].map((m) => (
            <div key={m.label}>
              <p className="text-[11px] font-bold text-white">{m.value}</p>
              <p className="text-[8px] text-zinc-500">{m.label}</p>
            </div>
          ))}
        </div>
      </motion.div>
    </div>
  );
}

// ─── Feature Visual 4: One Dashboard ─────────────────────────────────────────

function DashboardVisual() {
  const metrics = [
    {
      label: 'HRV',
      value: '68',
      unit: 'ms',
      change: '+12%',
      positive: true,
      sparkValues: [55, 58, 52, 61, 64, 60, 68],
      color: '#9B8EFF',
    },
    {
      label: 'Recovery',
      value: '84',
      unit: '%',
      change: '+9%',
      positive: true,
      sparkValues: [70, 68, 75, 72, 78, 80, 84],
      color: '#10B981',
    },
    {
      label: 'Sleep',
      value: '7h 42m',
      unit: '',
      change: 'Deep: 1h 22m',
      positive: true,
      sparkValues: [6.2, 7.1, 6.8, 7.5, 7.0, 7.3, 7.7],
      color: '#38BDF8',
    },
    {
      label: 'Calories',
      value: '2,340',
      unit: '/ 2,800',
      change: '84% of goal',
      positive: true,
      sparkValues: [1800, 2100, 2300, 2000, 2400, 2200, 2340],
      color: '#FB923C',
    },
    {
      label: 'Active',
      value: '620',
      unit: 'kcal',
      change: 'Zone 2: 34min',
      positive: true,
      sparkValues: [400, 500, 480, 550, 600, 580, 620],
      color: '#F472B6',
    },
    {
      label: 'Training Load',
      value: 'Mod.',
      unit: '',
      change: 'Trend: ↑',
      positive: true,
      sparkValues: [3, 4, 3, 5, 4, 5, 4],
      color: '#34D399',
    },
  ];

  function MiniSparkline({ values, color }: { values: number[]; color: string }) {
    const min = Math.min(...values);
    const max = Math.max(...values);
    const range = max - min || 1;
    const h = 20;
    const w = 48;
    const pts = values.map((v, i) => `${(i / (values.length - 1)) * w},${h - ((v - min) / range) * h}`).join(' ');
    return (
      <svg width={w} height={h} viewBox={`0 0 ${w} ${h}`}>
        <polyline points={pts} fill="none" stroke={color} strokeWidth="1.5" strokeLinejoin="round" opacity="0.8" />
      </svg>
    );
  }

  return (
    <div className="flex h-full flex-col p-4">
      {/* AI banner */}
      <motion.div
        className="mb-3 flex items-start gap-2 rounded-xl border border-sage/20 bg-sage/6 px-3 py-2"
        animate={{ opacity: [0.8, 1, 0.8] }}
        transition={{ duration: 4, repeat: Infinity }}
      >
        <span className="text-sm">💡</span>
        <p className="text-[10px] leading-snug text-white/85">
          <span className="font-semibold text-sage">Best performance window:</span>{' '}
          10 AM – 1 PM today · Recovery 84% · HRV above baseline
        </p>
      </motion.div>

      {/* Metric grid */}
      <div className="grid grid-cols-2 gap-2 flex-1">
        {metrics.map((m, i) => (
          <motion.div
            key={m.label}
            className="flex flex-col justify-between rounded-xl border border-white/8 bg-black/40 p-2.5"
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ delay: i * 0.08, duration: 0.4 }}
            whileHover={{ borderColor: `${m.color}40` }}
          >
            <div className="flex items-start justify-between">
              <div>
                <p className="text-[9px] text-zinc-500">{m.label}</p>
                <p className="text-sm font-bold text-white leading-tight">
                  {m.value}<span className="text-[9px] font-normal text-zinc-500 ml-0.5">{m.unit}</span>
                </p>
              </div>
              <MiniSparkline values={m.sparkValues} color={m.color} />
            </div>
            <p className="text-[8px] mt-1" style={{ color: m.color }}>{m.change}</p>
          </motion.div>
        ))}
      </div>

      {/* Connected apps footer */}
      <div className="mt-3 flex items-center gap-1.5">
        <span className="text-[9px] text-zinc-600">Connected:</span>
        {[SiStrava, SiApple].map((Icon, i) => (
          <Icon key={i} size={10} color={i === 0 ? '#FC4C02' : '#e8e8e8'} />
        ))}
        <span className="text-[9px] text-zinc-600">+4 apps</span>
        <div className="ml-auto flex items-center gap-1">
          <div className="h-1.5 w-1.5 rounded-full bg-green-400" />
          <span className="text-[9px] text-green-400">Live</span>
        </div>
      </div>
    </div>
  );
}

// ─── Section ──────────────────────────────────────────────────────────────────

const FEATURES = [
  {
    icon: Brain,
    tag: 'AI Reasoning',
    title: 'Cross-app intelligence that actually connects the dots',
    body: "ZuraLog's AI reads across Strava, Oura, CalAI, and more simultaneously — noticing that your recovery scores drop when you eat late, or that your best runs follow 8+ hours of deep sleep. Then it tells you, in plain English.",
    visual: 'neural' as const,
    accent: '#CFE1B9',
    Visual: NeuralVisual,
  },
  {
    icon: Zap,
    tag: 'Autonomous Actions',
    title: 'Your AI acts — not just advises',
    body: "ZuraLog doesn't just tell you what to do. When your HRV is low, it adjusts your training plan. When you hit a macro goal, it suggests a recovery meal. It works behind the scenes so you don't have to think.",
    visual: 'actions' as const,
    accent: '#A8D8A8',
    Visual: ActionsVisual,
  },
  {
    icon: PenLine,
    tag: 'Zero-Friction Logging',
    title: 'Log once, sync everywhere — or don\'t log at all',
    body: 'Connect your apps and ZuraLog pulls data automatically. Snap a photo of your meal — ZuraLog sees it. Finish a Strava run — ZuraLog knows. Speak it like a human. It listens, parses, and files it away.',
    visual: 'logging' as const,
    accent: '#CFE1B9',
    Visual: LoggingVisual,
  },
  {
    icon: LayoutDashboard,
    tag: 'One Dashboard',
    title: 'Every metric, every app, one beautiful view',
    body: "Replace your five-app morning routine with one intelligent dashboard. See HRV, sleep quality, training load, calories, and active energy — all in one place, with AI surfacing only what matters today.",
    visual: 'dashboard' as const,
    accent: '#A8D8A8',
    Visual: DashboardVisual,
  },
];

/**
 * Renders the 4-feature showcase with rich product visuals and scroll animations.
 */
export function FeaturesSection() {
  const sectionRef = useRef<HTMLElement>(null);

  useGSAP(
    () => {
      if (!sectionRef.current) return;

      sectionRef.current.querySelectorAll('.feature-block').forEach((block) => {
        gsap.fromTo(
          block,
          { opacity: 0, y: 50 },
          {
            opacity: 1,
            y: 0,
            duration: 0.9,
            ease: 'power3.out',
            scrollTrigger: {
              trigger: block,
              start: 'top 80%',
            },
          },
        );
      });
    },
    { scope: sectionRef },
  );

  return (
    <section ref={sectionRef} className="py-28 md:py-40" id="features">
      <div className="mx-auto max-w-6xl px-4">
        <div className="mb-12 text-center md:mb-20">
          <p className="mb-4 text-xs font-semibold uppercase tracking-[0.2em] text-sage">What ZuraLog Does</p>
          <h2 className="font-display text-4xl font-bold tracking-tight md:text-5xl">
            One AI. All your apps. Actually useful.
          </h2>
          <p className="mx-auto mt-4 max-w-lg text-lg text-muted-foreground">
            Not just another tracker. An AI system that reads across your entire health ecosystem and takes action.
          </p>
        </div>

        <div className="space-y-16 md:space-y-24">
          {FEATURES.map((feature, i) => {
            const Icon = feature.icon;
            const { Visual } = feature;
            const isReversed = i % 2 === 1;
            return (
              <div
                key={feature.tag}
                className={`feature-block grid items-center gap-6 md:gap-10 md:grid-cols-2 ${isReversed ? 'md:[&>*:first-child]:order-2' : ''}`}
              >
                {/* Text */}
                <div className="space-y-5">
                  <div className="flex items-center gap-3">
                    <div className="inline-flex h-10 w-10 items-center justify-center rounded-xl border border-border/30 bg-surface">
                      <Icon className="h-4 w-4 text-sage" />
                    </div>
                    <span
                      className="text-xs font-semibold uppercase tracking-[0.15em]"
                      style={{ color: feature.accent }}
                    >
                      {feature.tag}
                    </span>
                  </div>
                  <h3 className="font-display text-2xl font-bold leading-tight tracking-tight sm:text-3xl md:text-4xl">
                    {feature.title}
                  </h3>
                  <p className="text-base leading-relaxed text-muted-foreground md:text-lg">{feature.body}</p>
                </div>

                {/* Visual mockup */}
                <div
                  className="h-[22rem] overflow-hidden rounded-2xl border border-border/20 bg-black/60 backdrop-blur-sm sm:h-80 sm:rounded-3xl md:h-96 shadow-[0_0_80px_rgba(0,0,0,0.6)]"
                  style={{
                    boxShadow: `0 0 80px rgba(0,0,0,0.6), 0 0 40px ${feature.accent}0a`,
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
