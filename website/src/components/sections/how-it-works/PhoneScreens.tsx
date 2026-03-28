"use client";

import React from "react";
import {
  Zap, Moon, Heart, Flame, Footprints, Activity,
  Droplets, Dumbbell, Brain, TrendingUp, MessageCircle,
  Target, Trophy, BookOpen, Sparkles, Shield,
} from "lucide-react";
import { FaApple } from "react-icons/fa";
import { SiGooglefit } from "react-icons/si";

/* ─── Connect ─────────────────────────────────────────────── */
function ConnectScreen() {
  return (
    <div className="flex flex-col gap-3 px-4 pb-4 pt-2">
      <p className="text-center text-[10px] font-semibold" style={{ color: "#CFE1B9" }}>
        Connect Your Apps
      </p>
      <div className="grid grid-cols-2 gap-2">
        {[
          { icon: <FaApple size={18} />, name: "Apple Health", color: "#F0EEE9" },
          { icon: <SiGooglefit size={18} />, name: "Health Connect", color: "#4285F4" },
          { icon: <Zap size={18} />, name: "Strava", color: "#FC4C02" },
          { icon: <Activity size={18} />, name: "Fitbit", color: "#00B0B9" },
        ].map((app) => (
          <div
            key={app.name}
            className="flex flex-col items-center gap-1.5 rounded-2xl py-3"
            style={{ backgroundColor: "rgba(255,255,255,0.05)", border: "1px solid rgba(207,225,185,0.08)" }}
          >
            <div style={{ color: app.color }}>{app.icon}</div>
            <span className="text-[8px] font-medium" style={{ color: "#9B9894" }}>{app.name}</span>
          </div>
        ))}
      </div>
      <div
        className="rounded-full py-2 text-center text-[10px] font-semibold"
        style={{ backgroundColor: "#CFE1B9", color: "#1A2E22" }}
      >
        Connect Apps
      </div>
      <div className="flex flex-wrap justify-center gap-1">
        {["Sleep", "Heart", "Steps", "Calories"].map((tag) => (
          <span
            key={tag}
            className="rounded-full px-2 py-0.5 text-[7px] font-medium"
            style={{ backgroundColor: "rgba(207,225,185,0.1)", color: "#CFE1B9" }}
          >
            {tag}
          </span>
        ))}
      </div>
    </div>
  );
}

/* ─── Today ───────────────────────────────────────────────── */
function TodayScreen() {
  return (
    <div className="flex flex-col gap-2.5 px-4 pb-4 pt-2">
      <p className="text-[12px] font-bold" style={{ color: "#F0EEE9" }}>Good morning</p>
      {/* Health score card */}
      <div className="rounded-2xl p-3" style={{ backgroundColor: "rgba(207,225,185,0.08)", border: "1px solid rgba(207,225,185,0.12)" }}>
        <p className="text-[8px] font-semibold uppercase tracking-wider" style={{ color: "#9B9894" }}>Health Score</p>
        <p className="text-[22px] font-bold" style={{ color: "#CFE1B9" }}>82</p>
        <div className="mt-1 h-1.5 rounded-full" style={{ backgroundColor: "rgba(207,225,185,0.15)" }}>
          <div className="h-full rounded-full" style={{ width: "82%", backgroundColor: "#CFE1B9" }} />
        </div>
      </div>
      {/* Quick log buttons */}
      <div className="flex gap-1.5">
        {[
          { icon: Droplets, label: "Water", color: "#64D2FF" },
          { icon: Flame, label: "Calories", color: "#FF9F0A" },
          { icon: Dumbbell, label: "Workout", color: "#30D158" },
        ].map((item) => (
          <div
            key={item.label}
            className="flex flex-1 flex-col items-center gap-1 rounded-xl py-2"
            style={{ backgroundColor: `${item.color}10`, border: `1px solid ${item.color}20` }}
          >
            <item.icon size={12} style={{ color: item.color }} />
            <span className="text-[7px] font-medium" style={{ color: "#9B9894" }}>{item.label}</span>
          </div>
        ))}
      </div>
      {/* Insight card */}
      <div className="rounded-xl p-2.5" style={{ backgroundColor: "rgba(94,92,230,0.08)", border: "1px solid rgba(94,92,230,0.15)" }}>
        <div className="flex items-center gap-1.5">
          <Moon size={10} style={{ color: "#5E5CE6" }} />
          <p className="text-[8px] font-medium" style={{ color: "#F0EEE9" }}>Sleep was 8h 12m — above your average</p>
        </div>
      </div>
    </div>
  );
}

