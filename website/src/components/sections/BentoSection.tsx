"use client";

/**
 * BentoSection.tsx
 *
 * "How ZuraLog Works" — Section 3 of the marketing site.
 *
 * Layout: Dark charcoal (#2D2D2D) background with an asymmetric 6-card
 * bento grid. Cards are white with 24px border radius. Staggered
 * scroll-triggered entrance animations via GSAP + ScrollTrigger.
 *
 * Bento Grid Structure (CSS Grid):
 *   [Connect    ] [Community  ] [Integrations ↕ tall]
 *   [Dashboard   ──── wide    ] [Integrations ↕ cont]
 *   [Free]        [Personalized ── wide              ]
 *
 * Card 4 (Unified Dashboard) features:
 *   - Pool of 10 metric cards cycling through 4 visible slots
 *   - Each slot updates on a staggered ~4s interval (offset by slot index)
 *   - 3D Y-axis flip transition when swapping cards (Framer Motion)
 *   - Slot-machine / ticker value update within a card (GSAP counter)
 *   - Progress bar re-fill animation on each update
 *   - Status-based background tinting (green/yellow/red)
 *   - Magnetic 3D tilt on the outer card (GSAP mousemove)
 *   - GSAP scroll-triggered entrance with spring physics
 */

import { useRef, useState, useEffect, useCallback } from "react";
import { useGSAP } from "@gsap/react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/dist/ScrollTrigger";
import { AnimatePresence, motion } from "framer-motion";
import {
    Zap,
    LayoutDashboard,
    Smartphone,
    Sparkles,
    CheckCircle2,
    ChevronRight,
    Heart,
    Moon,
    Footprints,
    Flame,
    Apple,
    Weight,
    Dumbbell,
    Activity,
    Droplets,
    Brain,
} from "lucide-react";
import { APPS } from "./hero/FloatingIcons";
import { FaStrava, FaApple } from "react-icons/fa";
import { SiFitbit } from "react-icons/si";

// Register GSAP ScrollTrigger plugin on client side
if (typeof window !== "undefined") {
    gsap.registerPlugin(ScrollTrigger);
}

// ─────────────────────────────────────────────────────────────
// Types
// ─────────────────────────────────────────────────────────────

/** Status tier controls card background tinting and value color */
type MetricStatus = "good" | "okay" | "bad";

interface MetricCardData {
    /** Unique identifier for this metric type */
    id: string;
    /** Display label */
    label: string;
    /** Lucide icon component */
    Icon: React.ComponentType<{ size?: number; style?: React.CSSProperties; className?: string }>;
    /** Icon accent color (hex) */
    iconColor: string;
    /** Generates a fresh snapshot: value string, sub-label, status, progress 0–100 */
    generate: () => {
        value: string;
        sub: string;
        status: MetricStatus;
        progress: number;
    };
}

// ─────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────

/** Returns a random integer between min and max (inclusive) */
function rand(min: number, max: number): number {
    return Math.floor(Math.random() * (max - min + 1)) + min;
}

/**
 * Maps a progress percentage to a weighted status.
 * Target distribution: ~60% good, ~30% okay, ~10% bad.
 * Achieved by skewing the thresholds so the "good" band is wide.
 *
 * Normal (higher = better): good ≥ 45, okay ≥ 20, bad < 20
 * Inverted (lower = better): bad ≥ 80, okay ≥ 55, good < 55
 */
function progressToStatus(pct: number, invertBad?: boolean): MetricStatus {
    if (invertBad) {
        if (pct >= 80) return "bad";
        if (pct >= 55) return "okay";
        return "good";
    }
    if (pct >= 45) return "good";
    if (pct >= 20) return "okay";
    return "bad";
}

// ─────────────────────────────────────────────────────────────
// Status styling tokens
// ─────────────────────────────────────────────────────────────

const STATUS_STYLES: Record<MetricStatus, {
    bg: string;
    border: string;
    valuColor: string;
    barColor: string;
    dot: string;
}> = {
    good: {
        bg: "rgba(22, 163, 74, 0.07)",
        border: "rgba(22, 163, 74, 0.18)",
        valuColor: "#16a34a",
        barColor: "#16a34a",
        dot: "#16a34a",
    },
    okay: {
        bg: "rgba(234, 179, 8, 0.07)",
        border: "rgba(234, 179, 8, 0.22)",
        valuColor: "#ca8a04",
        barColor: "#eab308",
        dot: "#eab308",
    },
    bad: {
        bg: "rgba(220, 38, 38, 0.07)",
        border: "rgba(220, 38, 38, 0.18)",
        valuColor: "#dc2626",
        barColor: "#dc2626",
        dot: "#dc2626",
    },
};

// ─────────────────────────────────────────────────────────────
// Pool of 10 metric card definitions
// ─────────────────────────────────────────────────────────────

