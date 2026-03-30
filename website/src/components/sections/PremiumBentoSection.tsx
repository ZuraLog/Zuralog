"use client";

/**
 * PremiumBentoSection.tsx
 *
 * Premium dark features section — asymmetric glassmorphism bento grid.
 *
 * Grid layout (12-col, 24px gap):
 *   Row 1 (380px):  [All Your Health Data — col-span-7] [AI Insights — col-span-5, row-span-2]
 *   Row 2 (404px):  [Actions — col-span-3] [Proactive Coach — col-span-4] [AI Insights cont.]
 *
 * Glassmorphism spec:
 *   background: rgba(30, 30, 32, 0.72)
 *   backdrop-filter: blur(16px)
 *   border: 1px solid rgba(207, 225, 185, 0.08)
 *   border-radius: 24px
 *   hover: translateY(-4px) + Sage glow shadow + animated conic border sweep
 *
 * Glow orbs: Violet ellipse behind section heading (centered)
 */

import { useRef } from "react";
import { useGSAP } from "@gsap/react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/dist/ScrollTrigger";
import {
    Sparkles,
    Zap,
    MessageCircle,
    Target,
    CheckCircle2,
    Heart,
    Footprints,
    Moon,
    Flame,
} from "lucide-react";
import { FaApple, FaStrava, FaGoogle } from "react-icons/fa";
import { SiFitbit, SiGarmin } from "react-icons/si";

if (typeof window !== "undefined") {
    gsap.registerPlugin(ScrollTrigger);
}

/* ── Glassmorphism card base styles ─────────────────────────── */
const CARD_BASE =
    "relative overflow-hidden rounded-[24px] border border-[rgba(207,225,185,0.08)] " +
    "bg-[rgba(30,30,32,0.72)] backdrop-blur-[16px] " +
    "shadow-[0_4px_24px_rgba(0,0,0,0.35)] " +
    "transition-all duration-[350ms] ease-out group " +
    "hover:-translate-y-1 " +
    "hover:shadow-[0_0_0_1px_rgba(207,225,185,0.22),0_0_32px_rgba(207,225,185,0.10),0_16px_48px_rgba(0,0,0,0.5)]";

/* ── Health metric tiles data ───────────────────────────────── */
const METRICS = [
    { icon: Footprints, label: "Steps", value: "8,432", unit: "/ 10k", color: "#30D158" },
    { icon: Moon, label: "Sleep", value: "7h 22m", unit: "last night", color: "#5E5CE6" },
    { icon: Flame, label: "Calories", value: "1,840", unit: "burned", color: "#FF9F0A" },
    { icon: Heart, label: "Heart Rate", value: "62", unit: "bpm avg", color: "#FF375F" },
];

/* ── Integrations list ──────────────────────────────────────── */
const INTEGRATIONS = [
    { Icon: FaApple, label: "Apple Health", color: "#F0EEE9" },
    { Icon: FaStrava, label: "Strava", color: "#FC4C02" },
    { Icon: SiFitbit, label: "Fitbit", color: "#00B0B9" },
    { Icon: FaGoogle, label: "Google Fit", color: "#4285F4" },
    { Icon: SiGarmin, label: "Garmin", color: "#009DDC" },
];

/* ── Bento Card wrapper with animated conic border ─────────── */
function BentoCard({
    children,
    className = "",
    style = {},
}: {
    children: React.ReactNode;
    className?: string;
    style?: React.CSSProperties;
}) {
    return (
        <div className={`${CARD_BASE} ${className}`} style={style}>
            {/* Animated conic-gradient border sweep on hover */}
            <div
                aria-hidden="true"
                className="pointer-events-none absolute inset-[-1px] rounded-[25px] opacity-0 group-hover:opacity-100 transition-opacity duration-[350ms]"
                style={{
                    background:
                        "conic-gradient(from var(--border-angle, 0deg), transparent 0%, transparent 30%, rgba(207,225,185,0.55) 50%, transparent 70%, transparent 100%)",
                    animation: "borderSweep 2.5s linear infinite paused",
                    WebkitMask:
                        "linear-gradient(#fff 0 0) content-box, linear-gradient(#fff 0 0)",
                    WebkitMaskComposite: "xor",
                    maskComposite: "exclude",
                    padding: "1px",
                }}
                // eslint-disable-next-line react/no-unknown-property
                onMouseEnter={(e) => {
                    (e.currentTarget as HTMLElement).style.animationPlayState = "running";
                }}
                onMouseLeave={(e) => {
                    (e.currentTarget as HTMLElement).style.animationPlayState = "paused";
                }}
            />
            {children}
        </div>
    );
}

