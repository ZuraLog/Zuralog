/**
 * Problem Statement section — "Your apps don't talk to each other."
 *
 * Three rich visual cards that viscerally show the pain:
 *   1. App Overload — floating disconnected app logos with broken links
 *   2. No Intelligence — noisy contradictory data chart
 *   3. Exhausting to Maintain — late-night manual logging horror
 *
 * GSAP scroll-triggered reveal with staggered card animations.
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

gsap.registerPlugin(ScrollTrigger);

// ─── Visual 1: App Chaos ─────────────────────────────────────────────────────

/**
 * Disconnected app ecosystem — SVG lines + HTML nodes share a single
 * coordinate system via a fixed-size container.
 *
 * The container is 280×200px (logical). The SVG is absolutely positioned to
 * fill it and draws all lines. HTML nodes are also absolutely positioned using
 * the exact same (x, y) values as the SVG, ensuring pixel-perfect alignment.
 */
function AppChaosVisual() {
  const W = 280;
  const H = 200;
  // Center slightly above midpoint to leave badge space at bottom
  const cx = W / 2;       // 140
  const cy = H / 2 - 8;  // 92

  const R = 76; // orbit radius in px

  const apps = [
    { label: 'Strava', Icon: SiStrava,  color: '#FC4C02', angleDeg: 218 },
    { label: 'Health', Icon: SiApple,   color: '#e8e8e8', angleDeg: 322 },
    { label: 'Garmin', Icon: SiGarmin,  color: '#007CC3', angleDeg: 148 },
    { label: 'Fitbit', Icon: SiFitbit,  color: '#00B0B9', angleDeg:  38 },
    { label: 'Oura',   Icon: null,      color: '#9B8EFF', angleDeg: 266, letter: 'O' },
    { label: 'WHOOP',  Icon: null,      color: '#3DFF54', angleDeg:  74, letter: 'W' },
  ] as const;

  const nodeR = 19; // icon circle visual radius (px)

  /** Polar → cartesian */
  const pos = (angleDeg: number, r = R) => ({
    x: cx + r * Math.cos((angleDeg * Math.PI) / 180),
    y: cy + r * Math.sin((angleDeg * Math.PI) / 180),
  });

  return (
    <div className="flex h-full w-full items-center justify-center px-2">
    <div
      className="relative w-full max-w-[280px] flex-shrink-0 overflow-visible"
      style={{ aspectRatio: `${W} / ${H}` }}
    >
      {/* ── SVG layer: lines only ── */}
      <svg
        className="absolute inset-0 h-full w-full"
        viewBox={`0 0 ${W} ${H}`}
        preserveAspectRatio="xMidYMid meet"
        style={{ pointerEvents: 'none' }}
      >
        <defs>
          <style>{`
            @keyframes appChaosFlow {
              from { stroke-dashoffset: 14; }
              to   { stroke-dashoffset: 0; }
            }
            .chaos-line {
              animation: appChaosFlow 0.9s linear infinite;
            }
          `}</style>
        </defs>

        {/* Lines from each app node edge → just short of center */}
        {apps.map((app, i) => {
          const { x: ax, y: ay } = pos(app.angleDeg);
          const dx = cx - ax;
          const dy = cy - ay;
          const len = Math.hypot(dx, dy);
          const ux = dx / len;
          const uy = dy / len;
          // Start: nodeR px away from app center (on its edge)
          const x1 = ax + ux * nodeR;
          const y1 = ay + uy * nodeR;
          // End: 26px away from hub center (broken gap)
          const x2 = cx - ux * 26;
          const y2 = cy - uy * 26;
          return (
            <line
              key={app.label}
              x1={x1} y1={y1}
              x2={x2} y2={y2}
              stroke="rgba(239,68,68,0.5)"
              strokeWidth="1.2"
              strokeDasharray="4 3"
              className="chaos-line"
              style={{ animationDelay: `${i * 0.15}s` }}
            />
          );
        })}

        {/* Center broken hub circle */}
        <circle
          cx={cx} cy={cy} r="23"
          fill="rgba(100,0,0,0.3)"
          stroke="rgba(239,68,68,0.5)"
          strokeWidth="1.5"
          strokeDasharray="3 2"
        />
      </svg>

      {/* ── HTML layer: center NO HUB label ── */}
      <div
        className="absolute flex flex-col items-center justify-center rounded-full"
        style={{
          width: 46, height: 46,
          left: cx - 23, top: cy - 23,
          zIndex: 2,
        }}
      >
        <span className="text-[7px] font-bold uppercase tracking-wider text-red-400 leading-tight">NO</span>
        <span className="text-[7px] font-bold uppercase tracking-wider text-red-400 leading-tight">HUB</span>
      </div>

      {/* ── HTML layer: app nodes ── */}
      {apps.map((app, i) => {
        const { x, y } = pos(app.angleDeg);
        return (
          <motion.div
            key={app.label}
            className="absolute flex flex-col items-center"
            style={{
              left: x - nodeR,
              top: y - nodeR,
              width: nodeR * 2,
              zIndex: 3,
            }}
            animate={{ y: [0, -3, 0, 3, 0] }}
            transition={{ duration: 3.5 + i * 0.6, repeat: Infinity, ease: 'easeInOut', delay: i * 0.4 }}
          >
            {/* Circle node */}
            <div
              className="flex items-center justify-center rounded-full border border-white/10 bg-black/70 shadow-lg"
              style={{
                width: nodeR * 2,
                height: nodeR * 2,
                boxShadow: `0 0 10px ${app.color}22`,
              }}
            >
              {app.Icon ? (
                <app.Icon size={16} color={app.color} />
              ) : (
                <span style={{ fontSize: 12, fontWeight: 700, color: app.color }}>
                  {'letter' in app ? app.letter : ''}
                </span>
              )}
            </div>
            {/* Label */}
            <span className="mt-0.5 text-center text-[8px] font-medium leading-tight text-zinc-500">
              {app.label}
            </span>
          </motion.div>
        );
      })}

      {/* ── Stat badges ── */}
      <div
        className="absolute rounded-lg border border-white/8 bg-black/60 px-2 py-1 backdrop-blur-sm"
        style={{ left: 4, bottom: 4 }}
      >
        <p className="text-[9px] text-zinc-500">Apps switching</p>
        <p className="text-xs font-bold text-red-400">5× / day</p>
      </div>
      <div
        className="absolute rounded-lg border border-white/8 bg-black/60 px-2 py-1 backdrop-blur-sm"
        style={{ right: 4, bottom: 4 }}
      >
        <p className="text-[9px] text-zinc-500">Data shared</p>
        <p className="text-xs font-bold text-red-400">0%</p>
      </div>
    </div>
    </div>
  );
}

