/**
 * FloatingGraphics — rich ZuraLog UI mockup cards floating around the phone.
 *
 * Positioned to partially overlap the phone edges ("data spilling out" effect).
 * Cards are tightly clustered near center so they clearly surround the phone model.
 */
"use client";

import { motion } from "framer-motion";

/* ─── Rich mini UI components ────────────────────────────────────────── */

/** Live HRV + readiness ring with animated arc */
function ReadinessRing() {
  return (
    <div className="flex w-[116px] flex-col items-center gap-2 rounded-2xl border border-white/10 bg-[#0d0d0d]/90 p-3 backdrop-blur-md shadow-[0_8px_32px_rgba(0,0,0,0.7)]">
      <div className="relative flex h-14 w-14 items-center justify-center">
        <svg viewBox="0 0 56 56" className="absolute inset-0 h-full w-full -rotate-90">
          <circle cx="28" cy="28" r="22" fill="none" stroke="#CFE1B9" strokeWidth="4" strokeOpacity="0.12" />
          <motion.circle
            cx="28" cy="28" r="22"
            fill="none" stroke="#CFE1B9" strokeWidth="4" strokeLinecap="round"
            strokeDasharray="138"
            initial={{ strokeDashoffset: 138 }}
            animate={{ strokeDashoffset: 34 }}
            transition={{ delay: 1.4, duration: 1.2, ease: "easeOut" }}
          />
        </svg>
        <div className="z-10 text-center">
          <p className="text-lg font-bold leading-none text-white">82</p>
          <p className="mt-0.5 text-[8px] text-[#CFE1B9]/60">HRV</p>
        </div>
      </div>
      <div className="w-full">
        <p className="text-center text-[8px] font-semibold uppercase tracking-widest text-[#CFE1B9]/50">Readiness</p>
        <div className="mt-1 h-1 w-full rounded-full bg-white/10">
          <motion.div
            className="h-full rounded-full bg-[#CFE1B9]"
            initial={{ width: 0 }}
            animate={{ width: "75%" }}
            transition={{ delay: 1.6, duration: 0.8, ease: "easeOut" }}
          />
        </div>
      </div>
    </div>
  );
}

/** Weekly training load bar chart — bars use pixel heights so they render correctly */
function WeeklyChart() {
  // Max bar height in pixels (parent container is 48px)
  const MAX_H = 44;
  const days = [
    { label: "M", pct: 55 },
    { label: "T", pct: 80 },
    { label: "W", pct: 40 },
    { label: "T", pct: 90 },
    { label: "F", pct: 65 },
    { label: "S", pct: 30 },
    { label: "S", pct: 70, active: true },
  ] as const;

  return (
    <div className="w-[140px] rounded-2xl border border-white/10 bg-[#0d0d0d]/90 p-3 backdrop-blur-md shadow-[0_8px_32px_rgba(0,0,0,0.7)]">
      <div className="mb-2 flex items-center justify-between">
        <p className="text-[10px] font-semibold text-white/80">Weekly Load</p>
        <p className="text-[9px] text-[#CFE1B9]/70">+12%</p>
      </div>
      {/* Fixed-height container so bars animate from bottom upward */}
      <div className="flex items-end gap-[3px]" style={{ height: MAX_H }}>
        {days.map((d, i) => (
          <div key={i} className="flex flex-1 flex-col items-center justify-end gap-[2px]" style={{ height: MAX_H }}>
            <motion.div
              className={`w-full rounded-sm ${("active" in d && d.active) ? "bg-[#CFE1B9]" : "bg-[#CFE1B9]/35"}`}
              initial={{ height: 0 }}
              animate={{ height: Math.round((d.pct / 100) * MAX_H) }}
              transition={{ delay: 1.2 + i * 0.07, duration: 0.5, ease: "easeOut" }}
            />
          </div>
        ))}
      </div>
      {/* Day labels row */}
      <div className="mt-1 flex items-center gap-[3px]">
        {days.map((d, i) => (
          <span
            key={i}
            className={`flex-1 text-center text-[7px] ${("active" in d && d.active) ? "text-[#CFE1B9]" : "text-white/30"}`}
          >
            {d.label}
          </span>
        ))}
      </div>
    </div>
  );
}

/** AI Coach message bubble */
function AICoachBubble() {
  return (
    <div className="w-[152px] rounded-2xl rounded-bl-sm border border-[#CFE1B9]/15 bg-[#0b170b]/92 p-3 backdrop-blur-md shadow-[0_8px_32px_rgba(0,0,0,0.6)]">
      <div className="mb-2 flex items-center gap-1.5">
        <div className="flex h-4 w-4 items-center justify-center rounded-full bg-[#CFE1B9]/20">
          <div className="h-1.5 w-1.5 rounded-full bg-[#CFE1B9]" />
        </div>
        <span className="text-[8px] font-semibold uppercase tracking-wider text-[#CFE1B9]/70">ZuraLog AI</span>
      </div>
      <p className="text-[10px] leading-relaxed text-white/75">
        Rest day today — HRV dropped 14%. Light walk only.
      </p>
      <div className="mt-2 flex gap-1.5">
        <div className="rounded-full bg-[#CFE1B9]/15 px-2 py-0.5 text-[8px] text-[#CFE1B9]/80">Got it</div>
        <div className="rounded-full bg-white/5 px-2 py-0.5 text-[8px] text-white/40">Details</div>
      </div>
    </div>
  );
}

