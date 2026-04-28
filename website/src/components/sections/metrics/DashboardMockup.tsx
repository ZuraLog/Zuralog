"use client";

import { useRef } from "react";
import {
  Footprints, Heart, Moon, Flame, Sparkles,
} from "lucide-react";
import { useTilt } from "@/hooks/use-tilt";
import { useCountUp } from "./useCountUp";

const METRICS = [
  { label: "Steps", value: 8432, display: "8,432", icon: Footprints, color: "#30D158" },
  { label: "Heart Rate", value: 62, display: "62", suffix: " bpm", icon: Heart, color: "#FF375F" },
  { label: "Sleep", value: 7.7, display: "7h 42m", icon: Moon, color: "#5E5CE6" },
  { label: "Calories", value: 1840, display: "1,840", icon: Flame, color: "#FF9F0A" },
] as const;

const BAR_HEIGHTS = [55, 75, 40, 88, 65, 80, 70];
const DAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Today"];

export function DashboardMockup() {
  const tiltRef = useTilt<HTMLDivElement>({ maxTilt: 3, scale: 1.01 });
  const healthScoreCount = useCountUp<HTMLParagraphElement>({ target: 82, duration: 1.4 });

  return (
    <div
      ref={tiltRef}
      className="relative mx-auto w-full max-w-4xl"
      style={{ perspective: "1200px" }}
    >
      <div
        className="rounded-3xl p-6 md:p-8"
        style={{
          backgroundColor: "#161618",
          boxShadow: "0 24px 80px rgba(0,0,0,0.15), 0 0 0 1px rgba(255,255,255,0.03) inset",
        }}
      >
        {/* Top bar */}
        <div className="flex items-center justify-between mb-6 pb-4" style={{ borderBottom: "1px solid rgba(240,238,233,0.06)" }}>
          <div className="flex items-center gap-2.5">
            <div className="w-6 h-6 rounded-lg" style={{ backgroundColor: "#CFE1B9" }} />
            <span className="text-sm font-semibold" style={{ color: "#F0EEE9" }}>ZuraLog</span>
            <span className="text-xs" style={{ color: "#9B9894" }}>Dashboard</span>
          </div>
          <div className="flex gap-1">
            {["Today", "Week", "Month"].map((period, i) => (
              <span
                key={period}
                className="text-[10px] px-3 py-1.5 rounded-full"
                style={{
                  backgroundColor: i === 0 ? "rgba(207,225,185,0.12)" : "transparent",
                  color: i === 0 ? "#F0EEE9" : "#9B9894",
                }}
              >
                {period}
              </span>
            ))}
          </div>
        </div>

        {/* Main content: Health Score + Metrics grid */}
        <div className="flex gap-4 mb-4">
          {/* Health Score */}
          <div
            className="flex-1 rounded-2xl p-5 flex flex-col items-center justify-center"
            style={{
              backgroundColor: "rgba(207,225,185,0.06)",
              border: "1px solid rgba(207,225,185,0.1)",
            }}
          >
            <p className="text-[9px] font-semibold uppercase tracking-widest mb-1" style={{ color: "#9B9894" }}>
              Health Score
            </p>
            <p
              ref={healthScoreCount.ref}
              className="text-5xl font-extrabold tracking-tight"
              style={{ color: "#CFE1B9", letterSpacing: "-0.03em" }}
            >
              {healthScoreCount.display}
            </p>
            <p className="text-[9px] mt-1" style={{ color: "#9B9894" }}>+3 from last week</p>
          </div>

          {/* 2x2 Metrics grid */}
          <div className="flex-[2] grid grid-cols-2 gap-2.5">
            {METRICS.map((metric) => (
              <div
                key={metric.label}
                className="rounded-xl p-3.5"
                style={{ backgroundColor: "#1E1E20" }}
              >
                <div className="flex items-center gap-1.5 mb-1">
                  <metric.icon size={10} style={{ color: metric.color }} />
                  <p className="text-[8px]" style={{ color: "#9B9894" }}>{metric.label}</p>
                </div>
                <p className="text-xl font-bold" style={{ color: metric.color }}>
                  {metric.display}
                </p>
              </div>
            ))}
          </div>
        </div>

        {/* Bottom: Chart + AI Insight */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
          {/* Bar chart */}
          <div className="rounded-xl p-4" style={{ backgroundColor: "#1E1E20" }}>
            <p className="text-[9px] font-medium mb-3" style={{ color: "#9B9894" }}>
              7-Day Activity Trend
            </p>
            <div className="flex items-end gap-1.5" style={{ height: 64 }}>
              {BAR_HEIGHTS.map((h, i) => (
                <div
                  key={i}
                  className="flex-1 rounded-sm transition-all duration-500"
                  style={{
                    height: `${h}%`,
                    backgroundColor: i === 6 ? "#CFE1B9" : "rgba(207,225,185,0.15)",
                  }}
                />
              ))}
            </div>
            <div className="flex justify-between mt-2">
              {DAYS.map((day, i) => (
                <span
                  key={day}
                  className="text-[7px]"
                  style={{ color: i === 6 ? "#F0EEE9" : "#9B9894", fontWeight: i === 6 ? 600 : 400 }}
                >
                  {day}
                </span>
              ))}
            </div>
          </div>

          {/* AI Insight + Sources */}
          <div className="flex flex-col gap-2.5">
            <div
              className="rounded-xl p-4 flex-1"
              style={{
                backgroundColor: "rgba(207,225,185,0.06)",
                border: "1px solid rgba(207,225,185,0.1)",
              }}
            >
              <div className="flex items-center gap-1.5 mb-2">
                <div
                  className="w-4 h-4 rounded-md flex items-center justify-center"
                  style={{ backgroundColor: "#CFE1B9" }}
                >
                  <Sparkles size={8} style={{ color: "#1A2E22" }} />
                </div>
                <p className="text-[8px] font-semibold" style={{ color: "#CFE1B9" }}>AI INSIGHT</p>
              </div>
              <p className="text-[11px] leading-relaxed" style={{ color: "#F0EEE9" }}>
                Your HRV is up 12% this week — recovery is on track. Keep the evening walks going.
              </p>
              <p className="text-[8px] mt-2" style={{ color: "#9B9894" }}>
                Based on 30 days of data from 4 sources
              </p>
            </div>

            <div className="rounded-xl px-3.5 py-2.5 flex items-center gap-2.5" style={{ backgroundColor: "#1E1E20" }}>
              <div className="flex gap-1">
                {[
                  { emoji: "🏃", bg: "rgba(252,76,2,0.08)" },
                  { emoji: "🍎", bg: "rgba(0,0,0,0.15)" },
                  { emoji: "⌚", bg: "rgba(0,176,185,0.08)" },
                ].map((src, i) => (
                  <div
                    key={i}
                    className="w-5 h-5 rounded-md flex items-center justify-center text-[8px]"
                    style={{ backgroundColor: src.bg }}
                  >
                    {src.emoji}
                  </div>
                ))}
              </div>
              <span className="text-[8px]" style={{ color: "#9B9894" }}>+50 apps connected</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
