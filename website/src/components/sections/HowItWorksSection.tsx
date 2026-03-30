"use client";

/**
 * HowItWorksSection — Cinematic scroll-driven feature showcase.
 *
 * 6 full-viewport panels driven by a single GSAP ScrollTrigger:
 *   00 · Connect     — integrations hub
 *   01 · Today       — daily insights & quick-log
 *   02 · Data        — personalised metrics grid
 *   03 · Coach       — AI conversation
 *   04 · Progress    — goals, achievements, journal
 *   05 · Trends      — AI correlation discovery
 *
 * Each panel slides in from the right (translateX 60 → 0, opacity 0 → 1)
 * and exits to the left. A single ScrollTrigger scrubs through all 6
 * panels — no per-panel triggers, no repaints.
 */

import { useRef, useEffect } from "react";
import { useGSAP } from "@gsap/react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/dist/ScrollTrigger";
import { FaStrava, FaApple } from "react-icons/fa";
import { SiFitbit, SiGarmin } from "react-icons/si";
import { FcGoogle } from "react-icons/fc";
import {
  Zap, Calendar, LayoutGrid, MessageSquare, Target, TrendingUp,
  Moon, Footprints, Flame, Heart, Activity,
  ArrowRight, Trophy, Star, CheckCircle2, BookOpen,
  Plus, Droplets,
} from "lucide-react";

if (typeof window !== "undefined") {
  gsap.registerPlugin(ScrollTrigger);
}

// ── Feature data ─────────────────────────────────────────────
const FEATURES = [
  {
    id: "connect",
    number: "00",
    eyebrow: "Connect",
    headline: "Everything,\nconnected.",
    description:
      "One tap. Apple Health, Google Health Connect, Strava, Fitbit, and 50+ more flow in automatically. No exports, no friction, no manual entry. Ever.",
    accent: "#CFE1B9",
    glowColor: "rgba(207,225,185,0.16)",
  },
  {
    id: "today",
    number: "01",
    eyebrow: "Today Tab",
    headline: "Your day,\nat a glance.",
    description:
      "Daily insights delivered fresh every morning. Log water, meals, and workouts in one tap. Your AI surfaces what matters — before you even ask.",
    accent: "#64D2FF",
    glowColor: "rgba(100,210,255,0.13)",
  },
  {
    id: "data",
    number: "02",
    eyebrow: "Data Tab",
    headline: "Your body,\nyour data.",
    description:
      "Personalised exactly to you. Organise, customise, and own every metric. No generic dashboards — only the numbers you actually care about.",
    accent: "#BF5AF2",
    glowColor: "rgba(191,90,242,0.13)",
  },
  {
    id: "coach",
    number: "03",
    eyebrow: "Coach Tab",
    headline: "Ask\nanything.",
    description:
      "Your AI coach knows every metric, every trend, every goal. Ask why you're tired, what to eat tonight, or how to finally break your plateau.",
    accent: "#30D158",
    glowColor: "rgba(48,209,88,0.13)",
  },
  {
    id: "progress",
    number: "04",
    eyebrow: "Progress Tab",
    headline: "Goals. Wins.\nGrowth.",
    description:
      "Set goals, earn achievements, journal your journey. Progress isn't just a number — it's a story only you can write.",
    accent: "#FF9F0A",
    glowColor: "rgba(255,159,10,0.13)",
  },
  {
    id: "trends",
    number: "05",
    eyebrow: "Trends Tab",
    headline: "The AI sees\nthe patterns.",
    description:
      "Your pace was off because your sleep was short. Your recovery dipped when your nutrition did. Correlations most people never find — surfaced automatically.",
    accent: "#FF375F",
    glowColor: "rgba(255,55,95,0.13)",
  },
] as const;

type FeatureId = (typeof FEATURES)[number]["id"];
const FEATURE_COUNT = FEATURES.length;

