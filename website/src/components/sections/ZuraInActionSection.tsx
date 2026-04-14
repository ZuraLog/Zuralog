"use client";

import { useRef, useCallback, useState, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { useCursorParallax } from "@/hooks/use-cursor-parallax";
import { useSoundContext } from "@/components/design-system/interactions/sound-provider";
import { PhoneMockup } from "@/components/phone";
import {
  Moon,
  Clock,
  Utensils,
  TrendingDown,
  Heart,
  CalendarCheck,
  ArrowRight,
  RotateCcw,
  type LucideIcon,
} from "lucide-react";

// ── Brand tokens ─────────────────────────────────────────────────────────────

const CANVAS = "#161618";
const SURFACE = "#1E1E20";
const SURFACE_RAISED = "#272729";
const SAGE = "#CFE1B9";
const TEXT_ON_SAGE = "#1A2E22";
const TEXT_PRIMARY = "#F0EEE9";
const TEXT_SECONDARY = "#9B9894";
const DIVIDER = "rgba(240,238,233,0.06)";

// ── Pattern overlay ──────────────────────────────────────────────────────────

function PatternOverlay({ opacity, blendMode }: { opacity: number; blendMode: "color-burn" | "screen" }) {
  return (
    <div
      aria-hidden="true"
      style={{
        position: "absolute", inset: 0,
        backgroundImage: "url('/patterns/original.png')",
        backgroundSize: "200px auto", backgroundRepeat: "repeat",
        mixBlendMode: blendMode, opacity, pointerEvents: "none",
      }}
    />
  );
}

function Stat({ children }: { children: React.ReactNode }) {
  return <span style={{ color: SAGE, fontWeight: 600 }}>{children}</span>;
}

function TypingIndicator() {
  return (
    <div style={{ position: "relative", background: SURFACE, borderRadius: "16px 16px 16px 4px", padding: "10px 14px", display: "inline-flex", gap: 5, alignItems: "center", overflow: "hidden" }}>
      <PatternOverlay opacity={0.07} blendMode="screen" />
      {[0, 1, 2].map((i) => (
        <motion.div key={i} style={{ width: 5, height: 5, borderRadius: "50%", background: TEXT_SECONDARY, position: "relative" }} animate={{ opacity: [0.35, 1, 0.35], y: [0, -3, 0] }} transition={{ duration: 0.9, repeat: Infinity, delay: i * 0.2 }} />
      ))}
    </div>
  );
}

// ── Card data ────────────────────────────────────────────────────────────────

interface ActionCard {
  id: string;
  label: string;
  categoryColor: string;
  categoryBg: string;
  triggerIcon: LucideIcon;
  triggerTitle: string;
  triggerDetail: string;
  actionIcon: LucideIcon;
  actionTitle: string;
  actionDetail: string;
}

const CARDS: ActionCard[] = [
  {
    id: "schedule", label: "The Schedule Pivot",
    categoryColor: "#5E5CE6", categoryBg: "rgba(94, 92, 230, 0.10)",
    triggerIcon: Moon, triggerTitle: "Sleep score below 60",
    triggerDetail: "HRV is low and recovery is incomplete.",
    actionIcon: Clock, actionTitle: "Deep work shifts to 10 AM",
    actionDetail: "Zura moves your 8 AM focus block to 10 AM, giving your body a two-hour recovery window before any demanding work.",
  },
  {
    id: "nutrition", label: "The Nutrition Adjustment",
    categoryColor: "#FF9F0A", categoryBg: "rgba(255, 159, 10, 0.10)",
    triggerIcon: TrendingDown, triggerTitle: "Training load 30% below plan",
    triggerDetail: "A missed run left a surplus of unused fuel.",
    actionIcon: Utensils, actionTitle: "Dinner macros adjusted",
    actionDetail: "Zura lowers tonight's calorie target and bumps protein to support recovery — no manual math required.",
  },
  {
    id: "recovery", label: "The Proactive Nudge",
    categoryColor: "#FF375F", categoryBg: "rgba(255, 55, 95, 0.10)",
    triggerIcon: Heart, triggerTitle: "Sluggish recovery, 3 sessions straight",
    triggerDetail: "Heart rate recovery has been slow all week.",
    actionIcon: CalendarCheck, actionTitle: "Recovery day locked in",
    actionDetail: "Zura flags overtraining risk and blocks tomorrow in your calendar as a mandatory active recovery day.",
  },
];

const PATTERN_BG: React.CSSProperties = {
  backgroundImage: "var(--ds-pattern-sage)",
  backgroundSize: "200px auto",
  backgroundRepeat: "repeat",
};

// ── Chat types + inline charts ───────────────────────────────────────────────

interface ChatMsg { from: "user" | "zura"; jsx: React.ReactNode; chart?: React.ReactNode; }

function SleepHRVChart() {
  const bars = [
    { label: "Mon", sleep: 82, hrv: 68 },
    { label: "Tue", sleep: 74, hrv: 55 },
    { label: "Wed", sleep: 61, hrv: 42 },
    { label: "Thu", sleep: 54, hrv: 28, highlight: true },
  ];
  return (
    <div style={{ background: SURFACE_RAISED, borderRadius: 12, padding: "10px 12px", marginTop: 6 }}>
      <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 6 }}>
        <span style={{ fontSize: 9, color: TEXT_SECONDARY, fontWeight: 600 }}>SLEEP & HRV TREND</span>
        <span style={{ fontSize: 9, color: TEXT_SECONDARY }}>This week</span>
      </div>
      <div style={{ display: "flex", gap: 6, alignItems: "flex-end", height: 48 }}>
        {bars.map((b) => (
          <div key={b.label} style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", gap: 2 }}>
            <div style={{ display: "flex", gap: 2, alignItems: "flex-end", height: 36 }}>
              <div style={{ width: 6, height: `${(b.sleep / 100) * 36}px`, borderRadius: 3, background: b.highlight ? "#5E5CE6" : "rgba(94,92,230,0.35)" }} />
              <div style={{ width: 6, height: `${(b.hrv / 100) * 36}px`, borderRadius: 3, background: b.highlight ? SAGE : "rgba(207,225,185,0.3)" }} />
            </div>
            <span style={{ fontSize: 8, color: b.highlight ? TEXT_PRIMARY : TEXT_SECONDARY, fontWeight: b.highlight ? 600 : 400 }}>{b.label}</span>
          </div>
        ))}
      </div>
      <div style={{ display: "flex", gap: 10, marginTop: 6, justifyContent: "center" }}>
        <span style={{ fontSize: 8, color: "rgba(94,92,230,0.7)" }}>● Sleep</span>
        <span style={{ fontSize: 8, color: "rgba(207,225,185,0.7)" }}>● HRV</span>
      </div>
    </div>
  );
}