/** Live metric pills — steps + calories */
function MetricPills() {
  return (
    <div className="flex flex-col gap-1.5">
      <div className="flex items-center gap-2 rounded-full border border-white/10 bg-[#0d0d0d]/90 px-3 py-1.5 shadow-[0_4px_16px_rgba(0,0,0,0.6)] backdrop-blur-md">
        <div className="h-1.5 w-1.5 rounded-full bg-[#CFE1B9]" />
        <span className="text-xs font-bold text-white">9,820</span>
        <span className="text-[9px] text-white/40">steps</span>
        <span className="ml-auto text-[9px] font-medium text-[#CFE1B9]/70">98%</span>
      </div>
      <div className="flex items-center gap-2 rounded-full border border-white/10 bg-[#0d0d0d]/90 px-3 py-1.5 shadow-[0_4px_16px_rgba(0,0,0,0.6)] backdrop-blur-md">
        <div className="h-1.5 w-1.5 rounded-full bg-orange-400/80" />
        <span className="text-xs font-bold text-white">1,840</span>
        <span className="text-[9px] text-white/40">kcal</span>
        <span className="ml-auto text-[9px] font-medium text-orange-400/70">78%</span>
      </div>
    </div>
  );
}

/** Workout summary card */
function WorkoutCard() {
  return (
    <div className="w-[130px] rounded-2xl border border-white/10 bg-[#0d0d0d]/90 p-2.5 backdrop-blur-md shadow-[0_8px_32px_rgba(0,0,0,0.7)]">
      <div className="mb-2 flex items-center gap-1.5">
        <div className="rounded-lg bg-[#FC4C02]/20 p-1">
          <div className="h-2 w-2 rounded-sm bg-[#FC4C02]" />
        </div>
        <p className="text-[9px] font-semibold text-white/80">Morning Run</p>
      </div>
      <div className="grid grid-cols-2 gap-1">
        <div className="rounded-lg bg-white/5 p-1">
          <p className="text-[8px] text-white/40">Distance</p>
          <p className="text-[10px] font-bold text-white">8.2 km</p>
        </div>
        <div className="rounded-lg bg-white/5 p-1">
          <p className="text-[8px] text-white/40">Pace</p>
          <p className="text-[10px] font-bold text-white">5:12</p>
        </div>
        <div className="rounded-lg bg-white/5 p-1">
          <p className="text-[8px] text-white/40">Time</p>
          <p className="text-[10px] font-bold text-white">42:38</p>
        </div>
        <div className="rounded-lg bg-white/5 p-1">
          <p className="text-[8px] text-white/40">HR avg</p>
          <p className="text-[10px] font-bold text-white">156</p>
        </div>
      </div>
    </div>
  );
}

/* ─── Layout config ──────────────────────────────────────────────────── */

interface GraphicElement {
  id: string;
  /** % from left, centered with translate(-50%,-50%) */
  x: number;
  /** % from top */
  y: number;
  /** Parallax depth multiplier (px per normalized mouse unit) */
  depth: number;
  delay: number;
  content: React.ReactNode;
}

// Phone model center sits at approximately 50% / 42% of the hero viewport.
// Target: cards tightly clustered around phone edges per reference Image 2.
// Left cards: x ~38-40% (right edge overlaps phone left bezel ~43%)
// Right cards: x ~60-62% (left edge overlaps phone right bezel ~57%)
// Vertical: top row y~28%, bottom row y~55%, metrics y~62%
const DESKTOP_ELEMENTS: GraphicElement[] = [
  { id: "readiness", x: 38, y: 28, depth: 6, delay: 0.7, content: <ReadinessRing /> },
  { id: "workout",   x: 38, y: 55, depth: 5, delay: 0.9, content: <WorkoutCard /> },
  { id: "weekly",    x: 62, y: 28, depth: 7, delay: 0.8, content: <WeeklyChart /> },
  { id: "coach",     x: 62, y: 52, depth: 5, delay: 1.0, content: <AICoachBubble /> },
  { id: "metrics",   x: 50, y: 62, depth: 4, delay: 1.1, content: <MetricPills /> },
];

/* ─── Component ──────────────────────────────────────────────────────── */

interface FloatingGraphicsProps {
  mouseX: number;
  mouseY: number;
  isMobile: boolean;
  reducedMotion?: boolean;
}

/**
 * FloatingGraphics renders rich ZuraLog UI mockup cards as HTML overlays.
 * Cards overlap the phone edges to create a "data spilling out of the device" effect.
 */
export function FloatingGraphics({
  mouseX,
  mouseY,
  isMobile,
  reducedMotion = false,
}: FloatingGraphicsProps) {
  // On mobile, integration cards provide enough visual context — skip floating graphics
  if (isMobile) return null;

  const elements = DESKTOP_ELEMENTS;

  return (
    <div className="pointer-events-none absolute inset-0 overflow-visible">
      {elements.map((el) => (
        <div
          key={el.id}
          className="absolute"
          style={{
            left: `${el.x}%`,
            top: `${el.y}%`,
            transform: "translate(-50%, -50%)",
          }}
        >
          <motion.div
            initial={reducedMotion ? false : { opacity: 0, scale: 0.85, y: 16 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            transition={
              reducedMotion
                ? { duration: 0 }
                : { delay: el.delay, duration: 0.6, ease: "easeOut" }
            }
            style={{
              x: reducedMotion ? 0 : mouseX * el.depth,
              y: reducedMotion ? 0 : -mouseY * el.depth,
              willChange: "transform",
            }}
          >
            {el.content}
          </motion.div>
        </div>
      ))}
    </div>
  );
}