/* ─── Data ────────────────────────────────────────────────── */
function DataScreen() {
  return (
    <div className="flex flex-col gap-2 px-4 pb-4 pt-2">
      <p className="text-[10px] font-semibold" style={{ color: "#F0EEE9" }}>Your Data</p>
      <div className="grid grid-cols-2 gap-1.5">
        {[
          { label: "Steps", value: "8,432", icon: Footprints, color: "#30D158" },
          { label: "Heart Rate", value: "62 bpm", icon: Heart, color: "#FF375F" },
          { label: "Sleep", value: "7h 42m", icon: Moon, color: "#5E5CE6" },
          { label: "Calories", value: "1,840", icon: Flame, color: "#FF9F0A" },
        ].map((metric) => (
          <div
            key={metric.label}
            className="rounded-xl p-2.5"
            style={{ backgroundColor: "rgba(255,255,255,0.04)", border: "1px solid rgba(240,238,233,0.06)" }}
          >
            <metric.icon size={10} style={{ color: metric.color }} />
            <p className="mt-1 text-[12px] font-bold" style={{ color: "#F0EEE9" }}>{metric.value}</p>
            <p className="text-[7px]" style={{ color: "#9B9894" }}>{metric.label}</p>
          </div>
        ))}
      </div>
      {/* Mini chart placeholder */}
      <div className="rounded-xl p-2.5" style={{ backgroundColor: "rgba(255,255,255,0.04)", border: "1px solid rgba(240,238,233,0.06)" }}>
        <p className="mb-1.5 text-[8px] font-medium" style={{ color: "#9B9894" }}>Weekly Steps</p>
        <div className="flex items-end gap-1" style={{ height: 32 }}>
          {[60, 80, 45, 90, 70, 85, 75].map((h, i) => (
            <div
              key={i}
              className="flex-1 rounded-sm"
              style={{ height: `${h}%`, backgroundColor: i === 6 ? "#CFE1B9" : "rgba(207,225,185,0.2)" }}
            />
          ))}
        </div>
      </div>
    </div>
  );
}

/* ─── Coach ───────────────────────────────────────────────── */
function CoachScreen() {
  return (
    <div className="flex flex-col gap-2 px-4 pb-4 pt-2">
      <div className="flex items-center gap-1.5">
        <div className="flex h-5 w-5 items-center justify-center rounded-full" style={{ backgroundColor: "#CFE1B9" }}>
          <Sparkles size={10} style={{ color: "#1A2E22" }} />
        </div>
        <p className="text-[10px] font-semibold" style={{ color: "#F0EEE9" }}>Health Coach</p>
      </div>
      {/* Chat messages */}
      <div className="flex flex-col gap-1.5">
        <div className="ml-auto max-w-[80%] rounded-2xl rounded-br-md px-2.5 py-1.5" style={{ backgroundColor: "rgba(207,225,185,0.15)", border: "1px solid rgba(207,225,185,0.25)" }}>
          <p className="text-[8px]" style={{ color: "#F0EEE9" }}>Why am I not losing weight?</p>
        </div>
        <div className="max-w-[85%] rounded-2xl rounded-bl-md px-2.5 py-1.5" style={{ backgroundColor: "rgba(255,255,255,0.06)", border: "1px solid rgba(240,238,233,0.08)" }}>
          <p className="text-[8px] leading-relaxed" style={{ color: "#F0EEE9" }}>
            Your calorie data shows a 230 cal surplus. Evening snacking is the main factor. Plus runs dropped from 8 to 3 this month.
          </p>
        </div>
        <div className="ml-auto max-w-[80%] rounded-2xl rounded-br-md px-2.5 py-1.5" style={{ backgroundColor: "rgba(207,225,185,0.15)", border: "1px solid rgba(207,225,185,0.25)" }}>
          <p className="text-[8px]" style={{ color: "#F0EEE9" }}>What should I change?</p>
        </div>
        <div className="max-w-[85%] rounded-2xl rounded-bl-md px-2.5 py-1.5" style={{ backgroundColor: "rgba(255,255,255,0.06)", border: "1px solid rgba(240,238,233,0.08)" }}>
          <p className="text-[8px] leading-relaxed" style={{ color: "#F0EEE9" }}>
            Cut 250 cals — skip the post-dinner snack — and get back to 5+ runs/week.
          </p>
        </div>
      </div>
    </div>
  );
}