function MacroAdjustChart() {
  const macros = [
    { label: "Carbs", before: 240, after: 195, color: "#FF9F0A" },
    { label: "Protein", before: 130, after: 155, color: SAGE },
    { label: "Fat", before: 72, after: 60, color: TEXT_SECONDARY },
  ];
  return (
    <div style={{ background: SURFACE_RAISED, borderRadius: 12, padding: "10px 12px", marginTop: 6 }}>
      <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 8 }}>
        <span style={{ fontSize: 9, color: TEXT_SECONDARY, fontWeight: 600 }}>DINNER MACROS — ADJUSTED</span>
        <span style={{ fontSize: 9, color: "#FF9F0A" }}>−180 kcal</span>
      </div>
      <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
        {macros.map((m) => (
          <div key={m.label}>
            <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 2 }}>
              <span style={{ fontSize: 9, color: TEXT_SECONDARY }}>{m.label}</span>
              <span style={{ fontSize: 9, color: TEXT_PRIMARY }}>
                <span style={{ color: TEXT_SECONDARY, textDecoration: "line-through", marginRight: 4 }}>{m.before}g</span>{m.after}g
              </span>
            </div>
            <div style={{ height: 4, borderRadius: 2, background: "rgba(240,238,233,0.06)", overflow: "hidden" }}>
              <div style={{ height: "100%", width: `${(m.after / 260) * 100}%`, borderRadius: 2, background: m.color, opacity: 0.8 }} />
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

function HRRecoveryChart() {
  const sessions = [
    { label: "S1", val: 72, normal: true }, { label: "S2", val: 65, normal: true },
    { label: "S3", val: 58, normal: false }, { label: "S4", val: 51, normal: false },
    { label: "S5", val: 44, normal: false },
  ];
  return (
    <div style={{ background: SURFACE_RAISED, borderRadius: 12, padding: "10px 12px", marginTop: 6 }}>
      <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 6 }}>
        <span style={{ fontSize: 9, color: TEXT_SECONDARY, fontWeight: 600 }}>HR RECOVERY — LAST 5 SESSIONS</span>
        <span style={{ fontSize: 9, color: "#FF375F" }}>↓ Declining</span>
      </div>
      <div style={{ position: "relative", height: 40, marginBottom: 4 }}>
        <svg width="100%" height="40" viewBox="0 0 200 40" preserveAspectRatio="none" style={{ display: "block" }}>
          <line x1="0" y1="12" x2="200" y2="12" stroke="rgba(255,55,95,0.15)" strokeDasharray="3 3" />
          <polyline fill="none" stroke="#FF375F" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" points={sessions.map((s, i) => `${20 + i * 42},${40 - (s.val / 100) * 40}`).join(" ")} />
          {sessions.map((s, i) => <circle key={s.label} cx={20 + i * 42} cy={40 - (s.val / 100) * 40} r="3" fill={s.normal ? TEXT_SECONDARY : "#FF375F"} />)}
        </svg>
      </div>
      <div style={{ display: "flex", justifyContent: "space-between", paddingLeft: 4, paddingRight: 4 }}>
        {sessions.map((s) => <span key={s.label} style={{ fontSize: 8, color: s.normal ? TEXT_SECONDARY : "#FF375F", fontWeight: s.normal ? 400 : 600 }}>{s.label}</span>)}
      </div>
    </div>
  );
}

