"use client";

/**
 * DashboardBento.tsx
 *
 * The "Unified Dashboard" bento card — Card 4 in the bento grid.
 *
 * Extracted into its own file so it can be imported with `dynamic({ ssr: false })`
 * from BentoSection. This is required because DashboardMetricCard uses Math.random()
 * inside useState's lazy initialiser and setInterval callbacks, which causes a
 * SSR/CSR hydration mismatch if rendered on the server.
 *
 * Animations:
 *   - Framer Motion 3D Y-axis flip when a card identity changes (AnimatePresence)
 *   - GSAP slot-machine ticker + progress bar refill on value updates
 *   - CSS dashboardFloat idle float per tile (staggered by slot index)
 *   - GSAP magnetic 3D tilt on the outer card (mousemove)
 */

import { useRef, useState, useEffect } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/dist/ScrollTrigger";
import { AnimatePresence, motion } from "framer-motion";
import {
    LayoutDashboard,
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

interface SlotSnapshot {
    cardId: string;
    label: string;
    Icon: React.ComponentType<{ size?: number; style?: React.CSSProperties; className?: string }>;
    iconColor: string;
    value: string;
    sub: string;
    status: MetricStatus;
    progress: number;
    /** Incremented each time the value changes within the same card */
    valueKey: number;
    /** Incremented each time the card identity changes, drives 3D swap flip */
    cardKey: number;
}

interface DashboardMetricCardProps {
    snapshot: SlotSnapshot;
    slotIndex: number;
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
    {
        id: "cal-intake",
        label: "Cal. Intake",
        Icon: Apple,
        iconColor: "#16a34a",
        generate: () => {
            const target = 2200;
            const intake = rand(900, 3200);
            const diff = intake - target;
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
    {
        id: "resting-hr",
        label: "Resting HR",
        Icon: Activity,
        iconColor: "#db2777",
        generate: () => {
            const bpm = rand(44, 92);
            const pct = Math.round(((bpm - 44) / (92 - 44)) * 100);
            const status = progressToStatus(pct, true);
            return {
                value: `${bpm} bpm`,
                sub: bpm < 60 ? "Athletic range" : bpm < 75 ? "Normal range" : "Above normal",
                status,
                progress: pct,
            };
        },
    },
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
    {
        id: "stress",
        label: "Stress",
        Icon: Brain,
        iconColor: "#9333ea",
        generate: () => {
            const score = rand(10, 92);
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
// Slot helpers (client-only, use Math.random — safe here since
// this file is never SSR'd thanks to dynamic({ ssr: false }))
// ─────────────────────────────────────────────────────────────

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

/**
 * Renders one metric tile inside the Dashboard bento.
 *
 * Animations:
 * - Framer Motion AnimatePresence + Y-axis 3D flip when cardKey changes
 * - GSAP slot-machine counter + progress bar refill when valueKey changes
 * - CSS dashboardFloat idle float (staggered by slotIndex)
 * - Status-based background tint, border, and value colour
 */
function DashboardMetricCard({ snapshot, slotIndex }: DashboardMetricCardProps) {
    const valueRef = useRef<HTMLSpanElement>(null);
    const barFillRef = useRef<HTMLDivElement>(null);
    const prevValueRef = useRef<string>(snapshot.value);
    const prevProgressRef = useRef<number>(snapshot.progress);

    const styles = STATUS_STYLES[snapshot.status];

    useEffect(() => {
        if (prevValueRef.current === snapshot.value) return;
        prevValueRef.current = snapshot.value;

        if (barFillRef.current) {
            gsap.fromTo(barFillRef.current,
                { width: `${prevProgressRef.current}%` },
                { width: `${snapshot.progress}%`, duration: 0.9, ease: "power2.out", delay: 0.15 }
            );
        }
        prevProgressRef.current = snapshot.progress;

        if (valueRef.current) {
            gsap.fromTo(valueRef.current,
                { y: 0, opacity: 1 },
                {
                    y: -18, opacity: 0, duration: 0.18, ease: "power2.in",
                    onComplete: () => {
                        gsap.fromTo(valueRef.current,
                            { y: 18, opacity: 0 },
                            { y: 0, opacity: 1, duration: 0.28, ease: "back.out(1.8)" }
                        );
                    },
                }
            );
        }
    }, [snapshot.value, snapshot.progress]);

    return (
        <motion.div
            key={snapshot.cardKey}
            initial={{ rotateY: -90, opacity: 0, scale: 0.9 }}
            animate={{ rotateY: 0, opacity: 1, scale: 1 }}
            exit={{ rotateY: 90, opacity: 0, scale: 0.9 }}
            transition={{ type: "spring", stiffness: 260, damping: 22, delay: slotIndex * 0.06 }}
            style={{
                transformStyle: "preserve-3d",
                animation: `dashboardFloat 3.4s ease-in-out infinite`,
                animationDelay: `${slotIndex * 0.85}s`,
            }}
            className="dashboard-metric-tile rounded-2xl p-4 border relative overflow-hidden"
        >
            <div className="absolute inset-0 rounded-2xl pointer-events-none transition-colors duration-700" style={{ backgroundColor: styles.bg }} />
            <div className="absolute inset-0 rounded-2xl pointer-events-none transition-colors duration-700" style={{ border: `1.5px solid ${styles.border}` }} />

            <div className="relative z-10 flex flex-col h-full">
                <div className="flex items-center justify-between mb-2">
                    <div className="flex items-center gap-1.5">
                        <snapshot.Icon size={13} style={{ color: snapshot.iconColor }} />
                        <p className="text-[10px] font-bold text-gray-500 uppercase tracking-wider">{snapshot.label}</p>
                    </div>
                    <div
                        className="w-2 h-2 rounded-full flex-shrink-0"
                        style={{ backgroundColor: styles.dot, boxShadow: `0 0 6px ${styles.dot}88` }}
                    />
                </div>

                <div className="overflow-hidden">
                    <span ref={valueRef} className="block text-[19px] font-black leading-none" style={{ color: styles.valuColor }}>
                        {snapshot.value}
                    </span>
                </div>

                <p className="text-[10px] font-medium text-gray-400 mt-1 leading-snug line-clamp-1">{snapshot.sub}</p>

                <div className="mt-auto pt-2.5">
                    <div className="h-1 rounded-full bg-gray-100 overflow-hidden">
                        <div
                            ref={barFillRef}
                            className="h-full rounded-full transition-colors duration-700"
                            style={{ width: `${snapshot.progress}%`, backgroundColor: styles.barColor }}
                        />
                    </div>
                </div>
            </div>
        </motion.div>
    );
}

// ─────────────────────────────────────────────────────────────
// DashboardBento — exported default (required for dynamic import)
// ─────────────────────────────────────────────────────────────

/**
 * The "Unified Dashboard" bento card.
 *
 * Manages a 4-slot cycling display from a pool of 10 metric definitions.
 * Each slot cycles independently on a staggered interval.
 *
 * Must be imported with `dynamic({ ssr: false })` — this component uses
 * Math.random() which would cause a hydration mismatch if SSR'd.
 */
export default function DashboardBento() {
    const [slots, setSlots] = useState<SlotSnapshot[]>(() => initSlots());
    const cardRef = useRef<HTMLDivElement>(null);

    // Staggered slot cycling — 4 independent timers, offset by slot index
    useEffect(() => {
        const BASE_INTERVAL = 3000;
        const SLOT_OFFSET = 1100;

        const timeouts: ReturnType<typeof setTimeout>[] = [];
        const intervals: ReturnType<typeof setInterval>[] = [];

        [0, 1, 2, 3].forEach((slotIdx) => {
            const tick = () => {
                setSlots(prev => {
                    const next = [...prev];
                    const current = next[slotIdx];
                    const shouldSwapCard = Math.random() < 0.30;

                    if (shouldSwapCard) {
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
                        const card = METRIC_POOL.find(c => c.id === current.cardId)!;
                        const snap = card.generate();
                        next[slotIdx] = { ...current, ...snap, valueKey: current.valueKey + 1 };
                    }

                    return next;
                });
            };

            const t = setTimeout(() => {
                tick();
                const iv = setInterval(tick, BASE_INTERVAL);
                intervals.push(iv);
            }, slotIdx * SLOT_OFFSET);

            timeouts.push(t);
        });

        return () => {
            timeouts.forEach(clearTimeout);
            intervals.forEach(clearInterval);
        };
    }, []);

    // Magnetic 3D tilt on outer card (GSAP)
    useEffect(() => {
        const card = cardRef.current;
        if (!card) return;

        const handleMouseMove = (e: MouseEvent) => {
            const rect = card.getBoundingClientRect();
            const cx = rect.left + rect.width / 2;
            const cy = rect.top + rect.height / 2;
            const dx = e.clientX - cx;
            const dy = e.clientY - cy;
            const maxTilt = 6;
            gsap.to(card, {
                rotateX: (-dy / (rect.height / 2)) * maxTilt,
                rotateY: (dx / (rect.width / 2)) * maxTilt,
                transformPerspective: 900,
                duration: 0.35,
                ease: "power2.out",
            });
        };

        const handleMouseLeave = () => {
            gsap.to(card, { rotateX: 0, rotateY: 0, duration: 0.8, ease: "elastic.out(1, 0.45)" });
        };

        card.addEventListener("mousemove", handleMouseMove);
        card.addEventListener("mouseleave", handleMouseLeave);

        return () => {
            card.removeEventListener("mousemove", handleMouseMove);
            card.removeEventListener("mouseleave", handleMouseLeave);
        };
    }, []);

    // Scroll-triggered entrance — must live here because this component is
    // loaded via dynamic() and won't exist when BentoSection's useGSAP runs.
    useEffect(() => {
        const card = cardRef.current;
        if (!card) return;

        gsap.registerPlugin(ScrollTrigger);

        const tween = gsap.fromTo(
            card,
            { opacity: 0, y: 70, scale: 0.92, rotateX: 12, transformPerspective: 1200 },
            {
                opacity: 1,
                y: 0,
                scale: 1,
                rotateX: 0,
                duration: 1.1,
                ease: "elastic.out(1, 0.65)",
                scrollTrigger: {
                    trigger: card,
                    start: "top 78%",
                    toggleActions: "play none none none",
                },
                onComplete: () => {
                    // Stagger-pop the metric tiles in after card entrance
                    const tiles = card.querySelectorAll(".dashboard-metric-tile");
                    gsap.fromTo(
                        tiles,
                        { opacity: 0, scale: 0.8, y: 20 },
                        { opacity: 1, scale: 1, y: 0, stagger: 0.1, duration: 0.55, ease: "back.out(2)" }
                    );
                },
            }
        );

        return () => {
            tween.kill();
            ScrollTrigger.getAll().forEach(st => {
                if (st.trigger === card) st.kill();
            });
        };
    }, []);

    return (
        <div
            ref={cardRef}
            data-card="dashboard"
            className="bento-card dashboard-bento group relative bg-white rounded-3xl p-7 lg:p-8 shadow-xl overflow-hidden opacity-0"
            style={{ gridColumn: "1 / 3", gridRow: "2", transformStyle: "preserve-3d", willChange: "transform" }}
        >
            {/* Subtle inner glow on hover */}
            <div
                className="absolute inset-0 rounded-3xl pointer-events-none transition-opacity duration-300 opacity-0 group-hover:opacity-100"
                style={{ boxShadow: "inset 0 0 40px rgba(232,245,168,0.12)" }}
            />

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
                    <div className="flex items-center gap-1.5 mt-4">
                        <div className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
                        <span className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">Live data</span>
                    </div>
                </div>

                {/* Right: 2×2 cycling metric grid */}
                <div className="flex-1 grid grid-cols-2 gap-3" style={{ perspective: "600px" }}>
                    <AnimatePresence mode="popLayout">
                        {slots.map((slot, i) => (
                            <DashboardMetricCard key={`slot-${i}`} snapshot={slot} slotIndex={i} />
                        ))}
                    </AnimatePresence>
                </div>
            </div>
        </div>
    );
}
