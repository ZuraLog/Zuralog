/**
 * FloatingGraphics — rich UI mockup cards floating tightly around the phone.
 *
 * Each element mimics a real ZuraLog screen component: live metrics, a workout
 * summary card, an AI coach bubble, a weekly chart, a sleep ring.
 * Positioned to overlap the phone edges for a "data spilling out" feel.
 *
 * Positioning philosophy:
 *   - Elements sit 20–80% from left / 25–82% from top (close to phone center)
 *   - Parallax depth values are low (4–7 px) so cards feel glued near the phone
 */
"use client";

import { motion } from "framer-motion";

/* ─── Rich mini UI components ────────────────────────────────────────── */

/** Live HRV + readiness ring with animated arc */
function ReadinessRing() {
  return (
    <div className="flex w-[120px] flex-col items-center gap-2 rounded-2xl border border-white/10 bg-[#111]/85 p-3 backdrop-blur-md shadow-[0_8px_32px_rgba(0,0,0,0.6)]">
      <div className="relative flex h-16 w-16 items-center justify-center">
        <svg viewBox="0 0 64 64" className="absolute inset-0 h-full w-full -rotate-90">
          <circle cx="32" cy="32" r="26" fill="none" stroke="#CFE1B9" strokeWidth="5" strokeOpacity="0.15" />
          <motion.circle
            cx="32" cy="32" r="26"
            fill="none" stroke="#CFE1B9" strokeWidth="5" strokeLinecap="round"
            strokeDasharray="163"
            initial={{ strokeDashoffset: 163 }}
            animate={{ strokeDashoffset: 40 }}
            transition={{ delay: 1.4, duration: 1.2, ease: "easeOut" }}
          />
        </svg>
        <div className="z-10 text-center">
          <p className="text-xl font-bold leading-none text-white">82</p>
          <p className="mt-0.5 text-[9px] text-[#CFE1B9]/60">HRV</p>
        </div>
      </div>
      <div className="w-full">
        <p className="text-center text-[9px] font-semibold uppercase tracking-widest text-[#CFE1B9]/50">Readiness</p>
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

/** Stacked bar chart — weekly training load */
function WeeklyChart() {
  const days = [
    { label: "M", h: 55 },
    { label: "T", h: 80 },
    { label: "W", h: 40 },
    { label: "T", h: 90 },
    { label: "F", h: 65 },
    { label: "S", h: 30 },
    { label: "S", h: 70, active: true },
  ] as const;
  return (
    <div className="w-[148px] rounded-2xl border border-white/10 bg-[#111]/85 p-3 backdrop-blur-md shadow-[0_8px_32px_rgba(0,0,0,0.6)]">
      <div className="mb-2 flex items-center justify-between">
        <p className="text-[10px] font-semibold text-white/80">Weekly Load</p>
        <p className="text-[9px] text-[#CFE1B9]/60">+12%</p>
      </div>
      <div className="flex h-14 items-end gap-1">
        {days.map((d, i) => (
          <div key={i} className="flex flex-1 flex-col items-center gap-0.5">
            <motion.div
              className={`w-full rounded-sm ${"active" in d && d.active ? "bg-[#CFE1B9]" : "bg-[#CFE1B9]/35"}`}
              initial={{ height: 0 }}
              animate={{ height: `${d.h}%` }}
              transition={{ delay: 1.2 + i * 0.07, duration: 0.5, ease: "easeOut" }}
            />
            <span className={`text-[7px] ${"active" in d && d.active ? "text-[#CFE1B9]" : "text-white/30"}`}>{d.label}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

/** AI Coach message bubble */
function AICoachBubble() {
  return (
    <div className="w-[160px] rounded-2xl rounded-bl-sm border border-[#CFE1B9]/20 bg-[#0e1f0e]/90 p-3.5 backdrop-blur-md shadow-[0_8px_32px_rgba(0,0,0,0.5)]">
      <div className="mb-2 flex items-center gap-2">
        <div className="flex h-5 w-5 items-center justify-center rounded-full bg-[#CFE1B9]/20">
          <div className="h-2 w-2 rounded-full bg-[#CFE1B9]" />
        </div>
        <span className="text-[9px] font-semibold uppercase tracking-wider text-[#CFE1B9]/70">ZuraLog AI</span>
      </div>
      <p className="text-[11px] leading-relaxed text-white/75">
        Rest day today — your HRV dropped 14%. Light walk only.
      </p>
      <div className="mt-2 flex gap-1.5">
        <div className="rounded-full bg-[#CFE1B9]/15 px-2 py-0.5 text-[9px] text-[#CFE1B9]/80">Got it</div>
        <div className="rounded-full bg-white/5 px-2 py-0.5 text-[9px] text-white/40">Details</div>
      </div>
    </div>
  );
}

/** Live metric pills — steps + calories */
function MetricPills() {
  return (
    <div className="flex flex-col gap-1.5">
      <div className="flex items-center gap-2 rounded-full border border-white/10 bg-[#111]/85 px-3 py-1.5 shadow-[0_4px_16px_rgba(0,0,0,0.5)] backdrop-blur-md">
        <div className="h-2 w-2 rounded-full bg-[#CFE1B9]" />
        <span className="text-xs font-bold text-white">9,820</span>
        <span className="text-[9px] text-white/40">steps</span>
        <span className="ml-auto text-[9px] font-medium text-[#CFE1B9]/70">98%</span>
      </div>
      <div className="flex items-center gap-2 rounded-full border border-white/10 bg-[#111]/85 px-3 py-1.5 shadow-[0_4px_16px_rgba(0,0,0,0.5)] backdrop-blur-md">
        <div className="h-2 w-2 rounded-full bg-orange-400/80" />
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
    <div className="w-[136px] rounded-2xl border border-white/10 bg-[#111]/85 p-3 backdrop-blur-md shadow-[0_8px_32px_rgba(0,0,0,0.6)]">
      <div className="mb-2 flex items-center gap-1.5">
        <div className="rounded-lg bg-[#FC4C02]/20 p-1">
          <div className="h-2.5 w-2.5 rounded-sm bg-[#FC4C02]" />
        </div>
        <p className="text-[10px] font-semibold text-white/80">Morning Run</p>
      </div>
      <div className="grid grid-cols-2 gap-1.5">
        <div className="rounded-lg bg-white/5 p-1.5">
          <p className="text-[9px] text-white/40">Distance</p>
          <p className="text-xs font-bold text-white">8.2 km</p>
        </div>
        <div className="rounded-lg bg-white/5 p-1.5">
          <p className="text-[9px] text-white/40">Pace</p>
          <p className="text-xs font-bold text-white">5:12</p>
        </div>
        <div className="rounded-lg bg-white/5 p-1.5">
          <p className="text-[9px] text-white/40">Time</p>
          <p className="text-xs font-bold text-white">42:38</p>
        </div>
        <div className="rounded-lg bg-white/5 p-1.5">
          <p className="text-[9px] text-white/40">HR avg</p>
          <p className="text-xs font-bold text-white">156</p>
        </div>
      </div>
    </div>
  );
}

/* ─── Layout config ──────────────────────────────────────────────────── */

interface GraphicElement {
  id: string;
  x: number;   // % from left (centered with translate(-50%,-50%))
  y: number;   // % from top
  depth: number;
  delay: number;
  content: React.ReactNode;
}

// Phone center is ~50% / ~42% of the hero.
// Cards hug the phone left/right edges and peek out below.
const DESKTOP_ELEMENTS: GraphicElement[] = [
  { id: "readiness", x: 22,  y: 36, depth: 6, delay: 0.7, content: <ReadinessRing /> },
  { id: "workout",   x: 21,  y: 62, depth: 5, delay: 0.9, content: <WorkoutCard /> },
  { id: "weekly",    x: 79,  y: 34, depth: 7, delay: 0.8, content: <WeeklyChart /> },
  { id: "coach",     x: 79,  y: 62, depth: 5, delay: 1.0, content: <AICoachBubble /> },
  { id: "metrics",   x: 50,  y: 82, depth: 4, delay: 1.1, content: <MetricPills /> },
];

const MOBILE_ELEMENTS: GraphicElement[] = [
  { id: "weekly",  x: 82, y: 30, depth: 4, delay: 0.7, content: <WeeklyChart /> },
  { id: "coach",   x: 15, y: 58, depth: 4, delay: 0.9, content: <AICoachBubble /> },
  { id: "metrics", x: 50, y: 84, depth: 3, delay: 1.1, content: <MetricPills /> },
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
 *
 * Cards hug the phone edges to create a "data overflowing from the device" effect.
 */
export function FloatingGraphics({
  mouseX,
  mouseY,
  isMobile,
  reducedMotion = false,
}: FloatingGraphicsProps) {
  const elements = isMobile ? MOBILE_ELEMENTS : DESKTOP_ELEMENTS;

  return (
    <div className="pointer-events-none absolute inset-0 overflow-hidden">
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