// ── Sparkline SVG ─────────────────────────────────────────────
function Sparkline({ values, color, w = 72, h = 28 }: { values: number[]; color: string; w?: number; h?: number }) {
  const max = Math.max(...values), min = Math.min(...values);
  const range = max - min || 1;
  const pts = values
    .map((v, i) => `${(i / (values.length - 1)) * w},${h - ((v - min) / range) * (h - 2) - 1}`)
    .join(" ");
  return (
    <svg width={w} height={h} viewBox={`0 0 ${w} ${h}`} fill="none" aria-hidden="true">
      <polyline points={pts} stroke={color} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

// ── Glassmorphism card wrapper ─────────────────────────────────
function AppCard({ accent, children }: { accent: string; children: React.ReactNode }) {
  return (
    <div
      className="w-full max-w-[420px] rounded-[28px] overflow-hidden"
      style={{
        backgroundColor: "rgba(18,18,20,0.82)",
        backdropFilter: "blur(24px)",
        WebkitBackdropFilter: "blur(24px)",
        border: `1px solid ${accent}1A`,
        boxShadow: `0 40px 80px rgba(0,0,0,0.55), 0 0 0 1px ${accent}0D`,
      }}
    >
      {/* Mac-style window chrome */}
      <div
        className="flex items-center gap-2 px-4 py-3 border-b"
        style={{ borderColor: `${accent}12` }}
      >
        {["#FF5F57", "#FFBD2E", "#28C840"].map((c) => (
          <div key={c} className="w-2.5 h-2.5 rounded-full" style={{ backgroundColor: c, opacity: 0.7 }} />
        ))}
        <div className="flex-1 mx-2 h-px" style={{ backgroundColor: "rgba(240,238,233,0.05)" }} />
        <div
          className="text-[10px] font-medium px-2.5 py-0.5 rounded-md"
          style={{ backgroundColor: `${accent}12`, color: accent }}
        >
          ZuraLog
        </div>
      </div>
      <div className="p-5">{children}</div>
    </div>
  );
}

// ── Preview: Connect ──────────────────────────────────────────
function ConnectPreview({ accent }: { accent: string }) {
  const apps = [
    { Icon: FaApple, color: "#F0EEE9", label: "Apple Health" },
    { Icon: FaStrava, color: "#FC4C02", label: "Strava" },
    { Icon: SiFitbit, color: "#00B0B9", label: "Fitbit" },
    { Icon: SiGarmin, color: "#009DDC", label: "Garmin" },
    { Icon: FcGoogle, color: "", label: "Health Connect" },
  ];
  return (
    <div className="flex flex-col gap-4">
      <p className="text-[10px] font-semibold uppercase tracking-[0.2em]" style={{ color: `${accent}80` }}>
        Connected Sources
      </p>
      <div className="grid grid-cols-5 gap-2">
        {apps.map(({ Icon, color, label }) => (
          <div key={label} className="flex flex-col items-center gap-1.5">
            <div
              className="w-10 h-10 rounded-xl flex items-center justify-center"
              style={{ backgroundColor: "rgba(255,255,255,0.06)", border: "1px solid rgba(207,225,185,0.08)" }}
            >
              <Icon size={17} color={color || undefined} />
            </div>
            <span className="text-[9px] text-center leading-tight" style={{ color: "rgba(240,238,233,0.35)" }}>
              {label.split(" ")[0]}
            </span>
          </div>
        ))}
      </div>
      <div className="flex flex-col items-center gap-0.5">
        <div className="w-px h-5" style={{ background: `linear-gradient(to bottom, transparent, ${accent})` }} />
        <div
          className="w-2 h-2 rotate-45"
          style={{ borderRight: `1.5px solid ${accent}`, borderBottom: `1.5px solid ${accent}`, marginTop: -4 }}
        />
      </div>
      <div
        className="flex items-center gap-3 rounded-2xl px-4 py-3"
        style={{
          backgroundColor: `${accent}12`,
          border: `1px solid ${accent}28`,
          boxShadow: `0 0 28px ${accent}14`,
        }}
      >
        <div className="w-8 h-8 rounded-lg flex items-center justify-center" style={{ backgroundColor: `${accent}22` }}>
          <Zap size={15} style={{ color: accent }} />
        </div>
        <div className="flex-1">
          <p className="text-xs font-semibold" style={{ color: "#F0EEE9" }}>ZuraLog Hub</p>
          <p className="text-[10px]" style={{ color: "#9B9894" }}>5 sources · syncing live</p>
        </div>
        <div className="flex gap-1">
          {[0, 1, 2].map((d) => (
            <div
              key={d}
              className="w-1 h-1 rounded-full animate-pulse"
              style={{ backgroundColor: accent, animationDelay: `${d * 200}ms` }}
            />
          ))}
        </div>
      </div>
      <div className="grid grid-cols-3 gap-2">
        {[
          { label: "Apps", value: "8+" },
          { label: "Last sync", value: "2m ago" },
          { label: "Data pts", value: "14.2k" },
        ].map(({ label, value }) => (
          <div
            key={label}
            className="rounded-xl p-2.5"
            style={{ backgroundColor: "rgba(255,255,255,0.04)", border: "1px solid rgba(240,238,233,0.06)" }}
          >
            <p className="text-xs font-semibold" style={{ color: "#F0EEE9" }}>{value}</p>
            <p className="text-[9px] mt-0.5" style={{ color: "#9B9894" }}>{label}</p>
          </div>
        ))}
      </div>
    </div>
  );
}

// ── Preview: Today ────────────────────────────────────────────
function TodayPreview({ accent }: { accent: string }) {
  const metrics = [
    { icon: Footprints, label: "Steps", value: "8,432", sub: "/ 10k", color: "#30D158", pct: 84 },
    { icon: Flame, label: "Calories", value: "1,840", sub: "kcal", color: "#FF9F0A", pct: 72 },
    { icon: Moon, label: "Sleep", value: "7h 22m", sub: "last night", color: "#5E5CE6", pct: 92 },
  ];
  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-xs font-semibold" style={{ color: "#F0EEE9" }}>Good morning, Fernando</p>
          <p className="text-[10px]" style={{ color: "#9B9894" }}>Monday, 25 March · 7:42 AM</p>
        </div>
        <Calendar size={15} style={{ color: accent }} />
      </div>
      <div className="grid grid-cols-3 gap-2">
        {metrics.map(({ icon: Icon, label, value, sub, color, pct }) => (
          <div
            key={label}
            className="rounded-2xl p-3 flex flex-col items-center gap-1.5"
            style={{ backgroundColor: "rgba(255,255,255,0.05)", border: "1px solid rgba(240,238,233,0.06)" }}
          >
            <div className="relative w-9 h-9">
              <svg viewBox="0 0 36 36" className="w-full h-full -rotate-90">
                <circle cx="18" cy="18" r="14" fill="none" stroke="rgba(255,255,255,0.06)" strokeWidth="2.5" />
                <circle
                  cx="18" cy="18" r="14" fill="none" stroke={color} strokeWidth="2.5"
                  strokeLinecap="round"
                  strokeDasharray={`${2 * Math.PI * 14}`}
                  strokeDashoffset={`${2 * Math.PI * 14 * (1 - pct / 100)}`}
                />
              </svg>
              <div className="absolute inset-0 flex items-center justify-center">
                <Icon size={11} style={{ color }} />
              </div>
            </div>
            <p className="text-[11px] font-semibold text-center leading-tight" style={{ color: "#F0EEE9" }}>{value}</p>
            <p className="text-[9px] text-center" style={{ color: "#9B9894" }}>{label}</p>
          </div>
        ))}
      </div>
      <div
        className="rounded-xl px-3 py-2.5"
        style={{ backgroundColor: `${accent}0F`, border: `1px solid ${accent}1E` }}
      >
        <p className="text-[11px] leading-relaxed" style={{ color: "#F0EEE9" }}>
          <span style={{ color: accent }}>✦ </span>
          1,568 steps from your goal. A 12-minute walk would close it.
        </p>
      </div>
      <div className="flex gap-2">
        {[
          { icon: Droplets, label: "Water" },
          { icon: Flame, label: "Meal" },
          { icon: Activity, label: "Workout" },
        ].map(({ icon: Icon, label }) => (
          <button
            key={label}
            className="flex-1 flex flex-col items-center gap-1 py-2 rounded-xl"
            style={{ backgroundColor: "rgba(255,255,255,0.05)", border: "1px solid rgba(240,238,233,0.07)" }}
          >
            <Icon size={12} style={{ color: accent }} />
            <span className="text-[9px]" style={{ color: "#9B9894" }}>
              <Plus size={7} className="inline" /> {label}
            </span>
          </button>
        ))}
      </div>
    </div>
  );
}

// ── Preview: Data ─────────────────────────────────────────────
function DataPreview({ accent }: { accent: string }) {
  const tiles = [
    { label: "HRV", value: "72", unit: "ms", data: [60, 65, 58, 72, 70, 68, 72], color: accent },
    { label: "Resting HR", value: "58", unit: "bpm", data: [65, 62, 60, 58, 60, 57, 58], color: "#FF375F" },
    { label: "VO₂ Max", value: "48.2", unit: "ml/kg", data: [44, 45, 46, 47, 47, 48, 48], color: "#30D158" },
    { label: "Body Fat", value: "18.4", unit: "%", data: [20, 19.5, 19, 18.8, 18.6, 18.5, 18.4], color: "#FF9F0A" },
  ];
  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-center justify-between">
        <p className="text-[10px] font-semibold uppercase tracking-[0.2em]" style={{ color: `${accent}80` }}>
          My Data
        </p>
        <button className="flex items-center gap-1 text-[10px]" style={{ color: "#9B9894" }}>
          Customise <ArrowRight size={9} />
        </button>
      </div>
      <div className="grid grid-cols-2 gap-2.5">
        {tiles.map(({ label, value, unit, data, color }) => (
          <div
            key={label}
            className="rounded-xl p-3"
            style={{ backgroundColor: "rgba(255,255,255,0.05)", border: "1px solid rgba(240,238,233,0.06)" }}
          >
            <p className="text-[10px]" style={{ color: "#9B9894" }}>{label}</p>
            <p className="text-base font-bold leading-tight mt-0.5" style={{ color: "#F0EEE9" }}>
              {value}
              <span className="text-[9px] font-normal ml-0.5" style={{ color: "#9B9894" }}>{unit}</span>
            </p>
            <div className="mt-2">
              <Sparkline values={data} color={color} />
            </div>
          </div>
        ))}
      </div>
      <div
        className="rounded-xl px-3 py-2"
        style={{ backgroundColor: `${accent}0F`, border: `1px solid ${accent}1E` }}
      >
        <p className="text-[10px]" style={{ color: "#9B9894" }}>
          <span style={{ color: accent }}>↑ </span>HRV improved 20% this month. Recovery trending up.
        </p>
      </div>
    </div>
  );
}