/* ─── Progress ────────────────────────────────────────────── */
function ProgressScreen() {
  return (
    <div className="flex flex-col gap-2.5 px-4 pb-4 pt-2">
      <p className="text-[10px] font-semibold" style={{ color: "#F0EEE9" }}>Your Progress</p>
      {/* Goal card */}
      <div className="rounded-xl p-2.5" style={{ backgroundColor: "rgba(48,209,88,0.08)", border: "1px solid rgba(48,209,88,0.15)" }}>
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-1.5">
            <Target size={10} style={{ color: "#30D158" }} />
            <p className="text-[8px] font-medium" style={{ color: "#F0EEE9" }}>Run 5x this week</p>
          </div>
          <p className="text-[9px] font-bold" style={{ color: "#30D158" }}>3/5</p>
        </div>
        <div className="mt-1.5 h-1 rounded-full" style={{ backgroundColor: "rgba(48,209,88,0.15)" }}>
          <div className="h-full rounded-full" style={{ width: "60%", backgroundColor: "#30D158" }} />
        </div>
      </div>
      {/* Achievement */}
      <div className="flex items-center gap-2 rounded-xl p-2.5" style={{ backgroundColor: "rgba(255,159,10,0.08)", border: "1px solid rgba(255,159,10,0.15)" }}>
        <Trophy size={14} style={{ color: "#FF9F0A" }} />
        <div>
          <p className="text-[8px] font-semibold" style={{ color: "#F0EEE9" }}>7-Day Streak!</p>
          <p className="text-[7px]" style={{ color: "#9B9894" }}>Logged every day this week</p>
        </div>
      </div>
      {/* Journal entry */}
      <div className="rounded-xl p-2.5" style={{ backgroundColor: "rgba(255,255,255,0.04)", border: "1px solid rgba(240,238,233,0.06)" }}>
        <div className="flex items-center gap-1.5 mb-1">
          <BookOpen size={9} style={{ color: "#CFE1B9" }} />
          <p className="text-[8px] font-medium" style={{ color: "#9B9894" }}>Today&apos;s Journal</p>
        </div>
        <p className="text-[7px] leading-relaxed" style={{ color: "#F0EEE9" }}>
          Feeling good after morning run. Energy levels are up this week...
        </p>
      </div>
    </div>
  );
}

/* ─── Trends ──────────────────────────────────────────────── */
function TrendsScreen() {
  return (
    <div className="flex flex-col gap-2 px-4 pb-4 pt-2">
      <div className="flex items-center gap-1.5">
        <Brain size={12} style={{ color: "#CFE1B9" }} />
        <p className="text-[10px] font-semibold" style={{ color: "#F0EEE9" }}>AI Trends</p>
      </div>
      {[
        {
          text: "Sleep < 7hrs → pace drops 12% next day",
          icon: Moon,
          color: "#5E5CE6",
        },
        {
          text: "Evening snacking adds 230 cal surplus",
          icon: Flame,
          color: "#FF9F0A",
        },
        {
          text: "HRV trending up 12% this week",
          icon: Heart,
          color: "#30D158",
        },
        {
          text: "Protein > 120g → recovery improves 18%",
          icon: Shield,
          color: "#64D2FF",
        },
      ].map((item, idx) => (
        <div
          key={idx}
          className="flex items-start gap-2 rounded-xl p-2"
          style={{ backgroundColor: `${item.color}08`, border: `1px solid ${item.color}15` }}
        >
          <div
            className="mt-0.5 flex h-5 w-5 flex-shrink-0 items-center justify-center rounded-md"
            style={{ backgroundColor: `${item.color}15` }}
          >
            <item.icon size={10} style={{ color: item.color }} />
          </div>
          <p className="text-[8px] font-medium leading-snug" style={{ color: "#F0EEE9" }}>
            {item.text}
          </p>
        </div>
      ))}
    </div>
  );
}

/* ─── Lookup ──────────────────────────────────────────────── */
export const PHONE_SCREENS: Record<string, () => React.ReactElement> = {
  connect: ConnectScreen,
  today: TodayScreen,
  data: DataScreen,
  coach: CoachScreen,
  progress: ProgressScreen,
  trends: TrendsScreen,
};
