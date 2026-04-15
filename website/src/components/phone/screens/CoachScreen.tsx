// website/src/components/phone/screens/CoachScreen.tsx
"use client";

import { useRef, useEffect, useState } from "react";
import { useInView, motion, AnimatePresence } from "framer-motion";
import { useSoundContext } from "@/components/design-system/interactions/sound-provider";

// ── Brand tokens (dark theme) ─────────────────────────────────────────────────
const CANVAS          = "#161618";
const SURFACE         = "#1E1E20";
const SURFACE_RAISED  = "#272729";
const SAGE            = "#CFE1B9";
const TEXT_ON_SAGE    = "#1A2E22";
const TEXT_PRIMARY    = "#F0EEE9";
const TEXT_SECONDARY  = "#9B9894";
const DIVIDER         = "rgba(240,238,233,0.06)";

// ── Pattern overlay helper ────────────────────────────────────────────────────
// blendMode: "color-burn" for Sage/light fills, "screen" for dark fills
function PatternOverlay({
  opacity,
  blendMode,
}: {
  opacity: number;
  blendMode: "color-burn" | "screen";
}) {
  return (
    <div
      aria-hidden="true"
      style={{
        position: "absolute",
        inset: 0,
        backgroundImage: "url('/patterns/original.png')",
        backgroundSize: "200px auto",
        backgroundRepeat: "repeat",
        mixBlendMode: blendMode,
        opacity,
        pointerEvents: "none",
      }}
    />
  );
}

// ── Stat highlight — Sage-coloured data points inside Zura's messages ─────────
function Stat({ children }: { children: React.ReactNode }) {
  return (
    <span style={{ color: SAGE, fontWeight: 600 }}>{children}</span>
  );
}

// ── Typing indicator ──────────────────────────────────────────────────────────
function TypingIndicator() {
  return (
    <div
      style={{
        position: "relative",
        background: SURFACE,
        borderRadius: "16px 16px 16px 4px",
        padding: "10px 14px",
        display: "inline-flex",
        gap: 5,
        alignItems: "center",
        overflow: "hidden",
      }}
    >
      <PatternOverlay opacity={0.07} blendMode="screen" />
      {[0, 1, 2].map((i) => (
        <motion.div
          key={i}
          style={{
            width: 5,
            height: 5,
            borderRadius: "50%",
            background: TEXT_SECONDARY,
            position: "relative",
          }}
          animate={{ opacity: [0.35, 1, 0.35], y: [0, -3, 0] }}
          transition={{ duration: 0.9, repeat: Infinity, delay: i * 0.2 }}
        />
      ))}
    </div>
  );
}

// ── Conversation scripts ──────────────────────────────────────────────────────
interface Msg {
  from: "user" | "zura";
  jsx: React.ReactNode;
}

