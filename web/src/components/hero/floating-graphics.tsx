/**
 * FloatingGraphics — decorative UI elements floating around the phone in the hero.
 *
 * These represent ZuraLog app UI: bar charts, activity cards, metric pills,
 * AI chat bubbles, dashboard grids. Positioned as HTML overlays for crisp
 * rendering and easy maintenance.
 *
 * Each element has:
 *   - A fixed % position relative to the hero container
 *   - A depth multiplier that scales mouse parallax offset
 *   - A staggered entrance animation
 */
"use client";

import { motion } from "framer-motion";

/* ─── Mini UI mockup components ─────────────────────────────────────── */

/**
 * BarChart — miniature animated bar chart card.
 *
 * Bars animate upward on mount with staggered delays, using sage green fills.
 */
function BarChart() {
  const bars = [
    { h: "60%", delay: 0 },
    { h: "40%", delay: 0.08 },
    { h: "75%", delay: 0.16 },
    { h: "35%", delay: 0.24 },
    { h: "55%", delay: 0.32 },
  ];
  return (
    <div className="flex h-20 w-28 items-end gap-1 rounded-xl border border-white/[0.08] bg-[#1C1C1E]/80 p-3 backdrop-blur-sm">
      {bars.map((bar, i) => (
        <motion.div
          key={i}
          initial={{ height: 0 }}
          animate={{ height: bar.h }}
          transition={{ delay: 1.2 + bar.delay, duration: 0.5, ease: "easeOut" }}
          className="flex-1 rounded-sm bg-[#CFE1B9]/70"
        />
      ))}
    </div>
  );
}

/**
 * ActivityCard — miniature activity log card with skeleton rows.
 *
 * Mimics a ZuraLog recent-activity entry with avatar, title, and subtitle lines.
 */
function ActivityCard() {
  return (
    <div className="flex w-36 flex-col gap-1.5 rounded-xl border border-white/[0.08] bg-[#1C1C1E]/80 p-3 backdrop-blur-sm">
      <div className="h-2 w-16 rounded-full bg-white/20" />
      <div className="h-2 w-24 rounded-full bg-[#CFE1B9]/40" />
      <div className="mt-1 flex gap-2">
        <div className="h-5 w-5 rounded-full bg-[#CFE1B9]/30" />
        <div className="flex flex-col gap-1">
          <div className="h-1.5 w-12 rounded-full bg-white/15" />
          <div className="h-1.5 w-8 rounded-full bg-white/10" />
        </div>
      </div>
    </div>
  );
}

/**
 * MetricPill — compact pill showing a step-count metric.
 *
 * Represents a live health metric badge from the ZuraLog dashboard.
 */
function MetricPill() {
  return (
    <div className="flex items-center gap-2 rounded-full border border-white/[0.08] bg-[#1C1C1E]/80 px-4 py-2 backdrop-blur-sm">
      <div className="h-3 w-3 rounded-full bg-[#CFE1B9]/60" />
      <span className="text-xs font-semibold text-white/70">8,432</span>
      <span className="text-[10px] text-[#CFE1B9]/60">steps</span>
    </div>
  );
}

/**
 * AIChatBubble — small AI response bubble mimicking ZuraLog's AI chat.
 *
 * Uses a dark-green tinted background to distinguish AI voice from data cards.
 */
function AIChatBubble() {
  return (
    <div className="w-40 rounded-2xl rounded-bl-sm border border-[#CFE1B9]/15 bg-[#1C2E1C]/80 p-3 backdrop-blur-sm">
      <div className="mb-1.5 flex items-center gap-1.5">
        <div className="h-2 w-2 rounded-full bg-[#CFE1B9]/80" />
        <span className="text-[9px] font-medium text-[#CFE1B9]/70">ZuraLog AI</span>
      </div>
      <div className="space-y-1">
        <div className="h-1.5 w-full rounded-full bg-white/[0.12]" />
        <div className="h-1.5 w-3/4 rounded-full bg-white/[0.08]" />
      </div>
    </div>
  );
}