/* ── Card A: All Your Health Data ───────────────────────────── */
function HealthDataCard() {
    return (
        <BentoCard className="col-span-7 p-6 flex flex-col justify-between" style={{ height: "380px" }}>
            {/* Pattern overlay */}
            <div
                aria-hidden="true"
                className="absolute inset-0 pointer-events-none opacity-[0.07] mix-blend-screen"
                style={{
                    backgroundImage: "url('/patterns/original.png')",
                    backgroundSize: "400px 400px",
                }}
            />

            {/* Header */}
            <div>
                <div className="flex items-center gap-2 mb-1">
                    <CheckCircle2 size={16} className="text-[#CFE1B9]" />
                    <span className="text-xs font-medium text-[#CFE1B9] uppercase tracking-wider">All Your Health Data</span>
                </div>
                <h3 className="text-xl font-bold text-[#F0EEE9] mt-1">
                    Every metric. One place.
                </h3>
                <p className="text-sm text-[#9B9894] mt-1 max-w-[280px]">
                    ZuraLog syncs with 50+ apps and wearables to give you a complete picture of your health.
                </p>
            </div>

            {/* Metric tiles grid */}
            <div className="grid grid-cols-2 gap-3 mt-auto">
                {METRICS.map(({ icon: Icon, label, value, unit, color }) => (
                    <div
                        key={label}
                        className="flex items-center gap-3 rounded-[16px] bg-[rgba(22,22,24,0.6)] border border-[rgba(240,238,233,0.06)] p-3"
                    >
                        <div
                            className="w-8 h-8 rounded-[10px] flex items-center justify-center flex-shrink-0"
                            style={{ backgroundColor: `${color}20` }}
                        >
                            <Icon size={16} style={{ color }} />
                        </div>
                        <div className="min-w-0">
                            <div className="text-xs text-[#9B9894]">{label}</div>
                            <div className="text-sm font-semibold text-[#F0EEE9] truncate">
                                {value} <span className="text-[#9B9894] font-normal text-xs">{unit}</span>
                            </div>
                        </div>
                    </div>
                ))}
            </div>

            {/* Integration logos row */}
            <div className="flex items-center gap-3 mt-4 pt-4 border-t border-[rgba(240,238,233,0.06)]">
                <span className="text-xs text-[#9B9894]">Connects with</span>
                <div className="flex items-center gap-2">
                    {INTEGRATIONS.map(({ Icon, label, color }) => (
                        <div
                            key={label}
                            title={label}
                            className="w-7 h-7 rounded-full bg-[rgba(22,22,24,0.8)] border border-[rgba(240,238,233,0.08)] flex items-center justify-center"
                        >
                            <Icon size={13} style={{ color }} />
                        </div>
                    ))}
                    <span className="text-xs text-[#9B9894] ml-1">+45 more</span>
                </div>
            </div>
        </BentoCard>
    );
}