const METRIC_POOL: MetricCardData[] = [
    // 1. HRV
    {
        id: "hrv",
        label: "HRV",
        Icon: Heart,
        iconColor: "#e11d48",
        generate: () => {
            const ms = rand(28, 95);
            const pct = Math.round(((ms - 28) / (95 - 28)) * 100);
            const status = progressToStatus(pct);
            return {
                value: `${ms}ms`,
                sub: pct >= 70 ? "Above baseline" : pct >= 40 ? "Near baseline" : "Below baseline",
                status,
                progress: pct,
            };
        },
    },
    // 2. Sleep
    {
        id: "sleep",
        label: "Sleep",
        Icon: Moon,
        iconColor: "#7c3aed",
        generate: () => {
            const hrs = rand(4, 9);
            const mins = rand(0, 59);
            const totalMins = hrs * 60 + mins;
            const pct = Math.round(((totalMins - 240) / (540 - 240)) * 100);
            const status = progressToStatus(Math.max(0, Math.min(100, pct)));
            const deepMins = rand(30, 120);
            return {
                value: `${hrs}h ${mins}m`,
                sub: `Deep: ${Math.floor(deepMins / 60)}h ${deepMins % 60}m`,
                status,
                progress: Math.max(0, Math.min(100, pct)),
            };
        },
    },
    // 3. Steps
    {
        id: "steps",
        label: "Steps",
        Icon: Footprints,
        iconColor: "#0891b2",
        generate: () => {
            const steps = rand(2800, 14200);
            const goal = 10000;
            const pct = Math.min(100, Math.round((steps / goal) * 100));
            const status = progressToStatus(pct);
            return {
                value: steps.toLocaleString(),
                sub: `${pct}% of goal`,
                status,
                progress: pct,
            };
        },
    },
    // 4. Calories Burned
    {
        id: "cal-burned",
        label: "Cal. Burned",
        Icon: Flame,
        iconColor: "#ea580c",
        generate: () => {
            const burned = rand(1400, 3800);
            const goal = 2800;
            const pct = Math.min(100, Math.round((burned / goal) * 100));
            const status = progressToStatus(pct);
            return {
                value: burned.toLocaleString(),
                sub: `Of ${goal.toLocaleString()} goal`,
                status,
                progress: pct,
            };
        },
    },
    // 5. Calories Taken (Intake)
    {
        id: "cal-intake",
        label: "Cal. Intake",
        Icon: Apple,
        iconColor: "#16a34a",
        generate: () => {
            const target = 2200;
            const intake = rand(900, 3200);
            const diff = intake - target;
            // Closer to target = better
            const pct = Math.max(0, 100 - Math.round((Math.abs(diff) / target) * 100));
            const status = progressToStatus(pct);
            return {
                value: intake.toLocaleString(),
                sub: diff > 0 ? `+${diff} over target` : `${Math.abs(diff)} under target`,
                status,
                progress: pct,
            };
        },
    },
    // 6. Weight
    {
        id: "weight",
        label: "Weight",
        Icon: Weight,
        iconColor: "#64748b",
        generate: () => {
            const kg = (rand(560, 1000) / 10);
            const goal = 72.0;
            const diff = kg - goal;
            const absDiff = Math.abs(diff);
            const pct = Math.max(0, 100 - Math.round((absDiff / 15) * 100));
            const status = progressToStatus(pct);
            return {
                value: `${kg.toFixed(1)} kg`,
                sub: diff > 0 ? `${diff.toFixed(1)}kg above goal` : diff < 0 ? `${absDiff.toFixed(1)}kg below goal` : "At goal",
                status,
                progress: pct,
            };
        },
    },
    // 7. Workouts
    {
        id: "workouts",
        label: "Workouts",
        Icon: Dumbbell,
        iconColor: "#b45309",
        generate: () => {
            const done = rand(0, 7);
            const goal = 5;
            const pct = Math.min(100, Math.round((done / goal) * 100));
            const status = progressToStatus(pct);
            return {
                value: `${done} / wk`,
                sub: done >= goal ? "Goal crushed!" : `${goal - done} to go`,
                status,
                progress: pct,
            };
        },
    },
    // 8. Resting HR
    {
        id: "resting-hr",
        label: "Resting HR",
        Icon: Activity,
        iconColor: "#db2777",
        generate: () => {
            const bpm = rand(44, 92);
            const pct = Math.round(((bpm - 44) / (92 - 44)) * 100);
            // Lower HR = better (invertBad)
            const status = progressToStatus(pct, true);
            return {
                value: `${bpm} bpm`,
                sub: bpm < 60 ? "Athletic range" : bpm < 75 ? "Normal range" : "Above normal",
                status,
                progress: pct,
            };
        },
    },
    // 9. Hydration
    {
        id: "hydration",
        label: "Hydration",
        Icon: Droplets,
        iconColor: "#0284c7",
        generate: () => {
            const ml = rand(600, 3200);
            const goal = 2500;
            const pct = Math.min(100, Math.round((ml / goal) * 100));
            const status = progressToStatus(pct);
            return {
                value: `${(ml / 1000).toFixed(1)}L`,
                sub: `${pct}% of ${(goal / 1000).toFixed(1)}L goal`,
                status,
                progress: pct,
            };
        },
    },
    // 10. Stress Score
    {
        id: "stress",
        label: "Stress",
        Icon: Brain,
        iconColor: "#9333ea",
        generate: () => {
            const score = rand(10, 92);
            // Lower stress = better (invertBad)
            const status = progressToStatus(score, true);
            return {
                value: `${score}`,
                sub: score < 35 ? "Low — recovery mode" : score < 65 ? "Moderate" : "High — rest advised",
                status,
                progress: score,
            };
        },
    },
];

// ─────────────────────────────────────────────────────────────
// Topic pills for "Personalized for You" card
// Split into 3 rows for the infinite marquee lanes
// ─────────────────────────────────────────────────────────────
const TOPICS_ROW1 = [
    "Sleep Duration", "Deep Sleep", "REM Sleep", "Light Sleep", "Time in Bed",
    "Sleep Efficiency", "Sleep Latency", "HRV", "Resting Heart Rate", "Heart Rate",
    "Heart Rate Variability", "Respiratory Rate", "Blood Oxygen (SpO2)", "Body Temperature", "Wrist Temperature",
    "Menstrual Cycle", "Ovulation", "Cervical Mucus", "Basal Body Temp", "Spotting",
];
const TOPICS_ROW2 = [
    "Active Energy", "Basal Energy", "Dietary Calories", "Protein", "Carbohydrates",
    "Total Fat", "Saturated Fat", "Dietary Fiber", "Dietary Sugar", "Sodium",
    "Calcium", "Iron", "Vitamin C", "Vitamin D", "Potassium",
    "Water Intake", "Caffeine", "Blood Glucose", "Insulin Delivery", "Dietary Cholesterol",
];
const TOPICS_ROW3 = [
    "Step Count", "Walking Distance", "Running Distance", "Cycling Distance", "Swimming Distance",
    "Flights Climbed", "Exercise Minutes", "Stand Hours", "Move Ring", "Exercise Ring",
    "VO2 Max", "Running Speed", "Cycling Speed", "Swimming Laps", "Workout Duration",
    "Weight", "BMI", "Body Fat %", "Lean Body Mass", "Waist Circumference",
];

// Staggered animation delays (seconds) — enough entries to cover all pills.
// Spread between 0–9s so the lighting feels organic and non-repetitive.
const PILL_DELAYS = [
    0, 0.6, 1.3, 2.0, 2.7, 3.4, 4.1, 4.8, 5.6, 6.3,
    7.0, 7.8, 8.2, 0.3, 1.0, 1.8, 2.4, 3.1, 3.8, 4.5,
    5.2, 5.9, 6.7, 7.4, 8.0, 0.9, 1.6, 2.3, 3.0, 3.7,
    4.4, 5.1, 5.8, 6.5, 7.2, 7.9, 8.5, 0.4, 1.1, 1.9,
    2.6, 3.3, 4.0, 4.7, 5.4, 6.1, 6.8, 7.5, 8.3, 0.7,
    1.4, 2.1, 2.8, 3.5, 4.2, 4.9, 5.7, 6.4, 7.1, 7.9,
];

// ─────────────────────────────────────────────────────────────
// Connect card steps
// ─────────────────────────────────────────────────────────────
const CONNECT_STEPS = [
    { label: "Link your apps", done: true },
    { label: "ZuraLog reads your data", done: true },
    { label: "AI generates insights", done: false },
];