// ── Preview: Coach ────────────────────────────────────────────
function CoachPreview({ accent }: { accent: string }) {
  return (
    <div className="flex flex-col gap-2.5">
      <div className="flex items-center gap-2 mb-1">
        <div
          className="w-7 h-7 rounded-full flex items-center justify-center"
          style={{ backgroundColor: `${accent}1E`, border: `1px solid ${accent}2E` }}
        >
          <MessageSquare size={12} style={{ color: accent }} />
        </div>
        <div>
          <p className="text-xs font-semibold" style={{ color: "#F0EEE9" }}>Coach</p>
          <div className="flex items-center gap-1">
            <div className="w-1.5 h-1.5 rounded-full animate-pulse" style={{ backgroundColor: accent }} />
            <p className="text-[9px]" style={{ color: "#9B9894" }}>knows all your data</p>
          </div>
        </div>
      </div>
      <div className="flex justify-end">
        <div
          className="rounded-2xl rounded-br-sm px-3.5 py-2.5 max-w-[78%]"
          style={{ backgroundColor: "rgba(207,225,185,0.14)", border: "1px solid rgba(207,225,185,0.24)" }}
        >
          <p className="text-[11px]" style={{ color: "#F0EEE9" }}>Why didn&apos;t I hit 6min/km today?</p>
        </div>
      </div>
      <div className="flex justify-start">
        <div
          className="rounded-2xl rounded-bl-sm px-3.5 py-3 max-w-[88%]"
          style={{ backgroundColor: "rgba(255,255,255,0.07)", border: "1px solid rgba(240,238,233,0.09)" }}
        >
          <p className="text-[11px] leading-relaxed" style={{ color: "#9B9894" }}>
            Your sleep last night was{" "}
            <span style={{ color: "#F0EEE9", fontWeight: 600 }}>5h 12m</span> — 2h under baseline. Short sleep
            raises cortisol and cuts neuromuscular efficiency by{" "}
            <span style={{ color: accent, fontWeight: 600 }}>8–15%</span>. Your Strava pace reflects
            exactly that.
          </p>
        </div>
      </div>
      <div className="flex justify-end">
        <div
          className="rounded-2xl rounded-br-sm px-3.5 py-2.5 max-w-[78%]"
          style={{ backgroundColor: "rgba(207,225,185,0.14)", border: "1px solid rgba(207,225,185,0.24)" }}
        >
          <p className="text-[11px]" style={{ color: "#F0EEE9" }}>What should I eat tonight?</p>
        </div>
      </div>
      <div className="flex gap-1 px-1 pt-0.5">
        {[0, 1, 2].map((d) => (
          <div
            key={d}
            className="w-1.5 h-1.5 rounded-full animate-pulse"
            style={{ backgroundColor: `${accent}55`, animationDelay: `${d * 200}ms` }}
          />
        ))}
      </div>
    </div>
  );
}