/**
 * DashboardGrid — 2×2 grid of tiles mimicking the ZuraLog dashboard overview.
 *
 * Two tiles use sage green tints; two use neutral white-alpha fills.
 */
function DashboardGrid() {
  return (
    <div className="grid h-20 w-24 grid-cols-2 gap-1 rounded-xl border border-white/[0.08] bg-[#1C1C1E]/80 p-2 backdrop-blur-sm">
      <div className="rounded-md bg-[#CFE1B9]/20" />
      <div className="rounded-md bg-white/[0.08]" />
      <div className="rounded-md bg-white/[0.06]" />
      <div className="rounded-md bg-[#CFE1B9]/15" />
    </div>
  );
}

/* ─── Element layout configuration ──────────────────────────────────── */

interface GraphicElement {
  id: string;
  /** % from left edge of the hero container */
  x: number;
  /** % from top edge of the hero container */
  y: number;
  /** Mouse parallax multiplier — higher = more movement = feels closer to viewer */
  depth: number;
  /** Framer Motion entrance delay in seconds */
  delay: number;
  content: React.ReactNode;
}

const DESKTOP_ELEMENTS: GraphicElement[] = [
  { id: "bar-chart",  x: 18, y: 38, depth: 8,  delay: 0.6, content: <BarChart /> },
  { id: "activity",   x: 72, y: 28, depth: 10, delay: 0.8, content: <ActivityCard /> },
  { id: "metric",     x: 28, y: 68, depth: 6,  delay: 1.0, content: <MetricPill /> },
  { id: "chat",       x: 75, y: 62, depth: 12, delay: 0.9, content: <AIChatBubble /> },
  { id: "dashboard",  x: 15, y: 22, depth: 5,  delay: 1.1, content: <DashboardGrid /> },
];

const MOBILE_ELEMENTS: GraphicElement[] = [
  { id: "bar-chart", x: 12, y: 35, depth: 5, delay: 0.6, content: <BarChart /> },
  { id: "metric",    x: 80, y: 65, depth: 5, delay: 0.8, content: <MetricPill /> },
  { id: "chat",      x: 78, y: 30, depth: 6, delay: 1.0, content: <AIChatBubble /> },
];

/* ─── Component ──────────────────────────────────────────────────────── */

interface FloatingGraphicsProps {
  /** Normalized mouse X in range [-1, 1] */
  mouseX: number;
  /** Normalized mouse Y in range [-1, 1] */
  mouseY: number;
  /** Render mobile-optimised subset of elements when true */
  isMobile: boolean;
}

/**
 * FloatingGraphics renders decorative ZuraLog UI mockups as HTML overlays.
 *
 * Elements are absolutely positioned within the hero container and react to
 * mouse movement via parallax. Each element animates in from below on mount.
 *
 * @param mouseX - Normalized horizontal mouse position [-1, 1]
 * @param mouseY - Normalized vertical mouse position [-1, 1]
 * @param isMobile - When true, renders the reduced mobile element set
 */
export function FloatingGraphics({ mouseX, mouseY, isMobile }: FloatingGraphicsProps) {
  const elements = isMobile ? MOBILE_ELEMENTS : DESKTOP_ELEMENTS;

  return (
    <div className="pointer-events-none absolute inset-0 overflow-hidden">
      {elements.map((el) => (
        <motion.div
          key={el.id}
          initial={{ opacity: 0, scale: 0.8, y: 20 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          transition={{ delay: el.delay, duration: 0.7, ease: "easeOut" }}
          className="absolute"
          style={{
            left: `${el.x}%`,
            top: `${el.y}%`,
            transform: `translate(-50%, -50%) translate(${mouseX * el.depth}px, ${-mouseY * el.depth}px)`,
            willChange: "transform",
          }}
        >
          {el.content}
        </motion.div>
      ))}
    </div>
  );
}