// ─────────────────────────────────────────────────────────────
// Live metric snapshot (what one slot holds at a given moment)
// ─────────────────────────────────────────────────────────────

interface SlotSnapshot {
    cardId: string;
    label: string;
    Icon: React.ComponentType<{ size?: number; style?: React.CSSProperties; className?: string }>;
    iconColor: string;
    value: string;
    sub: string;
    status: MetricStatus;
    progress: number;
    /** Incremented each time the value changes within the same card, drives flip */
    valueKey: number;
    /** Incremented each time the card identity changes, drives 3D swap flip */
    cardKey: number;
}

/** Pick a random card from the pool that is NOT currently in any of the 4 slots */
function pickFresh(pool: MetricCardData[], usedIds: string[]): MetricCardData {
    const available = pool.filter(c => !usedIds.includes(c.id));
    const src = available.length > 0 ? available : pool;
    return src[Math.floor(Math.random() * src.length)];
}

/** Generate an initial set of 4 unique slots */
function initSlots(): SlotSnapshot[] {
    const used: string[] = [];
    return [0, 1, 2, 3].map(i => {
        const card = pickFresh(METRIC_POOL, used);
        used.push(card.id);
        const snap = card.generate();
        return {
            cardId: card.id,
            label: card.label,
            Icon: card.Icon,
            iconColor: card.iconColor,
            ...snap,
            valueKey: 0,
            cardKey: i,
        };
    });
}

// ─────────────────────────────────────────────────────────────
// DashboardMetricCard — individual animated metric tile
// ─────────────────────────────────────────────────────────────

interface DashboardMetricCardProps {
    snapshot: SlotSnapshot;
    slotIndex: number;
}

/**
 * Renders one metric tile inside the Dashboard bento.
 *
 * Animations:
 * - Framer Motion `AnimatePresence` + Y-axis 3D flip when `cardKey` changes (new card identity)
 * - GSAP slot-machine counter when `valueKey` changes (same card, new value)
 * - GSAP progress bar re-fill on each `valueKey` change
 * - Subtle idle float via CSS keyframe (applied via inline style)
 * - Status-based background tint, border, and value colour
 */
function DashboardMetricCard({ snapshot, slotIndex }: DashboardMetricCardProps) {
    const valueRef = useRef<HTMLSpanElement>(null);
    const barFillRef = useRef<HTMLDivElement>(null);
    const prevValueRef = useRef<string>(snapshot.value);
    const prevProgressRef = useRef<number>(snapshot.progress);

    const styles = STATUS_STYLES[snapshot.status];

    // Slot-machine ticker & bar refill when value changes (same card identity)
    useEffect(() => {
        if (prevValueRef.current === snapshot.value) return;
        prevValueRef.current = snapshot.value;

        // Bar refill
        if (barFillRef.current) {
            gsap.fromTo(barFillRef.current,
                { width: `${prevProgressRef.current}%` },
                {
                    width: `${snapshot.progress}%`,
                    duration: 0.9,
                    ease: "power2.out",
                    delay: 0.15,
                }
            );
        }
        prevProgressRef.current = snapshot.progress;

        // Value slot-machine: fast Y stagger out → in
        if (valueRef.current) {
            gsap.fromTo(valueRef.current,
                { y: 0, opacity: 1 },
                {
                    y: -18,
                    opacity: 0,
                    duration: 0.18,
                    ease: "power2.in",
                    onComplete: () => {
                        gsap.fromTo(valueRef.current,
                            { y: 18, opacity: 0 },
                            { y: 0, opacity: 1, duration: 0.28, ease: "back.out(1.8)" }
                        );
                    }
                }
            );
        }
    }, [snapshot.value, snapshot.progress]);

    return (
        // AnimatePresence key on cardKey — triggers 3D flip when card identity changes
        <motion.div
            key={snapshot.cardKey}
            initial={{ rotateY: -90, opacity: 0, scale: 0.9 }}
            animate={{ rotateY: 0, opacity: 1, scale: 1 }}
            exit={{ rotateY: 90, opacity: 0, scale: 0.9 }}
            transition={{
                type: "spring",
                stiffness: 260,
                damping: 22,
                delay: slotIndex * 0.06,
            }}
            style={{
                transformStyle: "preserve-3d",
                // Staggered idle float: each slot bobs at a different phase
                animation: `dashboardFloat 3.4s ease-in-out infinite`,
                animationDelay: `${slotIndex * 0.85}s`,
            }}
            className="dashboard-metric-tile rounded-2xl p-4 border relative overflow-hidden"
        >
            {/* Status background tint */}
            <div
                className="absolute inset-0 rounded-2xl pointer-events-none transition-colors duration-700"
                style={{ backgroundColor: styles.bg }}
            />

            {/* Status border ring */}
            <div
                className="absolute inset-0 rounded-2xl pointer-events-none transition-colors duration-700"
                style={{ border: `1.5px solid ${styles.border}` }}
            />

            {/* Content */}
            <div className="relative z-10 flex flex-col h-full">
                {/* Header row: icon + label + status dot */}
                <div className="flex items-center justify-between mb-2">
                    <div className="flex items-center gap-1.5">
                        <snapshot.Icon size={13} style={{ color: snapshot.iconColor }} />
                        <p className="text-[10px] font-bold text-gray-500 uppercase tracking-wider">
                            {snapshot.label}
                        </p>
                    </div>
                    {/* Status dot */}
                    <div
                        className="w-2 h-2 rounded-full flex-shrink-0"
                        style={{
                            backgroundColor: styles.dot,
                            boxShadow: `0 0 6px ${styles.dot}88`,
                        }}
                    />
                </div>

                {/* Value (slot-machine target) */}
                <div className="overflow-hidden">
                    <span
                        ref={valueRef}
                        className="block text-[19px] font-black leading-none"
                        style={{ color: styles.valuColor }}
                    >
                        {snapshot.value}
                    </span>
                </div>

                {/* Sub label */}
                <p className="text-[10px] font-medium text-gray-400 mt-1 leading-snug line-clamp-1">
                    {snapshot.sub}
                </p>

                {/* Progress bar */}
                <div className="mt-auto pt-2.5">
                    <div className="h-1 rounded-full bg-gray-100 overflow-hidden">
                        <div
                            ref={barFillRef}
                            className="h-full rounded-full transition-colors duration-700"
                            style={{
                                width: `${snapshot.progress}%`,
                                backgroundColor: styles.barColor,
                            }}
                        />
                    </div>
                </div>
            </div>
        </motion.div>
    );
}

// ─────────────────────────────────────────────────────────────
// DashboardBento — the Card 4 outer component
// ─────────────────────────────────────────────────────────────