/* ── Card B: AI Insights (tall, row-span-2) ─────────────────── */
function AIInsightsCard() {
    return (
        <BentoCard
            className="col-span-5 row-span-2 p-6 flex flex-col"
            style={{ gridRow: "span 2" }}
        >
            {/* Periwinkle (sleep) pattern overlay */}
            <div
                aria-hidden="true"
                className="absolute inset-0 pointer-events-none opacity-[0.07] mix-blend-screen"
                style={{
                    backgroundImage: "url('/patterns/periwinkle.png')",
                    backgroundSize: "400px 400px",
                }}
            />

            {/* Header */}
            <div className="flex items-center gap-2 mb-4">
                <Sparkles size={16} className="text-[#5E5CE6]" />
                <span className="text-xs font-medium text-[#5E5CE6] uppercase tracking-wider">AI Insights</span>
            </div>

            <h3 className="text-xl font-bold text-[#F0EEE9] mb-2">
                Your health, explained.
            </h3>
            <p className="text-sm text-[#9B9894] mb-6">
                ZuraLog&apos;s AI discovers patterns across your data and surfaces what actually matters.
            </p>

            {/* Insight cards stack */}
            <div className="flex flex-col gap-3 flex-1">
                {/* Primary insight */}
                <div className="rounded-[16px] bg-[rgba(94,92,230,0.08)] border border-[rgba(94,92,230,0.2)] p-4">
                    <div className="flex items-start gap-2 mb-2">
                        <Sparkles size={14} className="text-[#5E5CE6] mt-0.5 flex-shrink-0" />
                        <span className="text-xs font-medium text-[#5E5CE6]">Sleep pattern detected</span>
                    </div>
                    <p className="text-sm text-[#F0EEE9] leading-relaxed">
                        Your sleep quality improves{" "}
                        <span className="text-[#CFE1B9] font-semibold">23%</span> on days you
                        exercise before 9am.
                    </p>
                    <div className="mt-3 flex items-center gap-2">
                        <div className="h-1.5 flex-1 rounded-full bg-[rgba(94,92,230,0.2)] overflow-hidden">
                            <div className="h-full rounded-full bg-[#5E5CE6]" style={{ width: "78%" }} />
                        </div>
                        <span className="text-xs text-[#9B9894]">78% confidence</span>
                    </div>
                </div>

                {/* Secondary insight */}
                <div className="rounded-[16px] bg-[rgba(30,30,32,0.8)] border border-[rgba(240,238,233,0.06)] p-4">
                    <div className="flex items-start gap-2 mb-2">
                        <Heart size={14} className="text-[#FF375F] mt-0.5 flex-shrink-0" />
                        <span className="text-xs font-medium text-[#FF375F]">Recovery insight</span>
                    </div>
                    <p className="text-sm text-[#9B9894] leading-relaxed">
                        Resting heart rate dropped{" "}
                        <span className="text-[#CFE1B9] font-semibold">8 bpm</span> over the last
                        30 days. You&apos;re trending in the right direction.
                    </p>
                </div>

                {/* Activity insight */}
                <div className="rounded-[16px] bg-[rgba(30,30,32,0.8)] border border-[rgba(240,238,233,0.06)] p-4">
                    <div className="flex items-start gap-2 mb-2">
                        <Zap size={14} className="text-[#30D158] mt-0.5 flex-shrink-0" />
                        <span className="text-xs font-medium text-[#30D158]">Weekly summary</span>
                    </div>
                    <p className="text-sm text-[#9B9894] leading-relaxed">
                        You hit your activity goal{" "}
                        <span className="text-[#CFE1B9] font-semibold">5 of 7 days</span> this
                        week — your best streak yet.
                    </p>
                </div>
            </div>

            {/* Footer CTA */}
            <div className="mt-4 pt-4 border-t border-[rgba(240,238,233,0.06)]">
                <span className="text-xs text-[#9B9894]">
                    New insights generated daily based on your data.
                </span>
            </div>
        </BentoCard>
    );
}