// ── Scenario conversations ───────────────────────────────────────────────────

const SCENARIO_CHATS: Record<string, ChatMsg[]> = {
  schedule: [
    { from: "user", jsx: "I feel terrible this morning. Should I still try deep work at 8?" },
    { from: "zura", jsx: (<>Your sleep score came in at <Stat>54</Stat> — lowest this week. HRV dropped to <Stat>28ms</Stat>, well below your <Stat>45ms</Stat> baseline.</>), chart: <SleepHRVChart /> },
    { from: "zura", jsx: (<>I&apos;ve moved your deep work to <Stat>10 AM</Stat>. Use the next two hours for light tasks and hydration. Your cognitive peak will shift later today.</>) },
    { from: "user", jsx: "Good call. Anything else I should do this morning?" },
    { from: "zura", jsx: (<>A 15-minute walk and <Stat>500ml</Stat> of water before 9 AM will help bring your HRV up. I&apos;ll check in again at noon.</>) },
  ],
  nutrition: [
    { from: "user", jsx: "I skipped my run today. Should I change what I eat tonight?" },
    { from: "zura", jsx: (<>Yes — your training load was <Stat>30% lower</Stat> than planned. I&apos;ve already adjusted your dinner targets.</>), chart: <MacroAdjustChart /> },
    { from: "zura", jsx: (<>Protein is up to <Stat>155g</Stat> to support recovery even on rest days. Total calories down <Stat>180 kcal</Stat> to match your actual output.</>) },
    { from: "user", jsx: "That's so helpful. Will it adjust back tomorrow?" },
    { from: "zura", jsx: (<>If you hit your planned run tomorrow, I&apos;ll restore your full <Stat>2,340 kcal</Stat> target automatically. No action needed from you.</>) },
  ],
  recovery: [
    { from: "user", jsx: "My legs feel heavy again. Is something off?" },
    { from: "zura", jsx: (<>Your heart rate recovery has been sluggish for <Stat>3 consecutive sessions</Stat>. That&apos;s a strong overtraining signal.</>), chart: <HRRecoveryChart /> },
    { from: "zura", jsx: (<>I&apos;ve locked tomorrow as an <Stat>active recovery day</Stat> in your calendar. Light walking or yoga only. Your body needs this.</>) },
    { from: "user", jsx: "How long until I'm back to normal?" },
    { from: "zura", jsx: (<>Based on your past patterns, <Stat>2 easy days</Stat> usually brings your HR recovery back above <Stat>65%</Stat>. I&apos;ll clear you for full training once your numbers confirm it.</>) },
  ],
};