/**
 * The "Unified Dashboard" bento card.
 *
 * Manages a 4-slot cycling display from a pool of 10 metric definitions.
 * Each slot cycles independently on a staggered interval, showing the
 * "for anyone" effect where cards don't all update at once.
 */
function DashboardBento() {
    // Lazy initialiser runs only on the client — avoids SSR hydration mismatch
    // because this component is only rendered inside a client component tree.
    const [slots, setSlots] = useState<SlotSnapshot[]>(() => initSlots());
    const cardRef = useRef<HTMLDivElement>(null);

    // ── Staggered slot cycling ─────────────────────────────────
    // Runs once on mount. setSlots always uses the functional updater so it
    // reads the latest state without this effect ever needing to re-run.
    useEffect(() => {
        const BASE_INTERVAL = 3000; // ms between updates per slot
        const SLOT_OFFSET = 1100;   // ms stagger between slots

        const timeouts: ReturnType<typeof setTimeout>[] = [];
        const intervals: ReturnType<typeof setInterval>[] = [];

        [0, 1, 2, 3].forEach((slotIdx) => {
            const tick = () => {
                setSlots(prev => {
                    const next = [...prev];
                    const current = next[slotIdx];
                    const shouldSwapCard = Math.random() < 0.30;

                    if (shouldSwapCard) {
                        // Pick a card NOT currently visible in any slot
                        const usedIds = next.map(s => s.cardId);
                        const newCard = pickFresh(METRIC_POOL, usedIds);
                        const snap = newCard.generate();
                        next[slotIdx] = {
                            cardId: newCard.id,
                            label: newCard.label,
                            Icon: newCard.Icon,
                            iconColor: newCard.iconColor,
                            ...snap,
                            valueKey: 0,
                            cardKey: current.cardKey + 1,
                        };
                    } else {
                        // Same card, fresh randomised value
                        const card = METRIC_POOL.find(c => c.id === current.cardId)!;
                        const snap = card.generate();
                        next[slotIdx] = {
                            ...current,
                            ...snap,
                            valueKey: current.valueKey + 1,
                        };
                    }

                    return next;
                });
            };

            // Stagger the start of each slot's interval
            const t = setTimeout(() => {
                tick(); // immediate first tick after the stagger offset
                const iv = setInterval(tick, BASE_INTERVAL);
                intervals.push(iv);
            }, slotIdx * SLOT_OFFSET);

            timeouts.push(t);
        });

        return () => {
            timeouts.forEach(clearTimeout);
            intervals.forEach(clearInterval);
        };
    }, []); // empty — timers read state via functional updater, never go stale

    // ── Magnetic 3D tilt on outer card (GSAP) ─────────────────
    useEffect(() => {
        const card = cardRef.current;
        if (!card) return;

        const handleMouseMove = (e: MouseEvent) => {
            const rect = card.getBoundingClientRect();
            const cx = rect.left + rect.width / 2;
            const cy = rect.top + rect.height / 2;
            const dx = e.clientX - cx;
            const dy = e.clientY - cy;
            const maxTilt = 6; // degrees

            gsap.to(card, {
                rotateX: (-dy / (rect.height / 2)) * maxTilt,
                rotateY: (dx / (rect.width / 2)) * maxTilt,
                transformPerspective: 900,
                duration: 0.35,
                ease: "power2.out",
            });
        };

        const handleMouseLeave = () => {
            gsap.to(card, {
                rotateX: 0,
                rotateY: 0,
                duration: 0.8,
                ease: "elastic.out(1, 0.45)",
            });
        };

        card.addEventListener("mousemove", handleMouseMove);
        card.addEventListener("mouseleave", handleMouseLeave);

        return () => {
            card.removeEventListener("mousemove", handleMouseMove);
            card.removeEventListener("mouseleave", handleMouseLeave);
        };
    }, []);

    return (
        <div
            ref={cardRef}
            data-card="dashboard"
            className="bento-card dashboard-bento group relative bg-white rounded-3xl p-7 lg:p-8 shadow-xl overflow-hidden opacity-0"
            style={{
                gridColumn: "1 / 3",
                gridRow: "2",
                transformStyle: "preserve-3d",
                willChange: "transform",
            }}
        >
            {/* Subtle inner glow on hover */}
            <div className="absolute inset-0 rounded-3xl pointer-events-none transition-opacity duration-300 opacity-0 group-hover:opacity-100"
                style={{ boxShadow: "inset 0 0 40px rgba(232,245,168,0.12)" }} />

            <div className="flex flex-col lg:flex-row gap-6 h-full">
                {/* Left: Title block */}
                <div className="flex-shrink-0 lg:w-[200px]">
                    <div className="w-11 h-11 rounded-2xl bg-gray-900 flex items-center justify-center mb-4">
                        <LayoutDashboard size={20} className="text-[#E8F5A8]" />
                    </div>
                    <h3 className="text-xl font-bold text-gray-900 mb-2">Your Unified Dashboard</h3>
                    <p className="text-sm text-gray-500 leading-relaxed">
                        Real-time health metrics — tailored for you, live.
                    </p>
                    {/* Live indicator */}
                    <div className="flex items-center gap-1.5 mt-4">
                        <div className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
                        <span className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">Live data</span>
                    </div>
                </div>

                {/* Right: 2×2 cycling metric grid */}
                <div
                    className="flex-1 grid grid-cols-2 gap-3"
                    style={{ perspective: "600px" }}
                >
                    <AnimatePresence mode="popLayout">
                        {slots.map((slot, i) => (
                            <DashboardMetricCard
                                key={`slot-${i}`}
                                snapshot={slot}
                                slotIndex={i}
                            />
                        ))}
                    </AnimatePresence>
                </div>
            </div>
        </div>
    );
}

// ─────────────────────────────────────────────────────────────
// BentoSection — main export
// ─────────────────────────────────────────────────────────────

/**
 * BentoSection — "How ZuraLog Works"
 *
 * Dark background section with a 6-card bento grid layout.
 * Cards reveal with staggered GSAP scroll animations.
 */