// ── Preview: Progress ─────────────────────────────────────────
function ProgressPreview({ accent }: { accent: string }) {
  return (
    <div className="flex flex-col gap-3">
      <p className="text-[10px] font-semibold uppercase tracking-[0.2em]" style={{ color: `${accent}80` }}>
        My Goals
      </p>
      <div
        className="rounded-xl p-3.5"
        style={{ backgroundColor: "rgba(255,255,255,0.05)", border: "1px solid rgba(240,238,233,0.07)" }}
      >
        <div className="flex items-center justify-between mb-3">
          <div>
            <p className="text-xs font-semibold" style={{ color: "#F0EEE9" }}>Run 5K in under 25 min</p>
            <p className="text-[10px] mt-0.5" style={{ color: "#9B9894" }}>PB: 26:42 · Target: 15 Apr</p>
          </div>
          <Target size={15} style={{ color: accent }} />
        </div>
        <div className="h-1.5 rounded-full overflow-hidden" style={{ backgroundColor: "rgba(255,255,255,0.08)" }}>
          <div className="h-full rounded-full" style={{ width: "68%", backgroundColor: accent }} />
        </div>
        <p className="mt-1.5 text-[9px]" style={{ color: "#9B9894" }}>68% · 2 training weeks left</p>
      </div>
      <div>
        <p className="text-[10px] mb-2" style={{ color: "#9B9894" }}>Recent Achievements</p>
        <div className="flex gap-2">
          {[
            { icon: Trophy, label: "First 5K", color: "#FF9F0A" },
            { icon: Star, label: "7-Day Run", color: "#FF375F" },
            { icon: CheckCircle2, label: "Goal Set", color: "#30D158" },
            { icon: Activity, label: "1K Active", color: "#5E5CE6" },
          ].map(({ icon: Icon, label, color }) => (
            <div key={label} className="flex flex-col items-center gap-1 flex-1">
              <div
                className="w-9 h-9 rounded-xl flex items-center justify-center"
                style={{ backgroundColor: `${color}14`, border: `1px solid ${color}22` }}
              >
                <Icon size={13} style={{ color }} />
              </div>
              <p className="text-[8px] text-center leading-tight" style={{ color: "#9B9894" }}>{label}</p>
            </div>
          ))}
        </div>
      </div>
      <div
        className="rounded-xl p-3"
        style={{ backgroundColor: `${accent}08`, border: `1px solid ${accent}14` }}
      >
        <div className="flex items-center gap-1.5 mb-1.5">
          <BookOpen size={10} style={{ color: accent }} />
          <p className="text-[10px] font-medium" style={{ color: accent }}>Journal · Today</p>
        </div>
        <p className="text-[10px] leading-relaxed" style={{ color: "#9B9894" }}>
          &ldquo;Felt strong on the last 800m. Breathing finally clicked. Next week push the
          interval pace...&rdquo;
        </p>
      </div>
    </div>
  );
}