/* ── Card C: Actions / Coach Chat ───────────────────────────── */
function ActionsCard() {
    return (
        <BentoCard className="col-span-3 p-6 flex flex-col justify-between" style={{ height: "404px" }}>
            {/* Pattern overlay */}
            <div
                aria-hidden="true"
                className="absolute inset-0 pointer-events-none opacity-[0.07] mix-blend-screen"
                style={{
                    backgroundImage: "url('/patterns/original.png')",
                    backgroundSize: "400px 400px",
                }}
            />

            {/* Header */}
            <div>
                <div className="flex items-center gap-2 mb-1">
                    <MessageCircle size={16} className="text-[#CFE1B9]" />
                    <span className="text-xs font-medium text-[#CFE1B9] uppercase tracking-wider">AI Coach</span>
                </div>
                <h3 className="text-lg font-bold text-[#F0EEE9] mt-1">
                    Ask anything.
                </h3>
            </div>

            {/* Chat preview */}
            <div className="flex flex-col gap-3 mt-4 flex-1">
                {/* User message */}
                <div className="self-end max-w-[85%]">
                    <div className="rounded-[14px] rounded-tr-[4px] bg-[rgba(207,225,185,0.12)] border border-[rgba(207,225,185,0.15)] px-3 py-2">
                        <p className="text-sm text-[#F0EEE9]">Why do I feel tired after lunch?</p>
                    </div>
                </div>

                {/* Coach response */}
                <div className="self-start max-w-[90%]">
                    <div className="rounded-[14px] rounded-tl-[4px] bg-[rgba(30,30,32,0.9)] border border-[rgba(240,238,233,0.08)] px-3 py-2">
                        <p className="text-sm text-[#9B9894] leading-relaxed">
                            Based on your data, your energy dips ~2hrs after lunch because your sleep
                            debt is{" "}
                            <span className="text-[#CFE1B9]">1h 20m</span> this week. Try a 20-min
                            walk right after eating.
                        </p>
                    </div>
                </div>

                {/* Typing indicator */}
                <div className="self-start">
                    <div className="rounded-[14px] rounded-tl-[4px] bg-[rgba(30,30,32,0.9)] border border-[rgba(240,238,233,0.08)] px-4 py-3 flex items-center gap-1.5">
                        {[0, 0.3, 0.6].map((delay) => (
                            <div
                                key={delay}
                                className="w-1.5 h-1.5 rounded-full bg-[#9B9894] animate-bounce"
                                style={{ animationDelay: `${delay}s` }}
                            />
                        ))}
                    </div>
                </div>
            </div>

            <p className="text-xs text-[#9B9894] mt-4">
                Available 24/7 — always in context with your data.
            </p>
        </BentoCard>
    );
}

/* ── Card D: Proactive Coach ────────────────────────────────── */
function ProactiveCoachCard() {
    return (
        <BentoCard className="col-span-4 p-6 flex flex-col justify-between" style={{ height: "404px" }}>
            {/* Pattern overlay */}
            <div
                aria-hidden="true"
                className="absolute inset-0 pointer-events-none opacity-[0.07] mix-blend-screen"
                style={{
                    backgroundImage: "url('/patterns/sage.png')",
                    backgroundSize: "400px 400px",
                }}
            />

            {/* Header */}
            <div>
                <div className="flex items-center gap-2 mb-1">
                    <Target size={16} className="text-[#CFE1B9]" />
                    <span className="text-xs font-medium text-[#CFE1B9] uppercase tracking-wider">Today&apos;s Actions</span>
                </div>
                <h3 className="text-lg font-bold text-[#F0EEE9] mt-1">
                    Your coach&apos;s plan.
                </h3>
                <p className="text-sm text-[#9B9894] mt-1">
                    Personalized actions based on your data, not generic advice.
                </p>
            </div>

            {/* Action cards */}
            <div className="flex flex-col gap-3 mt-4 flex-1">
                {/* Primary action */}
                <div className="rounded-[16px] bg-[rgba(207,225,185,0.08)] border border-[rgba(207,225,185,0.15)] p-4">
                    <div className="flex items-center justify-between mb-2">
                        <div className="flex items-center gap-2">
                            <Footprints size={14} className="text-[#CFE1B9]" />
                            <span className="text-sm font-semibold text-[#F0EEE9]">Complete 8,000 steps</span>
                        </div>
                        <span className="text-xs text-[#9B9894]">Today</span>
                    </div>
                    {/* Progress bar */}
                    <div className="h-1.5 w-full rounded-full bg-[rgba(207,225,185,0.15)] overflow-hidden">
                        <div
                            className="h-full rounded-full bg-[#CFE1B9]"
                            style={{ width: "61%" }}
                        />
                    </div>
                    <div className="flex justify-between mt-1.5">
                        <span className="text-xs text-[#9B9894]">4,872 steps so far</span>
                        <span className="text-xs text-[#CFE1B9] font-medium">61%</span>
                    </div>
                </div>

                {/* Secondary action */}
                <div className="rounded-[16px] bg-[rgba(30,30,32,0.8)] border border-[rgba(240,238,233,0.06)] p-4">
                    <div className="flex items-center justify-between">
                        <div className="flex items-center gap-2">
                            <Moon size={14} className="text-[#5E5CE6]" />
                            <span className="text-sm text-[#F0EEE9]">Wind down by 10pm</span>
                        </div>
                        <div className="w-5 h-5 rounded-full border border-[rgba(240,238,233,0.12)]" />
                    </div>
                </div>

                {/* Tertiary action */}
                <div className="rounded-[16px] bg-[rgba(30,30,32,0.8)] border border-[rgba(240,238,233,0.06)] p-4">
                    <div className="flex items-center justify-between">
                        <div className="flex items-center gap-2">
                            <Zap size={14} className="text-[#FF9F0A]" />
                            <span className="text-sm text-[#F0EEE9]">Post-lunch 20-min walk</span>
                        </div>
                        <div className="w-5 h-5 rounded-full border border-[rgba(240,238,233,0.12)]" />
                    </div>
                </div>
            </div>
        </BentoCard>
    );
}