export function BentoSection() {
    const sectionRef = useRef<HTMLElement>(null);

    useGSAP(
        () => {
            if (!sectionRef.current) return;

            const cards = sectionRef.current.querySelectorAll<HTMLElement>(".bento-card");
            const title = sectionRef.current.querySelector<HTMLElement>(".bento-title");
            const subtitle = sectionRef.current.querySelector<HTMLElement>(".bento-subtitle");

            // Title entrance
            if (title) {
                gsap.fromTo(
                    title,
                    { opacity: 0, y: 40 },
                    {
                        opacity: 1,
                        y: 0,
                        duration: 0.8,
                        ease: "power3.out",
                        scrollTrigger: {
                            trigger: title,
                            start: "top 85%",
                            toggleActions: "play none none none",
                        },
                    }
                );
            }

            if (subtitle) {
                gsap.fromTo(
                    subtitle,
                    { opacity: 0, y: 30 },
                    {
                        opacity: 1,
                        y: 0,
                        duration: 0.7,
                        ease: "power3.out",
                        delay: 0.15,
                        scrollTrigger: {
                            trigger: subtitle,
                            start: "top 85%",
                            toggleActions: "play none none none",
                        },
                    }
                );
            }

            // Staggered card entrance for generic cards
            cards.forEach((card, i) => {
                const cardType = card.getAttribute('data-card');
                // Connect, waitlist, and dashboard handled specifically below
                if (cardType === 'connect' || cardType === 'waitlist' || cardType === 'dashboard') return;

                gsap.fromTo(
                    card,
                    { opacity: 0, y: 60, scale: 0.95 },
                    {
                        opacity: 1,
                        y: 0,
                        scale: 1,
                        duration: 0.7,
                        ease: "cubic-bezier(0.16, 1, 0.3, 1)",
                        delay: i * 0.12,
                        scrollTrigger: {
                            trigger: sectionRef.current,
                            start: "top 70%",
                            toggleActions: "play none none none",
                        },
                    }
                );
            });

            // ─────────────────────────────────────────────────────────────
            // Card 1: Connect - Specific Animations
            // ─────────────────────────────────────────────────────────────
            const card1 = sectionRef.current.querySelector('[data-card="connect"]');
            if (card1) {
                gsap.fromTo(
                    card1,
                    { opacity: 0, y: 80, scale: 0.8, rotateX: 25, rotateY: -15, transformPerspective: 1000 },
                    {
                        opacity: 1, y: 0, scale: 1, rotateX: 0, rotateY: 0,
                        duration: 1.4, ease: "elastic.out(1, 0.7)",
                        scrollTrigger: {
                            trigger: card1,
                            start: "top 80%",
                            toggleActions: "play none none none",
                        },
                        onComplete: () => {
                            const checks = card1.querySelectorAll('.connect-step-check');
                            gsap.fromTo(checks,
                                { scale: 0, opacity: 0, rotation: -90 },
                                { scale: 1, opacity: 1, rotation: 0, stagger: 0.15, duration: 0.6, ease: "back.out(2)" }
                            );
                            const pills = card1.querySelectorAll('.connect-app-pill');
                            gsap.fromTo(pills,
                                { y: 30, opacity: 0, scale: 0.5 },
                                { y: 0, opacity: 1, scale: 1, stagger: 0.1, duration: 1, ease: "elastic.out(1, 0.5)" }
                            );
                        }
                    }
                );

                const dot = card1.querySelector('.connect-dot');
                if (dot) {
                    gsap.to(dot, { scale: 1.5, opacity: 0.7, duration: 1.2, yoyo: true, repeat: -1, ease: "sine.inOut" });
                }

                const zap = card1.querySelector('.connect-zap');
                if (zap) {
                    gsap.to(zap, {
                        filter: "drop-shadow(0px 0px 12px rgba(232,245,168,0.9))",
                        y: -3, scale: 1.05,
                        duration: 1.5, yoyo: true, repeat: -1, ease: "sine.inOut"
                    });
                }

                const pills = card1.querySelectorAll('.connect-app-pill');
                pills.forEach((pill, idx) => {
                    gsap.to(pill, { y: -5, duration: 2.5, yoyo: true, repeat: -1, ease: "sine.inOut", delay: idx * 0.4 });
                });

                const sheen = card1.querySelector('.connect-sheen');
                card1.addEventListener('mouseenter', () => {
                    gsap.fromTo(sheen, { left: "-100%" }, { left: "200%", duration: 1.2, ease: "power2.inOut" });
                });

                card1.addEventListener('mousemove', (e) => {
                    const event = e as MouseEvent;
                    const rect = card1.getBoundingClientRect();
                    const rx = event.clientX - rect.left;
                    const ry = event.clientY - rect.top;

                    pills.forEach(pill => {
                        const pillRect = pill.getBoundingClientRect();
                        const px = pillRect.left - rect.left + pillRect.width / 2;
                        const py = pillRect.top - rect.top + pillRect.height / 2;
                        const dx = px - rx;
                        const dy = py - ry;
                        const dist = Math.sqrt(dx * dx + dy * dy);

                        if (dist < 100) {
                            const force = (100 - dist) / 100;
                            gsap.to(pill, {
                                x: (dx / dist) * force * 20,
                                y: (dy / dist) * force * 20 - 5,
                                duration: 0.3, ease: "power2.out"
                            });
                        } else {
                            gsap.to(pill, { x: 0, duration: 0.6, ease: "power2.out" });
                        }
                    });
                });
                card1.addEventListener('mouseleave', () => {
                    gsap.to(pills, { x: 0, duration: 0.8, ease: "elastic.out(1, 0.4)" });
                });
            }

            // ─────────────────────────────────────────────────────────────
            // Card 2: Waitlist & Leaderboard - Specific Animations
            // ─────────────────────────────────────────────────────────────
            const card2 = sectionRef.current.querySelector('[data-card="waitlist"]');
            if (card2) {
                gsap.fromTo(
                    card2,
                    { opacity: 0, scale: 0.85, y: 50 },
                    {
                        opacity: 1, scale: 1, y: 0,
                        duration: 1.2, ease: "elastic.out(1, 0.6)",
                        delay: 0.2,
                        scrollTrigger: {
                            trigger: card2,
                            start: "top 80%",
                            toggleActions: "play none none none",
                        },
                        onComplete: () => {
                            const counterNum = card2.querySelector('.waitlist-counter-opt');
                            if (counterNum) {
                                gsap.fromTo(counterNum,
                                    { innerText: 0 },
                                    { innerText: 2450, duration: 2, ease: "power3.out", snap: { innerText: 1 } }
                                );
                            }
                            const entries = card2.querySelectorAll('.leaderboard-entry');
                            gsap.fromTo(entries,
                                { x: -20, opacity: 0 },
                                { x: 0, opacity: 1, stagger: 0.15, duration: 0.6, ease: "power2.out" }
                            );
                        }
                    }
                );

                const entries = card2.querySelectorAll('.leaderboard-entry');
                entries.forEach((entry, idx) => {
                    gsap.to(entry, {
                        y: -3, rotation: idx % 2 === 0 ? 0.5 : -0.5,
                        duration: 3, yoyo: true, repeat: -1, ease: "sine.inOut", delay: idx * 0.3
                    });
                });

                const badge = card2.querySelector('.vip-badge');
                if (badge) {
                    gsap.to(badge, {
                        boxShadow: "0px 0px 15px rgba(255, 215, 0, 0.6)",
                        scale: 1.05,
                        duration: 1.5, yoyo: true, repeat: -1, ease: "sine.inOut"
                    });
                }

                const expandMask = card2.querySelector('.waitlist-hover-mask');
                if (expandMask) {
                    card2.addEventListener('mouseenter', () => {
                        gsap.fromTo(expandMask, { opacity: 0 }, { opacity: 1, duration: 0.3 });
                        gsap.to(entries, { x: 5, duration: 0.3, stagger: 0.05, ease: "power1.out" });
                    });
                    card2.addEventListener('mouseleave', () => {
                        gsap.to(expandMask, { opacity: 0, duration: 0.3 });
                        gsap.to(entries, { x: 0, duration: 0.3, stagger: -0.05, ease: "power1.out" });
                    });
                }
            }

            // ─────────────────────────────────────────────────────────────
            // Card 4: Dashboard Bento — scroll entrance
            // ─────────────────────────────────────────────────────────────
            const dashCard = sectionRef.current.querySelector('[data-card="dashboard"]');
            if (dashCard) {
                gsap.fromTo(
                    dashCard,
                    {
                        opacity: 0,
                        y: 70,
                        scale: 0.92,
                        rotateX: 12,
                        transformPerspective: 1200,
                    },
                    {
                        opacity: 1,
                        y: 0,
                        scale: 1,
                        rotateX: 0,
                        duration: 1.1,
                        ease: "elastic.out(1, 0.65)",
                        scrollTrigger: {
                            trigger: dashCard,
                            start: "top 78%",
                            toggleActions: "play none none none",
                        },
                        onComplete: () => {
                            // Stagger-pop the metric tiles in
                            const tiles = dashCard.querySelectorAll('.dashboard-metric-tile');
                            gsap.fromTo(tiles,
                                { opacity: 0, scale: 0.8, y: 20 },
                                {
                                    opacity: 1, scale: 1, y: 0,
                                    stagger: 0.1,
                                    duration: 0.55,
                                    ease: "back.out(2)",
                                }
                            );
                        }
                    }
                );
            }
        },
        { scope: sectionRef }
    );

    return (
        <section
            ref={sectionRef}
            id="bento-section"
            className="relative w-full py-28 lg:py-36 overflow-hidden"
            style={{ backgroundColor: "#2D2D2D" }}
        >
            {/* Subtle background texture */}
            <div
                className="absolute inset-0 opacity-[0.03] pointer-events-none"
                style={{
                    backgroundImage: `radial-gradient(circle at 1px 1px, #ffffff 1px, transparent 0)`,
                    backgroundSize: "40px 40px",
                }}
            />

            <div className="relative z-10 max-w-[1280px] mx-auto px-6 lg:px-12">
                {/* ── Section Header ── */}
                <div className="text-center mb-16 lg:mb-20">
                    <p className="bento-subtitle text-sm font-semibold tracking-[0.25em] uppercase text-[#E8F5A8] mb-4 opacity-0">
                        How It Works
                    </p>
                    <h2 className="bento-title text-4xl sm:text-5xl lg:text-[56px] font-bold text-white leading-[1.1] tracking-tight opacity-0">
                        How ZuraLog Works
                    </h2>
                </div>

                {/* ── Bento Grid ── */}
                <div
                    className="grid gap-4 lg:gap-5"
                    style={{
                        gridTemplateColumns: "repeat(3, 1fr)",
                        gridTemplateRows: "auto auto auto",
                    }}
                >
                    {/* ══ Card 1: CONNECT ══ */}
                    <div
                        data-card="connect"
                        className="bento-card group relative bg-white rounded-3xl p-7 lg:p-8 shadow-xl overflow-hidden
                                   hover:shadow-2xl transition-shadow duration-300 opacity-0"
                        style={{ gridColumn: "1", gridRow: "1", transformStyle: "preserve-3d" }}
                    >
                        {/* Interactive Sheen layer */}
                        <div className="connect-sheen absolute top-0 w-full h-full bg-gradient-to-r from-transparent via-white/80 to-transparent skew-x-[-25deg] pointer-events-none z-20" style={{ left: "-100%" }} />
                        {/* Decorative lime accent dot */}
                        <div className="connect-dot absolute top-6 right-6 w-3 h-3 rounded-full bg-[#E8F5A8] z-10" />

                        <div className="flex items-center gap-3 mb-5 relative z-10">
                            <div className="connect-zap w-11 h-11 rounded-2xl bg-[#E8F5A8] flex items-center justify-center flex-shrink-0 origin-center">
                                <Zap size={20} className="text-gray-900" />
                            </div>
                            <div>
                                <h3 className="text-xl font-bold text-gray-900">Connect</h3>
                                <p className="text-xs text-gray-500 font-medium">One-tap integration</p>
                            </div>
                        </div>

                        <p className="text-sm text-gray-600 leading-relaxed mb-6 relative z-10">
                            Link your favorite apps in seconds. ZuraLog handles the rest — no manual imports, no friction.
                        </p>

                        <div className="flex flex-col gap-2.5 relative z-10">
                            {CONNECT_STEPS.map((step, i) => (
                                <div key={i} className="flex items-center gap-3">
                                    <div className="connect-step-check opacity-0 transform-gpu origin-center">
                                        <CheckCircle2
                                            size={16}
                                            className={step.done ? "text-[#4CAF50] flex-shrink-0" : "text-gray-300 flex-shrink-0"}
                                        />
                                    </div>
                                    <span className={`text-sm font-medium ${step.done ? "text-gray-700" : "text-gray-400"}`}>
                                        {step.label}
                                    </span>
                                </div>
                            ))}
                        </div>

                        <div className="mt-6 flex flex-wrap gap-2 relative z-10 perspective-1000">
                            {[
                                { icon: <FaStrava className="text-[#FC4C02]" size={12} />, name: "Strava" },
                                { icon: <FaApple className="text-gray-800" size={12} />, name: "Apple Health" },
                                { icon: <SiFitbit className="text-[#00B0B9]" size={12} />, name: "Fitbit" },
                            ].map((app) => (
                                <div
                                    key={app.name}
                                    className="connect-app-pill opacity-0 flex items-center gap-1.5 bg-gray-50 border border-gray-100 rounded-full px-3 py-1.5 text-xs font-medium text-gray-600 shadow-sm"
                                    style={{ willChange: "transform" }}
                                >
                                    {app.icon}
                                    {app.name}
                                </div>
                            ))}
                        </div>
                    </div>

                    {/* ══ Card 2: WAITLIST & LEADERBOARD ══ */}
                    <div
                        data-card="waitlist"
                        className="bento-card group relative bg-white rounded-3xl p-7 lg:p-8 shadow-xl overflow-hidden
                                   hover:shadow-2xl transition-shadow duration-300 opacity-0"
                        style={{ gridColumn: "2", gridRow: "1" }}
                    >
                        <div className="waitlist-hover-mask absolute inset-0 bg-gradient-to-b from-[#E8F5A8]/10 to-transparent opacity-0 pointer-events-none transition-opacity duration-300" />

                        <div className="flex justify-between items-start mb-6 relative z-10">
                            <div>
                                <div className="inline-flex items-center gap-2 bg-[#1A1A1A] rounded-full px-3 py-1 mb-3">
                                    <div className="w-2 h-2 rounded-full bg-[#E8F5A8] animate-pulse" />
                                    <span className="text-[10px] font-bold text-white uppercase tracking-wider">Live Waitlist</span>
                                </div>
                                <h3 className="text-xl font-bold text-gray-900 mb-1 leading-tight">Join the Waitlist</h3>
                                <p className="text-xs text-gray-500 font-medium">Climb the ranks. Earn Pro.</p>
                            </div>
                            <div className="text-right">
                                <div className="text-2xl font-black text-gray-900 leading-none waitlist-counter-opt">0</div>
                                <div className="text-[10px] uppercase font-bold text-gray-400 mt-1">Total Users</div>
                            </div>
                        </div>

                        <div className="flex flex-col gap-2 relative z-10 mb-5">
                            <div className="leaderboard-entry opacity-0 flex items-center justify-between p-2.5 rounded-xl bg-gradient-to-r from-[#FFD700]/10 to-transparent border border-[#FFD700]/20">
                                <div className="flex items-center gap-3">
                                    <div className="w-6 font-bold text-[#D4AF37] text-sm text-center">#1</div>
                                    <div className="w-7 h-7 rounded-full bg-gray-900 flex items-center justify-center text-white text-[10px] font-bold shadow-sm">HY</div>
                                    <span className="text-sm font-semibold text-gray-900">Hyowon B.</span>
                                </div>
                            </div>
                            <div className="leaderboard-entry opacity-0 flex items-center justify-between p-2.5 rounded-xl bg-gray-50 border border-gray-100">
                                <div className="flex items-center gap-3">
                                    <div className="w-6 font-bold text-gray-400 text-sm text-center">#2</div>
                                    <div className="w-7 h-7 rounded-full bg-[#E8F5A8] flex items-center justify-center text-gray-900 text-[10px] font-bold shadow-sm">AL</div>
                                    <span className="text-sm font-semibold text-gray-700">Alice L.</span>
                                </div>
                            </div>
                            <div className="leaderboard-entry opacity-0 flex items-center justify-between p-2.5 rounded-xl bg-gray-50 border border-gray-100">
                                <div className="flex items-center gap-3">
                                    <div className="w-6 font-bold text-gray-400 text-sm text-center">#3</div>
                                    <div className="w-7 h-7 rounded-full border border-gray-200 border-dashed flex items-center justify-center text-gray-400 text-[10px] font-bold">+</div>
                                    <span className="text-sm font-medium text-gray-400 italic">This could be you</span>
                                </div>
                            </div>
                        </div>

                        <p className="text-[10px] text-gray-400 leading-relaxed font-medium relative z-10 text-center">
                            * Top 30 receive 3 months of ZuraLog Pro.
                            <br />First 30 receive 1 month. Refer friends to climb.
                        </p>
                    </div>

                    {/* ══ Card 3: INTEGRATIONS (tall, spans rows 1-2) ══ */}
                    <div
                        data-card="integrations"
                        className="bento-card group relative bg-white rounded-3xl shadow-xl overflow-hidden opacity-0
                                   hover:-translate-y-1 hover:shadow-2xl transition-all duration-300"
                        style={{ gridColumn: "3", gridRow: "1 / 3" }}
                    >
                        <div
                            className="absolute inset-0 w-full h-full pointer-events-none"
                            style={{
                                maskImage: "linear-gradient(to bottom, black 0%, black 20%, transparent 65%)",
                                WebkitMaskImage: "linear-gradient(to bottom, black 0%, black 20%, transparent 65%)"
                            }}
                        >
                            <div
                                className="absolute flex flex-row gap-4"
                                style={{ width: "350%", height: "300%", top: "-100%", left: "-100%", transform: "rotate(45deg)", justifyContent: "center" }}
                            >
                                {[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map(colIndex => {
                                    const speedClass = colIndex % 3 === 0 ? 'animate-drift-slow' : colIndex % 3 === 1 ? 'animate-drift-mid' : 'animate-drift-fast';
                                    return (
                                        <div
                                            key={colIndex}
                                            className={`integrations-column flex flex-col gap-4 w-max h-max ${speedClass}`}
                                            style={{ marginTop: colIndex % 2 !== 0 ? '40px' : '0px', willChange: "transform" }}
                                        >
                                            {[...APPS, ...APPS, ...APPS].map((app, i) => (
                                                <div
                                                    key={`${colIndex}-${i}`}
                                                    className="w-14 h-14 rounded-2xl bg-white border border-gray-100 flex flex-shrink-0 items-center justify-center shadow-[0_2px_10px_rgba(0,0,0,0.03)]"
                                                    style={{ transform: "rotate(-45deg) translateZ(0)" }}
                                                >
                                                    <app.Icon size={26} color={app.color} />
                                                </div>
                                            ))}
                                        </div>
                                    );
                                })}
                            </div>
                        </div>

                        <div className="absolute bottom-0 left-0 w-full p-7 lg:p-8 z-10 flex flex-col justify-end h-full pointer-events-none">
                            <div className="pointer-events-auto mt-auto">
                                <div className="inline-flex items-center gap-1.5 bg-[#E8F5A8] text-[#4d5e12] rounded-full px-3 py-1 mb-4 shadow-sm">
                                    <Sparkles size={12} className="text-[#6B7522]" />
                                    <span className="text-[10px] font-bold uppercase tracking-wider">Centralized Hub</span>
                                </div>
                                <h3 className="text-[28px] font-bold text-gray-900 mb-2 leading-tight">50+ Apps Flowing Seamlessly</h3>
                                <p className="text-sm text-gray-500 leading-relaxed mb-6 font-medium">
                                    From Apple Health to Strava — every platform you love, organically synced into one powerful dashboard.
                                </p>
                                <button className="flex items-center gap-1.5 text-sm font-semibold text-gray-900 hover:text-[#5A631B] group/btn transition-colors">
                                    Explore integrations
                                    <ChevronRight size={14} className="group-hover/btn:translate-x-1 transition-transform" />
                                </button>
                            </div>
                        </div>
                    </div>

                    {/* ══ Card 4: UNIFIED DASHBOARD ══ */}
                    <DashboardBento />

                    {/* ══ Card 5: FREE TO START ══ */}
                    <div
                        className="bento-card group relative rounded-3xl p-7 lg:p-8 shadow-xl overflow-hidden
                                   hover:-translate-y-1 hover:shadow-2xl transition-all duration-200 opacity-0"
                        style={{
                            gridColumn: "1",
                            gridRow: "3",
                            background: "linear-gradient(135deg, #E8F5A8 0%, #D4F291 100%)",
                        }}
                    >
                        <div className="w-11 h-11 rounded-2xl bg-white/70 flex items-center justify-center mb-4">
                            <Smartphone size={20} className="text-gray-900" />
                        </div>
                        <h3 className="text-xl font-bold text-gray-900 mb-2">Free to Start</h3>
                        <p className="text-sm text-gray-700 leading-relaxed mb-6">
                            Core features always free. No credit card required.
                        </p>
                        <div className="flex items-center gap-2">
                            <div className="flex-1 h-1.5 bg-white/50 rounded-full overflow-hidden">
                                <div className="h-full bg-gray-900/30 rounded-full" style={{ width: "65%" }} />
                            </div>
                            <span className="text-xs font-semibold text-gray-700">65% claimed</span>
                        </div>
                        <button className="mt-5 w-full bg-gray-900 text-white text-sm font-semibold py-3 rounded-2xl hover:bg-gray-800 transition-colors shadow-md">
                            Claim Your Spot →
                        </button>
                    </div>

                    {/* ══ Card 6: PERSONALIZED FOR YOU (wide, spans cols 2-3) ══ */}
                    <div
                        className="bento-card personalized-card group relative bg-white rounded-3xl shadow-xl overflow-hidden
                                   hover:-translate-y-1 hover:shadow-2xl transition-all duration-200 opacity-0"
                        style={{ gridColumn: "2 / 4", gridRow: "3" }}
                    >
                        {/* ── Header ── */}
                        <div className="flex items-center gap-3 px-7 lg:px-8 pt-7 lg:pt-8 pb-5">
                            <div className="w-11 h-11 rounded-2xl bg-gray-900 flex items-center justify-center flex-shrink-0">
                                <Sparkles size={20} className="text-[#E8F5A8]" />
                            </div>
                            <div>
                                <h3 className="text-xl font-bold text-gray-900">Personalized for You</h3>
                                <p className="text-xs text-gray-500 font-medium">AI-powered insights based on YOUR data</p>
                            </div>
                        </div>

                        {/* ── Marquee rows ── */}
                        <div
                            className="flex flex-col gap-3 pb-7 lg:pb-8"
                            style={{
                                maskImage: "linear-gradient(to right, transparent 0%, black 8%, black 92%, transparent 100%)",
                                WebkitMaskImage: "linear-gradient(to right, transparent 0%, black 8%, black 92%, transparent 100%)",
                            }}
                        >
                            {/* Row 1 — left → right */}
                            <div className="overflow-hidden">
                                <div className="animate-marquee-left flex gap-3 w-max">
                                    {/* First copy — readable by screen readers */}
                                    {TOPICS_ROW1.map((topic, i) => (
                                        <span key={`r1a-${i}`} className="pill-pulse inline-flex items-center px-4 py-2 rounded-full text-sm font-semibold border cursor-default whitespace-nowrap flex-shrink-0" style={{ animationDelay: `${PILL_DELAYS[i % PILL_DELAYS.length]}s` }}>{topic}</span>
                                    ))}
                                    {/* Duplicate copies for seamless loop — hidden from a11y */}
                                    {[...TOPICS_ROW1, ...TOPICS_ROW1].map((topic, i) => (
                                        <span key={`r1b-${i}`} aria-hidden="true" className="pill-pulse inline-flex items-center px-4 py-2 rounded-full text-sm font-semibold border cursor-default whitespace-nowrap flex-shrink-0" style={{ animationDelay: `${PILL_DELAYS[(i + TOPICS_ROW1.length) % PILL_DELAYS.length]}s` }}>{topic}</span>
                                    ))}
                                </div>
                            </div>

                            {/* Row 2 — right → left */}
                            <div className="overflow-hidden">
                                <div className="animate-marquee-right flex gap-3 w-max">
                                    {TOPICS_ROW2.map((topic, i) => (
                                        <span key={`r2a-${i}`} className="pill-pulse inline-flex items-center px-4 py-2 rounded-full text-sm font-semibold border cursor-default whitespace-nowrap flex-shrink-0" style={{ animationDelay: `${PILL_DELAYS[(i + 5) % PILL_DELAYS.length]}s` }}>{topic}</span>
                                    ))}
                                    {[...TOPICS_ROW2, ...TOPICS_ROW2].map((topic, i) => (
                                        <span key={`r2b-${i}`} aria-hidden="true" className="pill-pulse inline-flex items-center px-4 py-2 rounded-full text-sm font-semibold border cursor-default whitespace-nowrap flex-shrink-0" style={{ animationDelay: `${PILL_DELAYS[(i + TOPICS_ROW2.length + 5) % PILL_DELAYS.length]}s` }}>{topic}</span>
                                    ))}
                                </div>
                            </div>

                            {/* Row 3 — left → right */}
                            <div className="overflow-hidden">
                                <div className="animate-marquee-left flex gap-3 w-max">
                                    {TOPICS_ROW3.map((topic, i) => (
                                        <span key={`r3a-${i}`} className="pill-pulse inline-flex items-center px-4 py-2 rounded-full text-sm font-semibold border cursor-default whitespace-nowrap flex-shrink-0" style={{ animationDelay: `${PILL_DELAYS[(i + 10) % PILL_DELAYS.length]}s` }}>{topic}</span>
                                    ))}
                                    {[...TOPICS_ROW3, ...TOPICS_ROW3].map((topic, i) => (
                                        <span key={`r3b-${i}`} aria-hidden="true" className="pill-pulse inline-flex items-center px-4 py-2 rounded-full text-sm font-semibold border cursor-default whitespace-nowrap flex-shrink-0" style={{ animationDelay: `${PILL_DELAYS[(i + TOPICS_ROW3.length + 10) % PILL_DELAYS.length]}s` }}>{topic}</span>
                                    ))}
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </section>
    );
}