// ── Preview: Trends ───────────────────────────────────────────
function TrendsPreview({ accent }: { accent: string }) {
  const sleepPts = [7.2, 5.1, 8.0, 6.5, 4.8, 7.8, 6.2];
  const pacePts  = [6.1, 7.2, 5.8, 6.5, 7.8, 6.0, 6.8];
  const w = 200, h = 52;
  const sMax = Math.max(...sleepPts), sMin = Math.min(...sleepPts);
  const pMax = Math.max(...pacePts),  pMin = Math.min(...pacePts);
  const toSvg = (arr: number[], mn: number, mx: number) =>
    arr.map((v, i) => `${(i / (arr.length - 1)) * w},${h - ((v - mn) / (mx - mn)) * (h - 4) - 2}`).join(" ");

  return (
    <div className="flex flex-col gap-3">
      <div
        className="flex items-center gap-2.5 rounded-xl px-3 py-2.5"
        style={{ backgroundColor: `${accent}10`, border: `1px solid ${accent}24` }}
      >
        <span className="text-sm">🔍</span>
        <div className="flex-1">
          <p className="text-[11px] font-semibold" style={{ color: "#F0EEE9" }}>New Correlation Found</p>
          <p className="text-[9px]" style={{ color: "#9B9894" }}>Sleep Duration ↔ 5K Pace</p>
        </div>
        <div
          className="text-[9px] font-bold px-2 py-0.5 rounded-full"
          style={{ backgroundColor: `${accent}1E`, color: accent }}
        >
          94%
        </div>
      </div>
      <div
        className="rounded-xl p-3.5"
        style={{ backgroundColor: "rgba(255,255,255,0.04)", border: "1px solid rgba(240,238,233,0.06)" }}
      >
        <div className="flex gap-4 mb-2.5">
          {[
            { color: "#64D2FF", label: "Sleep (hrs)" },
            { color: accent, label: "5K Pace (min/km)" },
          ].map(({ color, label }) => (
            <div key={label} className="flex items-center gap-1.5">
              <div className="w-3 h-0.5 rounded" style={{ backgroundColor: color }} />
              <p className="text-[9px]" style={{ color: "#9B9894" }}>{label}</p>
            </div>
          ))}
        </div>
        <svg width="100%" height={h} viewBox={`0 0 ${w} ${h}`} preserveAspectRatio="none" aria-hidden="true">
          <polyline points={toSvg(sleepPts, sMin, sMax)} fill="none" stroke="#64D2FF" strokeWidth="1.5" strokeLinecap="round" />
          <polyline points={toSvg(pacePts, pMin, pMax)} fill="none" stroke={accent} strokeWidth="1.5" strokeLinecap="round" />
        </svg>
        <p className="text-[9px] mt-1.5" style={{ color: "#9B9894" }}>Last 7 sessions</p>
      </div>
      <div
        className="rounded-xl px-3.5 py-3"
        style={{ backgroundColor: "rgba(255,255,255,0.05)", border: "1px solid rgba(240,238,233,0.07)" }}
      >
        <p className="text-[11px] leading-relaxed" style={{ color: "#9B9894" }}>
          On nights under 7 hours, your 5K pace slows by{" "}
          <span style={{ color: "#F0EEE9", fontWeight: 600 }}>45 sec/km</span> on average.
          Across <span style={{ color: accent, fontWeight: 600 }}>3 months</span> of data.
        </p>
      </div>
      <div className="flex gap-2">
        {[
          { text: "Nutrition → HRV", conf: "87%" },
          { text: "Stress → Sleep", conf: "91%" },
        ].map(({ text, conf }) => (
          <div
            key={text}
            className="flex-1 rounded-lg px-2.5 py-2"
            style={{ backgroundColor: "rgba(255,255,255,0.04)", border: "1px solid rgba(240,238,233,0.06)" }}
          >
            <p className="text-[9px] font-medium" style={{ color: "#9B9894" }}>{text}</p>
            <p className="text-[9px] font-semibold mt-0.5" style={{ color: accent }}>{conf} conf.</p>
          </div>
        ))}
      </div>
    </div>
  );
}