/* ── Main Section ───────────────────────────────────────────── */
export function PremiumBentoSection() {
    const sectionRef = useRef<HTMLElement>(null);

    useGSAP(
        () => {
            gsap.fromTo(
                ".bento-card-reveal",
                { opacity: 0, y: 40 },
                {
                    opacity: 1,
                    y: 0,
                    duration: 0.8,
                    stagger: 0.1,
                    ease: "power3.out",
                    scrollTrigger: {
                        trigger: sectionRef.current,
                        start: "top 80%",
                        once: true,
                    },
                }
            );
        },
        { scope: sectionRef }
    );

    return (
        <section
            id="bento-section"
            ref={sectionRef}
            className="relative w-full py-24 px-4 overflow-hidden"
        >
            {/* ── Violet glow orb — centered behind section heading ── */}
            <div
                aria-hidden="true"
                className="absolute pointer-events-none"
                style={{
                    width: "600px",
                    height: "400px",
                    top: "0px",
                    left: "50%",
                    transform: "translateX(-50%)",
                    background:
                        "radial-gradient(ellipse, rgba(94,92,230,0.10) 0%, transparent 70%)",
                }}
            />

            <div className="relative z-10 max-w-[1280px] mx-auto">
                {/* Section heading */}
                <div className="text-center mb-14 bento-card-reveal">
                    <div className="inline-flex items-center gap-2 border border-[rgba(207,225,185,0.15)] rounded-full px-4 py-1.5 mb-4 bg-[rgba(207,225,185,0.05)]">
                        <Sparkles size={12} className="text-[#CFE1B9]" />
                        <span className="text-xs font-medium text-[#CFE1B9] uppercase tracking-wider">Features</span>
                    </div>
                    <h2 className="text-4xl md:text-5xl font-bold text-[#F0EEE9] tracking-tight">
                        Everything you need to{" "}
                        <span className="text-topo-pattern">thrive.</span>
                    </h2>
                    <p className="text-lg text-[#9B9894] mt-4 max-w-[520px] mx-auto">
                        Built around your data, powered by AI, designed for how you actually live.
                    </p>
                </div>

                {/* ── Bento grid ── */}
                <div
                    className="grid gap-6"
                    style={{
                        gridTemplateColumns: "repeat(12, 1fr)",
                        gridTemplateRows: "380px 404px",
                    }}
                >
                    <div className="bento-card-reveal col-span-12 md:col-span-7">
                        <HealthDataCard />
                    </div>
                    <div
                        className="bento-card-reveal col-span-12 md:col-span-5 md:row-span-2"
                        style={{ gridRow: "span 2" }}
                    >
                        <AIInsightsCard />
                    </div>
                    <div className="bento-card-reveal col-span-12 md:col-span-3">
                        <ActionsCard />
                    </div>
                    <div className="bento-card-reveal col-span-12 md:col-span-4">
                        <ProactiveCoachCard />
                    </div>
                </div>
            </div>
        </section>
    );
}
