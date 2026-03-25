"use client";

/**
 * HowItWorksSection — Interactive tabs with bold, premium visuals.
 *
 * 4 clickable tabs with large morphing visual panels.
 * Rich colors, depth, glows, and animated elements.
 */

import { useState, useRef } from "react";
import { motion, AnimatePresence } from "framer-motion";
import {
  Zap, Brain, TrendingUp, MessageCircle, Sparkles,
  Smartphone, ArrowRight, Heart, Moon, Flame, Footprints,
  Activity, Shield,
} from "lucide-react";
import { FaStrava, FaApple } from "react-icons/fa";
import { SiFitbit, SiGarmin } from "react-icons/si";
import { playClick, playTick } from "@/lib/sounds";

const TABS = [
  {
    id: "connect",
    label: "Connect",
    icon: Zap,
    headline: "Link your world",
    description: "One tap to connect Strava, Apple Health, Fitbit, and 50+ more. Your data flows in automatically — no exports, no friction, no manual entry ever again.",
    accent: "#CFE1B9",
  },
  {
    id: "analyze",
    label: "Analyze",
    icon: Brain,
    headline: "AI that reasons",
    description: "ZuraLog cross-references sleep, nutrition, activity, and recovery across every app. It doesn't just store your data — it thinks with it.",
    accent: "#D4F291",
  },
  {
    id: "insights",
    label: "Insights",
    icon: TrendingUp,
    headline: "Actions, not charts",
    description: "Get told what to eat, when to rest, and why your weight stalled. Real answers derived from your real data across every source.",
    accent: "#E8F5A8",
  },
  {
    id: "coach",
    label: "Coach",
    icon: MessageCircle,
    headline: "Talk to your data",
    description: "Ask anything in plain English. \"Why am I tired?\" \"What should I eat tonight?\" Your AI health coach has all the context it needs.",
    accent: "#CFE1B9",
  },
] as const;

const EXPO_OUT = [0.16, 1, 0.3, 1] as [number, number, number, number];