// ── Preview map ───────────────────────────────────────────────
const PREVIEWS: Record<FeatureId, React.ComponentType<{ accent: string }>> = {
  connect:  ConnectPreview,
  today:    TodayPreview,
  data:     DataPreview,
  coach:    CoachPreview,
  progress: ProgressPreview,
  trends:   TrendsPreview,
};

// ── Main section ──────────────────────────────────────────────
export function HowItWorksSection() {
  const sectionRef  = useRef<HTMLElement>(null);
  const pinnedRef   = useRef<HTMLDivElement>(null);
  const panelEls    = useRef<(Element | null)[]>([]);
  const glowEls     = useRef<(Element | null)[]>([]);
  const dotEls      = useRef<(Element | null)[]>([]);
  const progressRef = useRef<HTMLDivElement>(null);

  // Cache DOM refs once on mount
  useEffect(() => {
    if (!pinnedRef.current) return;
    panelEls.current = FEATURES.map((f) => pinnedRef.current!.querySelector(`[data-panel="${f.id}"]`));
    glowEls.current  = FEATURES.map((f) => pinnedRef.current!.querySelector(`[data-glow="${f.id}"]`));
    dotEls.current   = FEATURES.map((_, i) => pinnedRef.current!.querySelector(`[data-dot="${i}"]`));

    panelEls.current.forEach((el) => {
      if (el) (el as HTMLElement).style.willChange = "transform, opacity";
    });

    return () => {
      panelEls.current = [];
      glowEls.current  = [];
      dotEls.current   = [];
    };
  }, []);

  useGSAP(() => {
    if (!sectionRef.current || !pinnedRef.current) return;

    const dur = 1 / FEATURE_COUNT; // fraction of total scroll per panel

    const trigger = ScrollTrigger.create({
      trigger: sectionRef.current,
      start: "top top",
      end: () => `+=${window.innerHeight * FEATURE_COUNT}`,
      pin: pinnedRef.current,
      scrub: true,
      onUpdate(self) {
        const p = self.progress;
        const activeIdx = Math.min(Math.floor(p * FEATURE_COUNT), FEATURE_COUNT - 1);

        FEATURES.forEach((f, i) => {
          const panel = panelEls.current[i];
          const glow  = glowEls.current[i];
          const dot   = dotEls.current[i];
          if (!panel) return;

          const enterStart = i * dur;
          const enterEnd   = enterStart + dur * 0.20;
          const exitStart  = enterStart + dur * 0.80;
          const exitEnd    = enterStart + dur;

          let opacity = 0, x = 60, scale = 0.96;

          if (i === 0) {
            // First panel: visible from progress=0
            if (p <= exitStart) {
              opacity = 1; x = 0; scale = 1;
            } else if (p <= exitEnd) {
              const t = (p - exitStart) / (exitEnd - exitStart);
              opacity = 1 - t; x = -55 * t; scale = 1 - 0.04 * t;
            }
          } else if (i === FEATURE_COUNT - 1) {
            // Last panel: stays after fully visible
            if (p >= enterStart && p <= enterEnd) {
              const t = (p - enterStart) / (enterEnd - enterStart);
              opacity = t; x = 60 * (1 - t); scale = 0.96 + 0.04 * t;
            } else if (p > enterEnd) {
              opacity = 1; x = 0; scale = 1;
            }
          } else {
            if (p >= enterStart && p <= enterEnd) {
              const t = (p - enterStart) / (enterEnd - enterStart);
              opacity = t; x = 60 * (1 - t); scale = 0.96 + 0.04 * t;
            } else if (p > enterEnd && p <= exitStart) {
              opacity = 1; x = 0; scale = 1;
            } else if (p > exitStart && p <= exitEnd) {
              const t = (p - exitStart) / (exitEnd - exitStart);
              opacity = 1 - t; x = -55 * t; scale = 1 - 0.04 * t;
            }
          }

          gsap.set(panel, { opacity, x, scale });
          if (glow) gsap.set(glow, { opacity: opacity * 0.9 });

          // Animate indicator dots
          if (dot) {
            const isActive = i === activeIdx;
            (dot as HTMLElement).style.width = isActive ? "24px" : "8px";
            (dot as HTMLElement).style.backgroundColor = isActive
              ? f.accent
              : "rgba(240,238,233,0.15)";
          }
        });

        // Bottom progress line
        if (progressRef.current) {
          progressRef.current.style.transform = `scaleX(${p})`;
        }
      },
    });

    return () => { trigger.kill(); };
  }, { scope: sectionRef });

  return (
    <section
      ref={sectionRef}
      id="how-it-works-section"
      className="relative w-full"
      style={{ height: `${(FEATURE_COUNT + 1) * 100}vh` }}
    >
      {/* ── Pinned viewport ── */}
      <div
        ref={pinnedRef}
        className="w-full h-screen relative overflow-hidden"
        style={{ backgroundColor: "transparent" }}
      >
        {/* Topo texture */}
        <div
          aria-hidden="true"
          className="absolute inset-0 pointer-events-none"
          style={{
            backgroundImage: "url(/patterns/original.png)",
            backgroundSize: "600px auto",
            backgroundRepeat: "repeat",
            opacity: 0.045,
            mixBlendMode: "screen",
          }}
        />

        {/* Per-feature ambient glow orbs */}
        {FEATURES.map((f) => (
          <div
            key={f.id}
            data-glow={f.id}
            aria-hidden="true"
            className="absolute pointer-events-none"
            style={{
              right: "10%",
              top: "50%",
              transform: "translateY(-50%)",
              width: 560,
              height: 560,
              borderRadius: "50%",
              background: `radial-gradient(circle, ${f.glowColor} 0%, transparent 68%)`,
              opacity: 0,
            }}
          />
        ))}

        {/* ── Feature panels ── */}
        {FEATURES.map((f, i) => {
          const Preview = PREVIEWS[f.id as FeatureId];
          return (
            <div
              key={f.id}
              data-panel={f.id}
              className="absolute inset-0 flex items-center"
              style={{ opacity: i === 0 ? 1 : 0 }}
            >
              <div
                className="w-full mx-auto px-6 lg:px-16 grid grid-cols-1 lg:grid-cols-2 gap-10 lg:gap-20 items-center"
                style={{ maxWidth: 1280 }}
              >
                {/* ── Left: Typography ── */}
                <div className="flex flex-col gap-5">
                  {/* Ghost number — large decorative */}
                  <span
                    aria-hidden="true"
                    className="font-black leading-none select-none pointer-events-none"
                    style={{
                      fontSize: "clamp(5rem, 14vw, 11rem)",
                      color: `${f.accent}09`,
                      lineHeight: 0.88,
                      letterSpacing: "-0.04em",
                      marginBottom: "-1.2rem",
                      display: "block",
                    }}
                  >
                    {f.number}
                  </span>

                  {/* Eyebrow */}
                  <div className="flex items-center gap-3">
                    <div className="h-px w-7" style={{ backgroundColor: f.accent }} />
                    <span
                      className="text-[11px] font-semibold uppercase tracking-[0.24em]"
                      style={{ color: f.accent }}
                    >
                      {f.eyebrow}
                    </span>
                  </div>

                  {/* Headline */}
                  <h2
                    className="font-bold tracking-tight leading-[1.04]"
                    style={{
                      fontSize: "clamp(2.6rem, 4.5vw, 4.2rem)",
                      color: "#F0EEE9",
                      whiteSpace: "pre-line",
                    }}
                  >
                    {f.headline}
                  </h2>

                  {/* Description */}
                  <p
                    className="leading-relaxed"
                    style={{
                      fontSize: "clamp(0.875rem, 1.1vw, 1rem)",
                      color: "#9B9894",
                      maxWidth: "36ch",
                    }}
                  >
                    {f.description}
                  </p>

                  {/* Accent rule */}
                  <div
                    className="h-0.5 w-10 rounded-full"
                    style={{ backgroundColor: f.accent }}
                  />
                </div>

                {/* ── Right: App preview card ── */}
                <div className="hidden lg:flex justify-end">
                  <AppCard accent={f.accent}>
                    <Preview accent={f.accent} />
                  </AppCard>
                </div>
              </div>
            </div>
          );
        })}

        {/* ── Scroll indicator dots ── */}
        <div className="absolute bottom-8 left-1/2 -translate-x-1/2 z-30 flex items-center gap-2">
          {FEATURES.map((f, i) => (
            <div
              key={i}
              data-dot={i}
              className="h-1.5 rounded-full"
              style={{
                width: i === 0 ? 24 : 8,
                backgroundColor: i === 0 ? f.accent : "rgba(240,238,233,0.15)",
                transition: "width 200ms ease, background-color 200ms ease",
              }}
            />
          ))}
        </div>

        {/* ── Feature counter — bottom right ── */}
        <div className="absolute bottom-7 right-8 z-30 hidden md:flex items-center gap-1.5">
          {FEATURES.map((f, i) => (
            <span
              key={i}
              className="text-[10px] font-semibold tabular-nums"
              data-counter={i}
              style={{ color: i === 0 ? "#9B9894" : "rgba(240,238,233,0.14)" }}
            >
              {f.number}
            </span>
          ))}
        </div>

        {/* ── Bottom progress bar ── */}
        <div
          className="absolute bottom-0 inset-x-0 h-px"
          style={{ backgroundColor: "rgba(207,225,185,0.06)" }}
        >
          <div
            ref={progressRef}
            className="h-full origin-left"
            style={{ backgroundColor: "#CFE1B9", transform: "scaleX(0)" }}
          />
        </div>
      </div>
    </section>
  );
}