const CHAT_DELAYS = [400, 1200, 3800, 6200, 7200, 9600, 12000, 13000, 15400];

// ── ActionChatScreen ─────────────────────────────────────────────────────────

function ActionChatScreen({ cardId, label, categoryColor, isActive }: { cardId: string; label: string; categoryColor: string; isActive: boolean }) {
  const scrollRef = useRef<HTMLDivElement>(null);
  const [step, setStep] = useState(0);
  const { playSound } = useSoundContext();
  const conv = SCENARIO_CHATS[cardId];

  useEffect(() => {
    if (!isActive) { setStep(0); return; }
    const timers = CHAT_DELAYS.map((delay, i) => setTimeout(() => setStep(i + 1), delay));
    return () => timers.forEach(clearTimeout);
  }, [isActive]);

  useEffect(() => {
    if (step === 0 || !isActive) return;
    if (step === 1 || step === 4 || step === 7) playSound("pop");
    if (step === 3 || step === 6 || step === 9) playSound("tick");
  }, [step, playSound, isActive]);

  useEffect(() => {
    const el = scrollRef.current;
    if (!el) return;
    el.scrollTo({ top: el.scrollHeight, behavior: "smooth" });
  }, [step]);

  const bubble = { hidden: { opacity: 0, y: 10, scale: 0.96 }, show: { opacity: 1, y: 0, scale: 1, transition: { duration: 0.3, ease: "easeOut" as const } } };

  const userBubble = (key: string, content: React.ReactNode) => (
    <motion.div key={key} variants={bubble} initial="hidden" animate="show" className="self-end max-w-[76%]">
      <div style={{ position: "relative", background: SAGE, borderRadius: "16px 16px 4px 16px", padding: "9px 13px", overflow: "hidden" }}>
        <PatternOverlay opacity={0.12} blendMode="color-burn" />
        <p style={{ position: "relative", color: TEXT_ON_SAGE, fontSize: 12, lineHeight: 1.55 }}>{content}</p>
      </div>
    </motion.div>
  );

  const zuraBubble = (key: string, content: React.ReactNode, chart?: React.ReactNode, maxW = "82%") => (
    <motion.div key={key} variants={bubble} initial="hidden" animate="show" className="self-start" style={{ maxWidth: maxW }}>
      <div style={{ position: "relative", background: SURFACE, borderRadius: "16px 16px 16px 4px", padding: "9px 13px", overflow: "hidden" }}>
        <PatternOverlay opacity={0.07} blendMode="screen" />
        <p style={{ position: "relative", color: TEXT_PRIMARY, fontSize: 12, lineHeight: 1.55 }}>{content}</p>
        {chart && <div style={{ position: "relative" }}>{chart}</div>}
      </div>
    </motion.div>
  );

  const typingEl = (key: string) => (
    <motion.div key={key} initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, scale: 0.9 }} transition={{ duration: 0.2 }} className="self-start">
      <TypingIndicator />
    </motion.div>
  );

  return (
    <div className="w-full h-full flex flex-col" style={{ background: CANVAS, fontFamily: "var(--font-jakarta)" }}>
      <div className="flex justify-between items-center px-5 pt-3 pb-1 flex-shrink-0">
        <span style={{ color: TEXT_PRIMARY, fontSize: 11, fontWeight: 600 }}>9:41</span>
        <div className="flex items-center gap-1.5">
          <svg width="13" height="10" viewBox="0 0 13 10" fill={TEXT_SECONDARY}><rect x="0" y="6" width="2.5" height="4" rx="0.5" /><rect x="3.5" y="4" width="2.5" height="6" rx="0.5" /><rect x="7" y="2" width="2.5" height="8" rx="0.5" /><rect x="10.5" y="0" width="2.5" height="10" rx="0.5" /></svg>
          <svg width="16" height="10" viewBox="0 0 16 10" fill={TEXT_SECONDARY}><rect x="0.5" y="0.5" width="12" height="9" rx="1.5" stroke={TEXT_SECONDARY} strokeWidth="1" fill="none" /><rect x="13" y="3" width="2" height="4" rx="0.75" /><rect x="2" y="2" width="8" height="6" rx="0.75" /></svg>
        </div>
      </div>
      <div className="flex items-center gap-3 px-4 py-2.5 flex-shrink-0" style={{ borderBottom: `1px solid ${DIVIDER}` }}>
        <div style={{ width: 36, height: 36, borderRadius: "50%", background: SURFACE_RAISED, position: "relative", overflow: "hidden", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
          <PatternOverlay opacity={0.15} blendMode="screen" />
          <span style={{ color: SAGE, fontWeight: 700, fontSize: 14, position: "relative" }}>Z</span>
        </div>
        <div className="flex-1 min-w-0">
          <div style={{ color: TEXT_PRIMARY, fontWeight: 600, fontSize: 14, lineHeight: 1.2 }}>Zura</div>
          <div className="flex items-center gap-1.5 mt-0.5">
            <div style={{ width: 6, height: 6, borderRadius: "50%", background: "#34C759" }} />
            <span style={{ color: TEXT_SECONDARY, fontSize: 10 }}>{label}</span>
          </div>
        </div>
        <div style={{ width: 8, height: 8, borderRadius: "50%", background: categoryColor, flexShrink: 0 }} />
      </div>
      <div ref={scrollRef} className="flex-1 flex flex-col gap-2 px-3 py-3 overflow-y-auto" style={{ scrollbarWidth: "none" }}>
        <AnimatePresence mode="popLayout">
          {step >= 1 && userBubble("u1", conv[0].jsx)}
          {step === 2 && typingEl("t1")}
          {step >= 3 && zuraBubble("z1", conv[1].jsx, conv[1].chart, "88%")}
          {step >= 4 && zuraBubble("z2", conv[2].jsx)}
          {step >= 7 && userBubble("u2", conv[3].jsx)}
          {step === 8 && typingEl("t2")}
          {step >= 9 && zuraBubble("z3", conv[4].jsx)}
        </AnimatePresence>
      </div>
      <div className="px-3 pb-5 pt-2 flex-shrink-0">
        <div className="flex items-center gap-2" style={{ background: SURFACE, borderRadius: 22, padding: "10px 10px 10px 14px" }}>
          <span className="flex-1" style={{ color: "rgba(240,238,233,0.22)", fontSize: 12 }}>Ask Zura anything…</span>
          <div style={{ width: 28, height: 28, borderRadius: "50%", background: SAGE, position: "relative", overflow: "hidden", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
            <PatternOverlay opacity={0.12} blendMode="color-burn" />
            <svg width="11" height="11" viewBox="0 0 11 11" fill="none" style={{ position: "relative" }}><path d="M5.5 9V2M5.5 2L2.5 5M5.5 2L8.5 5" stroke={TEXT_ON_SAGE} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" /></svg>
          </div>
        </div>
      </div>
    </div>
  );
}

// ── Phone height constant ────────────────────────────────────────────────────
// PhoneMockup at 320px wide → native 427×864 scaled by 320/427 ≈ 0.749
// Rendered height ≈ 864 × 0.749 ≈ 647px. Add padding for the flip-back button.
const PHONE_HEIGHT = 700;

// ── ActionFlowCard ───────────────────────────────────────────────────────────
// Clean CSS hover (no GSAP tilt — avoids conflicts with the flip transform).

function ActionFlowCard({ card, index }: { card: ActionCard; index: number }) {
  const [isFlipped, setIsFlipped] = useState(false);
  const frontRef = useRef<HTMLDivElement>(null);
  const parallaxRef = useCursorParallax<HTMLDivElement>({ depth: 0.5 });
  const { playSound } = useSoundContext();

  const TriggerIcon = card.triggerIcon;
  const ActionIcon = card.actionIcon;

  // Measure front face height
  const [frontHeight, setFrontHeight] = useState(0);
  useEffect(() => {
    if (!frontRef.current) return;
    const ro = new ResizeObserver(([entry]) => setFrontHeight(entry.contentRect.height));
    ro.observe(frontRef.current);
    return () => ro.disconnect();
  }, []);

  const activeHeight = isFlipped ? PHONE_HEIGHT : (frontHeight || "auto");

  const handleFlip = useCallback(() => {
    playSound("tab-click");
    setIsFlipped((p) => !p);
  }, [playSound]);

  return (
    <div
      ref={parallaxRef}
      className="will-change-transform"
      style={{ zIndex: isFlipped ? 20 : 1, position: "relative" }}
    >
      <motion.div
        initial={{ opacity: 0, y: 36 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true }}
        transition={{ duration: 0.55, delay: index * 0.12 }}
        style={{ perspective: "1200px" }}
      >
        {/* Animated-height wrapper */}
        <motion.div
          animate={{ height: activeHeight }}
          transition={{ duration: 0.5, ease: [0.4, 0, 0.2, 1] }}
          style={{ position: "relative", overflow: "visible" }}
        >
          <motion.div
            animate={{ rotateY: isFlipped ? 180 : 0 }}
            transition={{ duration: 0.5, ease: [0.4, 0, 0.2, 1] }}
            style={{ transformStyle: "preserve-3d", width: "100%", height: "100%" }}
          >
            {/* ── FRONT FACE ── */}
            <div
              ref={frontRef}
              onClick={handleFlip}
              onMouseEnter={() => playSound("tick")}
              className="group relative overflow-hidden rounded-[20px] cursor-pointer transition-all duration-300 hover:shadow-[0_8px_30px_rgba(22,22,24,0.12)] hover:-translate-y-1"
              style={{
                backgroundColor: "#E8E6E1",
                boxShadow: "0 2px 16px rgba(22, 22, 24, 0.06)",
                backfaceVisibility: "hidden",
              }}
            >
              <div className="px-7 pt-6 pb-2 flex items-center justify-between">
                <span className="inline-flex items-center gap-2 rounded-full px-3 py-1 text-[11px] font-semibold uppercase tracking-wider" style={{ backgroundColor: card.categoryBg, color: card.categoryColor }}>
                  <span className="h-1.5 w-1.5 rounded-full" style={{ backgroundColor: card.categoryColor }} />
                  {card.label}
                </span>
                <span className="text-[10px] text-[#6B6864]/40 font-medium transition-colors duration-200 group-hover:text-[#6B6864]/70">Tap to preview →</span>
              </div>
              <div className="px-7 pb-7 pt-3 flex flex-col gap-4">
                <div className="flex items-start gap-4">
                  <div className="flex-shrink-0 w-10 h-10 rounded-[12px] flex items-center justify-center mt-0.5 transition-transform duration-300 group-hover:scale-110" style={{ backgroundColor: card.categoryBg }}>
                    <TriggerIcon size={18} style={{ color: card.categoryColor }} />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-[11px] font-semibold uppercase tracking-wider text-[#6B6864]/60 mb-1">Trigger</p>
                    <p className="font-semibold text-[15px] text-[#161618] leading-snug">{card.triggerTitle}</p>
                    <p className="text-[13px] text-[#6B6864] mt-0.5 leading-relaxed">{card.triggerDetail}</p>
                  </div>
                </div>
                <div className="flex items-center gap-3 pl-[18px]">
                  <div className="relative w-[4px] flex-shrink-0 flex flex-col items-center">
                    <div className="w-[2px] h-6 rounded-full" style={{ background: `repeating-linear-gradient(to bottom, ${card.categoryColor}40 0px, ${card.categoryColor}40 3px, transparent 3px, transparent 7px)` }} />
                  </div>
                  <div className="flex items-center gap-2">
                    <motion.div animate={{ x: [0, 4, 0] }} transition={{ duration: 1.8, repeat: Infinity, ease: "easeInOut" }}>
                      <ArrowRight size={14} style={{ color: card.categoryColor }} />
                    </motion.div>
                    <span className="text-[11px] font-semibold uppercase tracking-wider" style={{ color: card.categoryColor }}>Zura responds</span>
                  </div>
                </div>
                <div className="flex items-start gap-4 rounded-[14px] p-4 -mx-1 transition-colors duration-300 group-hover:bg-[rgba(52,78,65,0.09)]" style={{ backgroundColor: "rgba(52, 78, 65, 0.06)" }}>
                  <div className="flex-shrink-0 w-10 h-10 rounded-[12px] flex items-center justify-center mt-0.5 transition-transform duration-300 group-hover:scale-110" style={{ ...PATTERN_BG, backgroundSize: "120px auto" }}>
                    <ActionIcon size={18} style={{ color: "#F0EEE9" }} />
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-[11px] font-semibold uppercase tracking-wider text-[#344E41]/60 mb-1">Action</p>
                    <p className="font-semibold text-[15px] text-[#161618] leading-snug">{card.actionTitle}</p>
                    <p className="text-[13px] text-[#6B6864] mt-1 leading-relaxed">{card.actionDetail}</p>
                  </div>
                </div>
              </div>
            </div>

            {/* ── BACK FACE ── */}
            <div
              className="absolute top-0 left-0 w-full flex flex-col items-center cursor-pointer"
              onClick={handleFlip}
              style={{
                backfaceVisibility: "hidden",
                transform: "rotateY(180deg)",
                height: PHONE_HEIGHT,
              }}
            >
              {/* Phone — centered, full size */}
              <div className="relative z-10 flex flex-col items-center pt-2">
                <div
                  className="absolute pointer-events-none"
                  style={{
                    width: 300, height: 300,
                    top: "50%", left: "50%",
                    transform: "translate(-50%, -50%)",
                    background: `radial-gradient(ellipse at center, ${card.categoryColor}10 0%, transparent 70%)`,
                    filter: "blur(24px)",
                  }}
                />
                <PhoneMockup frameWidth={320}>
                  <ActionChatScreen cardId={card.id} label={card.label} categoryColor={card.categoryColor} isActive={isFlipped} />
                </PhoneMockup>
              </div>

              {/* Flip-back button */}
              <div className="relative z-10 mt-3">
                <button
                  onClick={(e) => { e.stopPropagation(); handleFlip(); }}
                  className="inline-flex items-center gap-1.5 rounded-full px-4 py-1.5 text-[11px] font-semibold uppercase tracking-wider transition-all hover:scale-105 active:scale-95"
                  style={{
                    backgroundColor: card.categoryBg,
                    color: card.categoryColor,
                    border: `1px solid ${card.categoryColor}25`,
                  }}
                >
                  <RotateCcw size={11} />
                  Flip back
                </button>
              </div>
            </div>
          </motion.div>
        </motion.div>
      </motion.div>
    </div>
  );
}

// ── ZuraInActionSection ──────────────────────────────────────────────────────

export function ZuraInActionSection() {
  const headlineRef = useCursorParallax<HTMLDivElement>({ depth: 0.4 });
  const gridRef = useCursorParallax<HTMLDivElement>({ depth: 0.3 });

  return (
    <section className="relative py-24 md:py-32 px-6 md:px-12 font-jakarta">
      <div className="mx-auto max-w-6xl">
        <div ref={headlineRef} className="will-change-transform">
          <motion.div
            initial={{ opacity: 0, y: 24 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.6 }}
            className="mb-16 md:mb-20"
          >
            <span className="inline-flex items-center gap-2 rounded-full border border-[#344E41]/30 bg-[#344E41]/[0.07] px-4 py-1.5 text-xs font-semibold uppercase tracking-widest text-[#344E41] mb-6">
              <span className="h-1.5 w-1.5 rounded-full bg-[#344E41]" />
              Autonomous Execution
            </span>
            <h2 className="font-bold uppercase tracking-tighter leading-[0.9] text-[#161618]" style={{ fontSize: "clamp(2.5rem, 5vw, 5.5rem)" }}>
              Zura doesn&apos;t just{" "}<br className="hidden sm:block" />
              <span className="ds-pattern-text" style={{ backgroundImage: "var(--ds-pattern-sage)" }}>track.</span>{" "}
              It{" "}<span className="ds-pattern-text" style={{ backgroundImage: "var(--ds-pattern-sage)" }}>acts.</span>
            </h2>
            <p className="mt-5 text-lg md:text-xl text-[#6B6864] max-w-xl">
              Most health apps show you data and stop there. Zura reads the signals, connects them, and takes action before you even think to ask.
            </p>
          </motion.div>
        </div>

        {/* Card grid — overflow visible so phones can extend beyond */}
        <div ref={gridRef} className="will-change-transform">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4 items-start" style={{ overflow: "visible" }}>
            {CARDS.map((card, i) => (
              <ActionFlowCard key={card.id} card={card} index={i} />
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