// ─── Visual 2: Noisy Data ─────────────────────────────────────────────────────

/** Multiple contradictory charts showing noise without insight */
function NoiseDataVisual() {
  // Three contradictory mini charts
  const hrv = [62, 58, 71, 55, 68, 52, 74, 48];
  const calories = [2100, 1850, 2400, 1600, 2700, 1900, 2200, 1700];
  const sleep = [7.2, 5.8, 8.1, 6.2, 7.8, 5.1, 8.5, 6.0];

  function Sparkline({ values, color, label, unit }: { values: number[]; color: string; label: string; unit: string }) {
    const min = Math.min(...values);
    const max = Math.max(...values);
    const range = max - min || 1;
    const h = 26;
    const w = 90;
    const pts = values.map((v, i) => `${(i / (values.length - 1)) * w},${h - ((v - min) / range) * h}`).join(' ');

    return (
      <div className="rounded-lg border border-white/8 bg-black/40 px-2.5 py-1.5">
        <div className="mb-1 flex items-center justify-between">
          <span className="text-[9px] font-semibold uppercase tracking-wider" style={{ color }}>{label}</span>
          <span className="flex items-center gap-1 text-[9px] text-zinc-500">
            <span className="text-red-400">↕</span> Inconsistent
          </span>
        </div>
        <div className="flex items-end gap-3">
          <svg width={w} height={h} viewBox={`0 0 ${w} ${h}`} className="flex-shrink-0 overflow-visible">
            <polyline
              points={pts}
              fill="none"
              stroke={color}
              strokeWidth="1.5"
              strokeLinejoin="round"
              opacity="0.7"
            />
            {/* Erratic highlight dots */}
            {values.map((v, i) => (
              <circle
                key={i}
                cx={(i / (values.length - 1)) * w}
                cy={h - ((v - min) / range) * h}
                r="2"
                fill={color}
                opacity={i % 2 === 0 ? "0.9" : "0.3"}
              />
            ))}
          </svg>
          <div className="flex items-baseline gap-0.5">
            <span className="text-sm font-bold text-white">{values[values.length - 1]}</span>
            <span className="text-[9px] text-zinc-500">{unit}</span>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="flex h-full flex-col gap-1.5 p-3">
      <div className="mb-0.5 flex items-center gap-2">
        <div className="h-2 w-2 rounded-full bg-red-400" />
        <span className="text-[10px] font-semibold uppercase tracking-wider text-zinc-400">
          Your data — 3 apps, 0 insight
        </span>
      </div>
      <Sparkline values={hrv} color="#9B8EFF" label="HRV" unit="ms" />
      <Sparkline values={calories} color="#FB923C" label="Calories" unit="kcal" />
      <Sparkline values={sleep} color="#38BDF8" label="Sleep" unit="hrs" />

      {/* Confusion overlay */}
      <div className="mt-auto flex items-center gap-2 rounded-lg border border-yellow-500/20 bg-yellow-950/20 px-2.5 py-1.5">
        <span className="text-xs">❓</span>
        <span className="text-[10px] text-yellow-400/80">
          What does this even mean for tomorrow&apos;s run?
        </span>
      </div>
    </div>
  );
}

// ─── Visual 3: Manual Logging Horror ─────────────────────────────────────────

/** Late-night manual logging form showing the tedium */
function ManualLoggingVisual() {
  const fields = [
    { label: 'Breakfast (kcal)', value: '420', done: true },
    { label: 'Lunch (kcal)', value: '680', done: true },
    { label: 'Dinner (kcal)', value: '...', done: false },
    { label: 'Workout duration', value: '47 min', done: true },
    { label: 'Sleep start time', value: '...', done: false },
    { label: 'Sleep quality (1-10)', value: '...', done: false },
    { label: 'HRV (manual)', value: '...', done: false },
    { label: 'Water intake (L)', value: '...', done: false },
  ];

  return (
    <div className="flex h-full flex-col p-3">
      {/* Header: Time stamp */}
      <div className="mb-1.5 flex items-center justify-between">
        <span className="text-[9px] font-semibold uppercase tracking-wider text-zinc-500">Daily log</span>
        <div className="flex items-center gap-1.5 rounded-lg border border-orange-500/20 bg-orange-950/20 px-2 py-0.5">
          <span className="text-sm">🕙</span>
          <span className="text-[10px] font-bold text-orange-400">11:47 PM</span>
        </div>
      </div>

      {/* Form fields */}
      <div className="flex flex-1 flex-col gap-px overflow-hidden">
        {fields.map((field, i) => (
          <motion.div
            key={field.label}
            className={`flex items-center justify-between rounded-md border px-2 py-0.5 ${
              field.done
                ? 'border-sage/15 bg-sage/5'
                : 'border-white/6 bg-white/3'
            }`}
            initial={{ opacity: 0.4 }}
            animate={field.done ? {} : {
              opacity: [0.4, 0.8, 0.4],
              borderColor: ['rgba(255,255,255,0.06)', 'rgba(239,68,68,0.2)', 'rgba(255,255,255,0.06)'],
            }}
            transition={{ duration: 3, delay: i * 0.4, repeat: Infinity }}
          >
            <span className="text-[10px] text-zinc-500">{field.label}</span>
            <span className={`text-[10px] font-medium ${field.done ? 'text-sage' : 'text-zinc-600'}`}>
              {field.value}
            </span>
          </motion.div>
        ))}
      </div>

      {/* Completion meter */}
      <div className="mt-1.5">
        <div className="mb-1 flex items-center justify-between">
          <span className="text-[9px] text-zinc-600">Completion</span>
          <span className="text-[9px] font-bold text-orange-400">3 / 8 done</span>
        </div>
        <div className="h-1 w-full overflow-hidden rounded-full bg-white/5">
          <div className="h-full w-[37.5%] rounded-full bg-orange-500/60" />
        </div>
      </div>

      <div className="mt-1.5 text-center">
        <span className="text-[9px] text-zinc-600">Entry #847 this year</span>
      </div>
    </div>
  );
}

// ─── Section ──────────────────────────────────────────────────────────────────

const PAIN_POINTS = [
  {
    tag: '01',
    title: 'App overload',
    body: 'Strava for runs. Oura for sleep. MyFitnessPal for food. CalAI for macros. Five apps, zero connection between them.',
    Visual: AppChaosVisual,
    accent: '#FC4C02',
  },
  {
    tag: '02',
    title: 'Zero insight',
    body: "You have mountains of data but can't connect the dots. Your HRV and training load live in separate universes.",
    Visual: NoiseDataVisual,
    accent: '#9B8EFF',
  },
  {
    tag: '03',
    title: 'A second job',
    body: 'Logging every meal, workout, and sleep score — manually, every single night — is exhausting. You deserve better.',
    Visual: ManualLoggingVisual,
    accent: '#FB923C',
  },
];

/**
 * Renders the problem statement section with rich visual cards.
 */
export function ProblemSection() {
  const sectionRef = useRef<HTMLElement>(null);
  const headingRef = useRef<HTMLHeadingElement>(null);
  const cardsRef = useRef<HTMLDivElement>(null);

  useGSAP(
    () => {
      if (!sectionRef.current) return;

      gsap.fromTo(
        headingRef.current,
        { opacity: 0, y: 60 },
        {
          opacity: 1,
          y: 0,
          duration: 0.9,
          ease: 'power3.out',
          scrollTrigger: {
            trigger: headingRef.current,
            start: 'top 80%',
          },
        },
      );

      gsap.fromTo(
        cardsRef.current?.querySelectorAll('.pain-card') ?? [],
        { opacity: 0, y: 60 },
        {
          opacity: 1,
          y: 0,
          duration: 0.8,
          ease: 'power3.out',
          stagger: 0.18,
          scrollTrigger: {
            trigger: cardsRef.current,
            start: 'top 75%',
          },
        },
      );
    },
    { scope: sectionRef },
  );

  return (
    <section ref={sectionRef} className="relative overflow-hidden py-28 md:py-40" id="problem">
      {/* Section-local background accent */}
      <div className="pointer-events-none absolute inset-0">
        <div className="absolute left-1/4 top-1/2 h-[500px] w-[500px] -translate-y-1/2 rounded-full bg-red-900/5 blur-[120px]" />
        <div className="absolute right-1/4 top-1/2 h-[400px] w-[400px] -translate-y-1/2 rounded-full bg-purple-900/5 blur-[100px]" />
      </div>

      <div className="relative mx-auto max-w-6xl px-4">
        {/* Heading */}
        <div className="mb-12 text-center md:mb-20">
          <p className="mb-4 text-xs font-semibold uppercase tracking-[0.2em] text-sage">The Problem</p>
          <h2
            ref={headingRef}
            className="font-display text-4xl font-bold leading-tight tracking-tight md:text-6xl lg:text-7xl"
          >
            Your apps{' '}
            <span className="relative inline-block text-foreground/40">don&apos;t</span>{' '}
            talk
            <br className="hidden md:block" />
            to each other.
          </h2>
          <p className="mx-auto mt-6 max-w-xl text-lg text-muted-foreground">
            You&apos;re juggling five fitness apps, drowning in data, and somehow knowing less about your health than ever.
          </p>
        </div>

        {/* Pain point cards */}
        <div ref={cardsRef} className="grid gap-6 sm:grid-cols-2 md:grid-cols-3">
          {PAIN_POINTS.map((point) => {
            const { Visual } = point;
            return (
              <div
                key={point.tag}
                className="pain-card group relative flex flex-col overflow-hidden rounded-3xl border border-border/30 bg-surface transition-all duration-500 hover:border-border/50 hover:shadow-[0_0_60px_rgba(0,0,0,0.4)]"
              >
                {/* Visual area */}
                <div className="h-56 w-full border-b border-border/20 bg-black/40 sm:h-64 md:h-72">
                  <Visual />
                </div>

                {/* Text content */}
                <div className="flex flex-1 flex-col gap-3 p-6">
                  <div className="flex items-center gap-2">
                    <span
                      className="text-xs font-bold uppercase tracking-[0.15em]"
                      style={{ color: point.accent }}
                    >
                      {point.tag}
                    </span>
                    <div className="h-px flex-1 bg-border/20" />
                  </div>
                  <h3 className="font-display text-xl font-semibold">{point.title}</h3>
                  <p className="text-sm leading-relaxed text-muted-foreground">{point.body}</p>
                </div>

                {/* Corner accent glow */}
                <div
                  className="pointer-events-none absolute -right-8 -top-8 h-32 w-32 rounded-full blur-2xl opacity-0 transition-opacity duration-500 group-hover:opacity-100"
                  style={{ backgroundColor: `${point.accent}18` }}
                />
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
}