const CONVERSATIONS: Msg[][] = [
  // 1 — Energy crash / sleep
  [
    { from: "user", jsx: "Why did I crash so hard Tuesday afternoon?" },
    { from: "zura", jsx: <>Tuesday you hit <Stat>5h 12m</Stat> of sleep, your lowest this month. HRV dropped to <Stat>38ms</Stat>, signaling incomplete recovery. Add in skipping hydration that morning, and your body had three strikes before noon.</> },
    { from: "user", jsx: "What should I do tonight?" },
    { from: "zura", jsx: <>Your patterns show two nights above <Stat>7h</Stat> reliably bounce your HRV back. Aim for <Stat>10:30 PM</Stat> tonight. I'll flag if your numbers shift by morning.</> },
    { from: "user", jsx: "Should I skip tomorrow's workout too?" },
    { from: "zura", jsx: <>If your HRV recovers above <Stat>52ms</Stat> by morning, a moderate session is fine. Below <Stat>45ms</Stat>, I'd swap it for a 20-minute walk. I'll notify you at 7 AM.</> },
  ],

  // 2 — Workout recovery
  [
    { from: "user", jsx: "Should I train hard today or take a rest day?" },
    { from: "zura", jsx: <>Your HRV this morning is <Stat>58ms</Stat>, 18% below your 7-day average. You trained legs yesterday and only slept <Stat>6.1 hours</Stat>. Recovery score is <Stat>41</Stat>. Light movement today.</> },
    { from: "user", jsx: "How does tomorrow look?" },
    { from: "zura", jsx: <>If tonight hits <Stat>7h+</Stat>, your HRV should climb into the <Stat>68–72ms</Stat> range, solidly green. A full session would be appropriate. I'll update your recommendation after sleep tracking ends.</> },
    { from: "user", jsx: "What kind of training fits my cycle right now?" },
    { from: "zura", jsx: <>You're in the <Stat>follicular phase</Stat>, days 6 through 13. This is your peak strength window. Your best PRs over the last 3 months all landed here. Go heavier this week.</> },
  ],

  // 3 — Nutrition
  [
    { from: "user", jsx: "Why am I not losing weight even though I'm eating healthy?" },
    { from: "zura", jsx: <>Your weekly average is <Stat>2,180 kcal</Stat>, about 330 above your target. Weekends account for most of the gap, and cooking oil and snacks are adding roughly <Stat>200 kcal/day</Stat> that aren't being logged.</> },
    { from: "user", jsx: "What's the easiest fix?" },
    { from: "zura", jsx: <>Your biggest lever is dinner portion size. Reducing it by <Stat>20%</Stat> puts you in deficit without drastically changing your meals. That one habit could cover 80% of the adjustment you need.</> },
    { from: "user", jsx: "Is my protein high enough for the training I'm doing?" },
    { from: "zura", jsx: <>You're averaging <Stat>118g/day</Stat>. For your body weight and training volume, I'd target <Stat>145–160g</Stat>. The gap is biggest on rest days. Adding Greek yoghurt or eggs at breakfast would close it.</> },
  ],

  // 4 — Sleep quality
  [
    { from: "user", jsx: "I slept 8 hours but still feel groggy. What's going on?" },
    { from: "zura", jsx: <>Your deep sleep was only <Stat>11%</Stat> last night. Normally you hit 19 to 22%. Heart rate stayed elevated until <Stat>2:10 AM</Stat>, likely from the gym session at 9:15 PM. Late workouts suppress your deep sleep.</> },
    { from: "user", jsx: "How late is too late to work out?" },
    { from: "zura", jsx: <>Workouts finishing before <Stat>7 PM</Stat> have zero measurable impact on your sleep. Between 7–9 PM, deep sleep drops ~12%. After 9 PM it drops <Stat>38%</Stat>. Your sweet spot is 5–7 PM.</> },
    { from: "user", jsx: "What else actually helps me get more deep sleep?" },
    { from: "zura", jsx: <>Three things correlate most strongly for you: early workouts, room below <Stat>19°C</Stat>, and no alcohol. On nights you hit all three, your deep sleep averages <Stat>24%</Stat>, well above baseline.</> },
  ],

  // 5 — Productivity patterns
  [
    { from: "user", jsx: "When do I actually feel my best?" },
    { from: "zura", jsx: <>Your top-rated energy days share three things: <Stat>7h+</Stat> sleep, a morning workout, and at least <Stat>2.2L</Stat> of water. That combination accounts for 84% of the days you logged high energy or focus.</> },
    { from: "user", jsx: "How often does that combination actually happen?" },
    { from: "zura", jsx: <>Only about <Stat>2 to 3 times per week</Stat>. The biggest bottleneck is morning movement. You skip it 60% of the time. Sleep and hydration are already quite consistent for you.</> },
    { from: "user", jsx: "Can you build me a routine around that?" },
    { from: "zura", jsx: <>On it. I'll set a <Stat>7:00 AM</Stat> movement prompt and a midday hydration check. After 2 weeks of data I'll adjust the routine based on what your numbers show. Start tomorrow?</> },
  ],
];

// Steps: [u1, typing1, z1, u2, typing2, z2, u3, typing3, z3]
// Times in ms — spread across ~20 seconds
const STEP_DELAYS = [700, 1700, 4200, 7400, 8400, 11800, 14800, 15800, 19200];

// ── CoachScreen ───────────────────────────────────────────────────────────────
export function CoachScreen() {
  const rootRef    = useRef<HTMLDivElement>(null);
  const scrollRef  = useRef<HTMLDivElement>(null);
  const isInView   = useInView(rootRef, { once: true, margin: "0px 0px -5% 0px" });
  const { playSound } = useSoundContext();

  // Pick one conversation per mount, stays stable across re-renders
  const [convIdx]  = useState(() => Math.floor(Math.random() * CONVERSATIONS.length));
  const conv       = CONVERSATIONS[convIdx];

  // Which step we're on (0 = nothing shown, 1–9 = progressive reveal)
  const [step, setStep] = useState(0);

  useEffect(() => {
    if (!isInView) return;
    const timers = STEP_DELAYS.map((delay, i) =>
      setTimeout(() => setStep(i + 1), delay)
    );
    return () => timers.forEach(clearTimeout);
  }, [isInView]);

  // Play a sound as each message bubble appears
  useEffect(() => {
    if (step === 0) return;
    // User messages: steps 1, 4, 7 → pop
    // Zura messages: steps 3, 6, 9 → tick
    // Typing indicators: steps 2, 5, 8 → silent
    if (step === 1 || step === 4 || step === 7) playSound("pop");
    if (step === 3 || step === 6 || step === 9) playSound("tick");
  }, [step, playSound]);

  // Auto-scroll to bottom whenever step advances
  useEffect(() => {
    const el = scrollRef.current;
    if (!el) return;
    el.scrollTo({ top: el.scrollHeight, behavior: "smooth" });
  }, [step]);

  const bubble = {
    hidden: { opacity: 0, y: 10, scale: 0.96 },
    show:   { opacity: 1, y: 0,  scale: 1,
              transition: { duration: 0.3, ease: "easeOut" as const } },
  };

  return (
    <div
      ref={rootRef}
      className="w-full h-full flex flex-col"
      style={{ background: CANVAS, fontFamily: "var(--font-jakarta)" }}
    >
      {/* ── Status bar ───────────────────────────────────── */}
      <div className="flex justify-between items-center px-5 pt-3 pb-1 flex-shrink-0">
        <span style={{ color: TEXT_PRIMARY, fontSize: 11, fontWeight: 600 }}>9:41</span>
        <div className="flex items-center gap-1.5">
          <svg width="13" height="10" viewBox="0 0 13 10" fill={TEXT_SECONDARY}>
            <rect x="0" y="6" width="2.5" height="4" rx="0.5" />
            <rect x="3.5" y="4" width="2.5" height="6" rx="0.5" />
            <rect x="7" y="2" width="2.5" height="8" rx="0.5" />
            <rect x="10.5" y="0" width="2.5" height="10" rx="0.5" />
          </svg>
          <svg width="16" height="10" viewBox="0 0 16 10" fill={TEXT_SECONDARY}>
            <rect x="0.5" y="0.5" width="12" height="9" rx="1.5" stroke={TEXT_SECONDARY} strokeWidth="1" fill="none" />
            <rect x="13" y="3" width="2" height="4" rx="0.75" />
            <rect x="2" y="2" width="8" height="6" rx="0.75" />
          </svg>
        </div>
      </div>

      {/* ── Chat header ──────────────────────────────────── */}
      <div
        className="flex items-center gap-3 px-4 py-2.5 flex-shrink-0"
        style={{ borderBottom: `1px solid ${DIVIDER}` }}
      >
        {/* Zura avatar — Surface Raised + pattern (15% screen) */}
        <div
          style={{
            width: 36, height: 36, borderRadius: "50%",
            background: SURFACE_RAISED,
            position: "relative", overflow: "hidden",
            display: "flex", alignItems: "center", justifyContent: "center",
            flexShrink: 0,
          }}
        >
          <PatternOverlay opacity={0.15} blendMode="screen" />
          <span style={{ color: SAGE, fontWeight: 700, fontSize: 14, position: "relative" }}>Z</span>
        </div>
        <div>
          <div style={{ color: TEXT_PRIMARY, fontWeight: 600, fontSize: 14, lineHeight: 1.2 }}>
            Zura
          </div>
          <div className="flex items-center gap-1.5 mt-0.5">
            <div style={{ width: 6, height: 6, borderRadius: "50%", background: "#34C759" }} />
            <span style={{ color: TEXT_SECONDARY, fontSize: 10 }}>AI Health Coach</span>
          </div>
        </div>
      </div>

      {/* ── Messages ─────────────────────────────────────── */}
      <div
        ref={scrollRef}
        className="flex-1 flex flex-col gap-2 px-3 py-3 overflow-y-auto"
        style={{ scrollbarWidth: "none" }}
      >
        <AnimatePresence mode="popLayout">

          {/* — User message 1 — */}
          {step >= 1 && (
            <motion.div key="u1" variants={bubble} initial="hidden" animate="show" className="self-end max-w-[76%]">
              <div style={{ position: "relative", background: SAGE, borderRadius: "16px 16px 4px 16px", padding: "9px 13px", overflow: "hidden" }}>
                <PatternOverlay opacity={0.12} blendMode="color-burn" />
                <p style={{ position: "relative", color: TEXT_ON_SAGE, fontSize: 12, lineHeight: 1.55 }}>
                  {conv[0].jsx}
                </p>
              </div>
            </motion.div>
          )}

          {/* — Zura typing 1 — */}
          {step === 2 && (
            <motion.div key="t1" initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, scale: 0.9 }} transition={{ duration: 0.2 }} className="self-start">
              <TypingIndicator />
            </motion.div>
          )}

          {/* — Zura message 1 — */}
          {step >= 3 && (
            <motion.div key="z1" variants={bubble} initial="hidden" animate="show" className="self-start max-w-[82%]">
              <div style={{ position: "relative", background: SURFACE, borderRadius: "16px 16px 16px 4px", padding: "9px 13px", overflow: "hidden" }}>
                <PatternOverlay opacity={0.07} blendMode="screen" />
                <p style={{ position: "relative", color: TEXT_PRIMARY, fontSize: 12, lineHeight: 1.55 }}>
                  {conv[1].jsx}
                </p>
              </div>
            </motion.div>
          )}

          {/* — User message 2 — */}
          {step >= 4 && (
            <motion.div key="u2" variants={bubble} initial="hidden" animate="show" className="self-end max-w-[76%]">
              <div style={{ position: "relative", background: SAGE, borderRadius: "16px 16px 4px 16px", padding: "9px 13px", overflow: "hidden" }}>
                <PatternOverlay opacity={0.12} blendMode="color-burn" />
                <p style={{ position: "relative", color: TEXT_ON_SAGE, fontSize: 12, lineHeight: 1.55 }}>
                  {conv[2].jsx}
                </p>
              </div>
            </motion.div>
          )}

          {/* — Zura typing 2 — */}
          {step === 5 && (
            <motion.div key="t2" initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, scale: 0.9 }} transition={{ duration: 0.2 }} className="self-start">
              <TypingIndicator />
            </motion.div>
          )}

          {/* — Zura message 2 — */}
          {step >= 6 && (
            <motion.div key="z2" variants={bubble} initial="hidden" animate="show" className="self-start max-w-[82%]">
              <div style={{ position: "relative", background: SURFACE, borderRadius: "16px 16px 16px 4px", padding: "9px 13px", overflow: "hidden" }}>
                <PatternOverlay opacity={0.07} blendMode="screen" />
                <p style={{ position: "relative", color: TEXT_PRIMARY, fontSize: 12, lineHeight: 1.55 }}>
                  {conv[3].jsx}
                </p>
              </div>
            </motion.div>
          )}

          {/* — User message 3 — */}
          {step >= 7 && (
            <motion.div key="u3" variants={bubble} initial="hidden" animate="show" className="self-end max-w-[76%]">
              <div style={{ position: "relative", background: SAGE, borderRadius: "16px 16px 4px 16px", padding: "9px 13px", overflow: "hidden" }}>
                <PatternOverlay opacity={0.12} blendMode="color-burn" />
                <p style={{ position: "relative", color: TEXT_ON_SAGE, fontSize: 12, lineHeight: 1.55 }}>
                  {conv[4].jsx}
                </p>
              </div>
            </motion.div>
          )}

          {/* — Zura typing 3 — */}
          {step === 8 && (
            <motion.div key="t3" initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, scale: 0.9 }} transition={{ duration: 0.2 }} className="self-start">
              <TypingIndicator />
            </motion.div>
          )}

          {/* — Zura message 3 — */}
          {step >= 9 && (
            <motion.div key="z3" variants={bubble} initial="hidden" animate="show" className="self-start max-w-[82%]">
              <div style={{ position: "relative", background: SURFACE, borderRadius: "16px 16px 16px 4px", padding: "9px 13px", overflow: "hidden" }}>
                <PatternOverlay opacity={0.07} blendMode="screen" />
                <p style={{ position: "relative", color: TEXT_PRIMARY, fontSize: 12, lineHeight: 1.55 }}>
                  {conv[5].jsx}
                </p>
              </div>
            </motion.div>
          )}

        </AnimatePresence>
      </div>

      {/* ── Input bar ────────────────────────────────────── */}
      <div className="px-3 pb-5 pt-2 flex-shrink-0">
        <div
          className="flex items-center gap-2"
          style={{ background: SURFACE, borderRadius: 22, padding: "10px 10px 10px 14px" }}
        >
          <span className="flex-1" style={{ color: "rgba(240,238,233,0.22)", fontSize: 12 }}>
            Ask Zura anything…
          </span>
          {/* Send — Sage + pattern (color-burn 12%) */}
          <div
            style={{
              width: 28, height: 28, borderRadius: "50%",
              background: SAGE,
              position: "relative", overflow: "hidden",
              display: "flex", alignItems: "center", justifyContent: "center",
              flexShrink: 0,
            }}
          >
            <PatternOverlay opacity={0.12} blendMode="color-burn" />
            <svg width="11" height="11" viewBox="0 0 11 11" fill="none" style={{ position: "relative" }}>
              <path d="M5.5 9V2M5.5 2L2.5 5M5.5 2L8.5 5" stroke={TEXT_ON_SAGE} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
          </div>
        </div>
      </div>
    </div>
  );
}
