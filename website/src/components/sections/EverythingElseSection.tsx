"use client";

import { motion } from "framer-motion";
import Marquee from "react-fast-marquee";
import {
  BookOpen, Droplets, Brain, Pill, Bell, Scale, Smile, Wind,
  Thermometer, Heart, Target, Flame, Sparkles, BarChart3, Star, ListChecks,
  Footprints, Sunrise, Calendar, Snowflake, Zap, Layers, Leaf, Coffee,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";

// ── Feature data ──────────────────────────────────────────────────────────────

interface Feature {
  icon: LucideIcon;
  label: string;
  bg: string;
  fg: string;
}

const ROW_1: Feature[] = [
  { icon: BookOpen,    label: "Journal",          bg: "#F5E8CC", fg: "#96600A" },
  { icon: Droplets,    label: "Water Intake",     bg: "#CCE0F5", fg: "#1D5F96" },
  { icon: Brain,       label: "Meditation",       bg: "#D4E4D0", fg: "#344E41" },
  { icon: Pill,        label: "Supplements",      bg: "#E8D9FF", fg: "#5A2DB8" },
  { icon: Bell,        label: "Reminders",        bg: "#FFE4CC", fg: "#A84E10" },
  { icon: Scale,       label: "Weight",           bg: "#D8DEE8", fg: "#374C6A" },
  { icon: Smile,       label: "Mood",             bg: "#FFD9D9", fg: "#A02020" },
  { icon: Wind,        label: "Breathing",        bg: "#C8EEE3", fg: "#1F6B52" },
];

const ROW_2: Feature[] = [
  { icon: Thermometer, label: "Body Temp",        bg: "#F5E8CC", fg: "#96600A" },
  { icon: Heart,       label: "Blood Pressure",   bg: "#FFD9EC", fg: "#A02060" },
  { icon: Target,      label: "Goals",            bg: "#D0E8D8", fg: "#344E41" },
  { icon: Flame,       label: "Streaks",          bg: "#FFE4CC", fg: "#A84E10" },
  { icon: Sparkles,    label: "AI Insights",      bg: "#E8D9FF", fg: "#5A2DB8" },
  { icon: BarChart3,   label: "Weekly Reports",   bg: "#D8DEE8", fg: "#374C6A" },
  { icon: Star,        label: "Gratitude",        bg: "#FFF4CC", fg: "#8C6C00" },
  { icon: ListChecks,  label: "Habits",           bg: "#D4E4D0", fg: "#344E41" },
];

const ROW_3: Feature[] = [
  { icon: Footprints,  label: "Steps",            bg: "#D0E8D8", fg: "#344E41" },
  { icon: Sunrise,     label: "Morning Routine",  bg: "#FFF4CC", fg: "#8C6C00" },
  { icon: Calendar,    label: "Cycle Tracking",   bg: "#FFD9EC", fg: "#A02060" },
  { icon: Snowflake,   label: "Cold Exposure",    bg: "#CCE0F5", fg: "#1D5F96" },
  { icon: Zap,         label: "Energy Levels",    bg: "#F5E8CC", fg: "#96600A" },
  { icon: Layers,      label: "Body Composition", bg: "#D4E4D0", fg: "#344E41" },
  { icon: Leaf,        label: "Mindfulness",      bg: "#C8EEE3", fg: "#1F6B52" },
  { icon: Coffee,      label: "Caffeine",         bg: "#F0E4D8", fg: "#7A4A20" },
];

// ── Pill ──────────────────────────────────────────────────────────────────────

function FeaturePill({ f }: { f: Feature }) {
  const Icon = f.icon;
  return (
    <div
      className="inline-flex items-center gap-3 rounded-full bg-white mx-1.5"
      style={{
        padding: "9px 20px 9px 9px",
        boxShadow:
          "0 1px 4px rgba(22,22,24,0.07), 0 0 0 1px rgba(22,22,24,0.055)",
      }}
    >
      <span
        className="flex items-center justify-center rounded-[9px] flex-shrink-0"
        style={{ width: 34, height: 34, background: f.bg }}
      >
        <Icon size={16} color={f.fg} strokeWidth={2} />
      </span>
      <span
        className="font-semibold text-[#161618] whitespace-nowrap"
        style={{ fontSize: 14, letterSpacing: "-0.01em" }}
      >
        {f.label}
      </span>
    </div>
  );
}

// ── Section ───────────────────────────────────────────────────────────────────

// The background color to blend gradient fades into — matches the page
const GRADIENT_COLOR = "#F0EEE9";

export function EverythingElseSection() {
  return (
    <section className="relative py-24 md:py-32 font-jakarta overflow-hidden">

      {/* Section header */}
      <motion.div
        initial={{ opacity: 0, y: 24 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true }}
        transition={{ duration: 0.6 }}
        className="px-6 md:px-12 mb-16 md:mb-20"
      >
        <div className="mx-auto max-w-6xl">
          <span className="inline-flex items-center gap-2 rounded-full border border-[#344E41]/30 bg-[#344E41]/[0.07] px-4 py-1.5 text-xs font-semibold uppercase tracking-widest text-[#344E41] mb-6">
            <span className="h-1.5 w-1.5 rounded-full bg-[#344E41]" />
            Everything else
          </span>

          <h2
            className="font-bold uppercase tracking-tighter leading-[0.9] text-[#161618]"
            style={{ fontSize: "clamp(2.5rem, 5vw, 5.5rem)" }}
          >
            And so much{" "}
            <span
              className="ds-pattern-text"
              style={{ backgroundImage: "var(--ds-pattern-sage)" }}
            >
              more.
            </span>
          </h2>

          <p className="mt-5 text-lg md:text-xl text-[#6B6864] max-w-xl">
            The details that add up. Dozens of ways to track every corner of
            your health — all in one place.
          </p>
        </div>
      </motion.div>

      {/* Marquee rows — autoFill clones children until the row fills the screen */}
      <div className="flex flex-col gap-3">
        <Marquee autoFill direction="left"  speed={35} gradient gradientColor={GRADIENT_COLOR} gradientWidth={80}>
          {ROW_1.map((f) => <FeaturePill key={f.label} f={f} />)}
        </Marquee>

        <Marquee autoFill direction="right" speed={28} gradient gradientColor={GRADIENT_COLOR} gradientWidth={80}>
          {ROW_2.map((f) => <FeaturePill key={f.label} f={f} />)}
        </Marquee>

        <Marquee autoFill direction="left"  speed={42} gradient gradientColor={GRADIENT_COLOR} gradientWidth={80}>
          {ROW_3.map((f) => <FeaturePill key={f.label} f={f} />)}
        </Marquee>
      </div>

    </section>
  );
}