export function HowItWorksSection() {
  const [activeTab, setActiveTab] = useState(0);
  const hasInteracted = useRef(false);

  if (typeof window !== "undefined" && !hasInteracted.current) {
    const unlock = () => { hasInteracted.current = true; };
    window.addEventListener("click", unlock, { once: true });
  }

  const handleTabClick = (i: number) => {
    if (hasInteracted.current) playClick();
    setActiveTab(i);
  };

  const handleTabHover = () => {
    if (hasInteracted.current) playTick();
  };

  const tab = TABS[activeTab];

  return (
    <section
      id="how-it-works-section"
      className="relative w-full py-20 md:py-32 lg:py-40 overflow-hidden"
      style={{ backgroundColor: "transparent" }}
    >
      <div className="relative z-10 max-w-6xl mx-auto px-6 lg:px-12">
        {/* Header */}
        <div className="text-center mb-12 md:mb-16">
          <div className="mx-auto mb-6 h-px w-16" style={{ background: "linear-gradient(to right, transparent, #344E41, transparent)" }} />
          <p className="text-sm font-semibold tracking-[0.25em] uppercase mb-4" style={{ color: "#344E41" }}>
            How It Works
          </p>
          <h2 className="text-4xl sm:text-5xl lg:text-[56px] font-bold tracking-tight leading-[1.1]" style={{ color: "#1A2E22" }}>
            How ZuraLog Works
          </h2>
        </div>

        {/* Tab bar */}
        <div className="flex justify-center mb-14 md:mb-20">
          <div
            className="inline-flex rounded-full p-1.5 gap-1"
            style={{ backgroundColor: "rgba(52, 78, 65, 0.04)", border: "1px solid rgba(52, 78, 65, 0.08)" }}
          >
            {TABS.map((t, i) => {
              const Icon = t.icon;
              const isActive = i === activeTab;
              return (
                <button
                  key={t.id}
                  onClick={() => handleTabClick(i)}
                  onMouseEnter={handleTabHover}
                  className="relative flex items-center gap-2 rounded-full px-5 md:px-6 py-3 text-xs md:text-sm font-semibold transition-all duration-300"
                  style={{ color: isActive ? "#141E18" : "rgba(52, 78, 65, 0.45)" }}
                >
                  {isActive && (
                    <motion.div
                      layoutId="activeTab"
                      className="absolute inset-0 rounded-full"
                      style={{
                        backgroundColor: "#CFE1B9",
                        boxShadow: "0 2px 16px rgba(207, 225, 185, 0.45)",
                      }}
                      transition={{ type: "spring", stiffness: 400, damping: 30 }}
                    />
                  )}
                  <span className="relative z-10 flex items-center gap-2">
                    <Icon size={15} />
                    <span className="hidden sm:inline">{t.label}</span>
                  </span>
                </button>
              );
            })}
          </div>
        </div>

        {/* Content area */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-12 lg:gap-20 items-center">
          {/* Left: Text */}
          <AnimatePresence mode="wait">
            <motion.div
              key={tab.id + "-text"}
              initial={{ opacity: 0, x: -24, filter: "blur(6px)" }}
              animate={{ opacity: 1, x: 0, filter: "blur(0px)" }}
              exit={{ opacity: 0, x: 24, filter: "blur(6px)" }}
              transition={{ duration: 0.4, ease: EXPO_OUT }}
              className="flex flex-col gap-6"
            >
              {/* Tab number badge */}
              <div
                className="w-12 h-12 rounded-2xl flex items-center justify-center text-lg font-bold"
                style={{ backgroundColor: `${tab.accent}30`, color: "#344E41" }}
              >
                {activeTab + 1}
              </div>
              <h3 className="text-4xl sm:text-5xl font-bold tracking-tight leading-[1.1]" style={{ color: "#1A2E22" }}>
                {tab.headline}
              </h3>
              <p className="text-base md:text-lg leading-relaxed max-w-md" style={{ color: "rgba(52, 78, 65, 0.55)" }}>
                {tab.description}
              </p>
              {/* Decorative accent bar */}
              <div className="h-1 w-16 rounded-full" style={{ backgroundColor: tab.accent }} />
            </motion.div>
          </AnimatePresence>

          {/* Right: Visual */}
          <AnimatePresence mode="wait">
            <motion.div
              key={tab.id + "-visual"}
              initial={{ opacity: 0, scale: 0.92, y: 20, filter: "blur(10px)" }}
              animate={{ opacity: 1, scale: 1, y: 0, filter: "blur(0px)" }}
              exit={{ opacity: 0, scale: 0.92, y: -20, filter: "blur(10px)" }}
              transition={{ duration: 0.5, ease: EXPO_OUT }}
              className="flex justify-center relative"
            >
              {/* Ambient glow behind card */}
              <div
                className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[400px] h-[400px] rounded-full pointer-events-none"
                style={{ background: `radial-gradient(circle, ${tab.accent}25 0%, transparent 70%)` }}
              />

              <div
                className="relative w-full max-w-lg rounded-3xl p-8 md:p-10"
                style={{
                  backgroundColor: "rgba(30, 46, 36, 0.85)",
                  backdropFilter: "blur(20px)",
                  WebkitBackdropFilter: "blur(20px)",
                  border: "1px solid rgba(207, 225, 185, 0.10)",
                  boxShadow: `0 12px 48px rgba(20, 30, 24, 0.25), 0 0 0 1px rgba(207, 225, 185, 0.06), 0 0 80px ${tab.accent}10`,
                  minHeight: "400px",
                }}
              >
                {/* ── Connect Visual ── */}
                {activeTab === 0 && (
                  <div className="flex flex-col items-center gap-7">
                    <div className="grid grid-cols-4 gap-3">
                      {[
                        { icon: <FaStrava className="text-[#FC4C02]" size={22} />, bg: "rgba(252,76,2,0.08)" },
                        { icon: <FaApple className="text-gray-800" size={22} />, bg: "rgba(0,0,0,0.05)" },
                        { icon: <SiFitbit className="text-[#00B0B9]" size={22} />, bg: "rgba(0,176,185,0.08)" },
                        { icon: <SiGarmin className="text-[#000]" size={22} />, bg: "rgba(0,0,0,0.05)" },
                      ].map((app, idx) => (
                        <motion.div
                          key={idx}
                          initial={{ scale: 0.8, opacity: 0 }}
                          animate={{ scale: 1, opacity: 1 }}
                          transition={{ delay: idx * 0.08, duration: 0.4, ease: EXPO_OUT }}
                          className="w-16 h-16 rounded-2xl flex items-center justify-center"
                          style={{ backgroundColor: "rgba(255,255,255,0.08)", border: "1px solid rgba(207,225,185,0.10)", boxShadow: "0 2px 8px rgba(0,0,0,0.10)" }}
                        >
                          {app.icon}
                        </motion.div>
                      ))}
                    </div>

                    {/* Flow arrow */}
                    <motion.div
                      initial={{ opacity: 0, scaleX: 0 }}
                      animate={{ opacity: 1, scaleX: 1 }}
                      transition={{ delay: 0.3, duration: 0.5, ease: EXPO_OUT }}
                      className="flex items-center gap-2 w-full max-w-[200px]"
                    >
                      <div className="flex-1 h-px" style={{ background: "linear-gradient(to right, transparent, #CFE1B9)" }} />
                      <div className="w-10 h-10 rounded-full flex items-center justify-center" style={{ backgroundColor: "#CFE1B9", boxShadow: "0 2px 16px rgba(207,225,185,0.4)" }}>
                        <ArrowRight size={16} style={{ color: "#141E18" }} />
                      </div>
                      <div className="flex-1 h-px" style={{ background: "linear-gradient(to left, transparent, #CFE1B9)" }} />
                    </motion.div>

                    {/* Central hub */}
                    <motion.div
                      initial={{ scale: 0.5, opacity: 0 }}
                      animate={{ scale: 1, opacity: 1 }}
                      transition={{ delay: 0.4, duration: 0.5, ease: EXPO_OUT }}
                      className="w-20 h-20 rounded-2xl flex items-center justify-center"
                      style={{ backgroundColor: "#CFE1B9", boxShadow: "0 4px 20px rgba(207,225,185,0.4)" }}
                    >
                      <Smartphone size={32} style={{ color: "#141E18" }} />
                    </motion.div>

                    {/* Metric tags */}
                    <div className="flex flex-wrap justify-center gap-2">
                      {[
                        { label: "Sleep", icon: Moon },
                        { label: "Heart", icon: Heart },
                        { label: "Steps", icon: Footprints },
                        { label: "Calories", icon: Flame },
                        { label: "Activity", icon: Activity },
                      ].map((m, idx) => (
                        <motion.div
                          key={m.label}
                          initial={{ y: 10, opacity: 0 }}
                          animate={{ y: 0, opacity: 1 }}
                          transition={{ delay: 0.5 + idx * 0.06, duration: 0.4, ease: EXPO_OUT }}
                          className="flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium"
                          style={{ backgroundColor: "rgba(207,225,185,0.10)", border: "1px solid rgba(207,225,185,0.20)", color: "#CFE1B9" }}
                        >
                          <m.icon size={11} />
                          {m.label}
                        </motion.div>
                      ))}
                    </div>
                  </div>
                )}

                {/* ── Analyze Visual ── */}
                {activeTab === 1 && (
                  <div className="flex flex-col items-center gap-6">
                    <motion.div
                      initial={{ scale: 0.5, opacity: 0 }}
                      animate={{ scale: 1, opacity: 1 }}
                      transition={{ duration: 0.5, ease: EXPO_OUT }}
                      className="w-24 h-24 rounded-full flex items-center justify-center"
                      style={{ backgroundColor: "rgba(212,242,145,0.15)", border: "2px solid rgba(212,242,145,0.35)", boxShadow: "0 0 40px rgba(212,242,145,0.2)" }}
                    >
                      <Brain size={40} style={{ color: "#CFE1B9" }} />
                    </motion.div>

                    {/* Animated connection lines */}
                    <div className="flex items-center gap-1">
                      {[0,1,2].map((d) => (
                        <motion.div
                          key={d}
                          initial={{ scaleY: 0 }}
                          animate={{ scaleY: 1 }}
                          transition={{ delay: 0.2 + d * 0.1, duration: 0.4, ease: EXPO_OUT }}
                          className="w-0.5 h-4 rounded-full"
                          style={{ backgroundColor: "rgba(212,242,145,0.5)" }}
                        />
                      ))}
                    </div>

                    <div className="w-full grid grid-cols-2 gap-2.5">
                      {[
                        { label: "Sleep vs Recovery", icon: Moon, color: "#5E5CE6" },
                        { label: "Nutrition vs Output", icon: Flame, color: "#FF9F0A" },
                        { label: "Heart vs Stress", icon: Heart, color: "#FF375F" },
                        { label: "Activity Trends", icon: Activity, color: "#30D158" },
                        { label: "Body Composition", icon: Shield, color: "#64D2FF" },
                        { label: "Cycle Patterns", icon: Sparkles, color: "#BF5AF2" },
                      ].map((item, idx) => (
                        <motion.div
                          key={item.label}
                          initial={{ x: idx % 2 === 0 ? -20 : 20, opacity: 0 }}
                          animate={{ x: 0, opacity: 1 }}
                          transition={{ delay: 0.3 + idx * 0.07, duration: 0.5, ease: EXPO_OUT }}
                          className="flex items-center gap-2.5 rounded-xl px-3.5 py-3"
                          style={{ backgroundColor: `${item.color}08`, border: `1px solid ${item.color}18` }}
                        >
                          <item.icon size={14} style={{ color: item.color }} />
                          <span className="text-xs font-semibold" style={{ color: "#E8EDE0" }}>{item.label}</span>
                        </motion.div>
                      ))}
                    </div>
                  </div>
                )}

                {/* ── Insights Visual ── */}
                {activeTab === 2 && (
                  <div className="flex flex-col gap-3.5">
                    {[
                      { text: "You're in a 230 cal surplus — evening snacking is the culprit.", icon: Flame, iconColor: "#FF9F0A", bg: "rgba(255,159,10,0.06)", border: "rgba(255,159,10,0.15)" },
                      { text: "Only 5hr sleep. Keep today's workout in Zone 2.", icon: Moon, iconColor: "#5E5CE6", bg: "rgba(94,92,230,0.06)", border: "rgba(94,92,230,0.15)" },
                      { text: "HRV trending up 12% this week. Recovery on track.", icon: Heart, iconColor: "#30D158", bg: "rgba(48,209,88,0.06)", border: "rgba(48,209,88,0.15)" },
                      { text: "Weight plateau detected — increase protein by 15g/day.", icon: TrendingUp, iconColor: "#FF375F", bg: "rgba(255,55,95,0.06)", border: "rgba(255,55,95,0.15)" },
                    ].map((item, idx) => (
                      <motion.div
                        key={idx}
                        initial={{ x: -30, opacity: 0 }}
                        animate={{ x: 0, opacity: 1 }}
                        transition={{ delay: idx * 0.1, duration: 0.5, ease: EXPO_OUT }}
                        className="flex items-start gap-3 rounded-2xl px-4 py-4"
                        style={{ backgroundColor: item.bg, border: `1px solid ${item.border}` }}
                      >
                        <div className="w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0 mt-0.5" style={{ backgroundColor: `${item.iconColor}15` }}>
                          <item.icon size={16} style={{ color: item.iconColor }} />
                        </div>
                        <p className="text-sm font-medium leading-snug" style={{ color: "#E8EDE0" }}>
                          {item.text}
                        </p>
                      </motion.div>
                    ))}
                  </div>
                )}

                {/* ── Coach Visual ── */}
                {activeTab === 3 && (
                  <div className="flex flex-col gap-3">
                    {[
                      { side: "right", text: "Why am I not losing weight?", delay: 0 },
                      { side: "left", text: "Your CalAI data shows 2,180 cal/day avg, but Strava puts your maintenance at ~1,950. That's a 230 cal surplus. Plus running dropped from 8 to 3 sessions this month.", delay: 0.15 },
                      { side: "right", text: "What should I change?", delay: 0.3 },
                      { side: "left", text: "Cut 250 cals (skip the post-dinner snack) and get back to 5+ runs per week. You'll be in deficit within 3 days.", delay: 0.45 },
                    ].map((msg, idx) => (
                      <motion.div
                        key={idx}
                        initial={{ opacity: 0, y: 12, scale: 0.95 }}
                        animate={{ opacity: 1, y: 0, scale: 1 }}
                        transition={{ delay: msg.delay, duration: 0.4, ease: EXPO_OUT }}
                        className={`flex ${msg.side === "right" ? "justify-end" : "justify-start"}`}
                      >
                        <div
                          className={`rounded-2xl px-4 py-3 max-w-[85%] ${msg.side === "right" ? "rounded-br-md" : "rounded-bl-md"}`}
                          style={{
                            backgroundColor: msg.side === "right" ? "rgba(207,225,185,0.18)" : "rgba(255,255,255,0.10)",
                            border: `1px solid ${msg.side === "right" ? "rgba(207,225,185,0.30)" : "rgba(207,225,185,0.12)"}`,
                            boxShadow: msg.side === "right" ? "0 2px 8px rgba(207,225,185,0.08)" : "none",
                          }}
                        >
                          <p className="text-sm leading-relaxed" style={{ color: "#E8EDE0" }}>
                            {msg.text}
                          </p>
                        </div>
                      </motion.div>
                    ))}
                    {/* Typing indicator */}
                    <motion.div
                      initial={{ opacity: 0 }}
                      animate={{ opacity: 1 }}
                      transition={{ delay: 0.7 }}
                      className="flex gap-1 px-4 py-2"
                    >
                      {[0,1,2].map((d) => (
                        <div
                          key={d}
                          className="w-1.5 h-1.5 rounded-full animate-pulse"
                          style={{ backgroundColor: "rgba(207,225,185,0.30)", animationDelay: `${d * 200}ms` }}
                        />
                      ))}
                    </motion.div>
                  </div>
                )}
              </div>
            </motion.div>
          </AnimatePresence>
        </div>
      </div>
    </section>
  );
}
