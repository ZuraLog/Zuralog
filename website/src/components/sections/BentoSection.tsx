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
 */

import { useRef } from "react";
import { useGSAP } from "@gsap/react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/dist/ScrollTrigger";
import {
    Zap,
    Users,
    LayoutDashboard,
    Smartphone,
    Sparkles,
    CheckCircle2,
    Plus,
    ChevronRight,
} from "lucide-react";
import {
    FaStrava,
    FaApple,
} from "react-icons/fa";
import { SiFitbit, SiGarmin } from "react-icons/si";
import { FcGoogle } from "react-icons/fc";

// Register GSAP ScrollTrigger plugin on client side
if (typeof window !== "undefined") {
    gsap.registerPlugin(ScrollTrigger);
}

// ─────────────────────────────────────────────────────────────
// App icon data for the "50+ Integrations" tall card
// ─────────────────────────────────────────────────────────────
const INTEGRATION_ICONS = [
    { icon: <FaStrava className="text-[#FC4C02]" size={22} />, name: "Strava" },
    { icon: <FaApple className="text-gray-800" size={22} />, name: "Apple" },
    { icon: <FcGoogle size={22} />, name: "Health Connect" },
    { icon: <SiFitbit className="text-[#00B0B9]" size={22} />, name: "Fitbit" },
    { icon: <SiGarmin className="text-[#007CC3]" size={22} />, name: "Garmin" },
    {
        icon: (
            <span className="font-black text-white text-xs bg-[#1A1A2E] w-full h-full flex items-center justify-center rounded-xl">
                O
            </span>
        ),
        name: "Oura",
    },
    {
        icon: (
            <span className="font-black text-white text-xs bg-gray-900 w-full h-full flex items-center justify-center rounded-xl">
                W
            </span>
        ),
        name: "WHOOP",
    },
    {
        icon: (
            <span className="font-bold text-white text-xs bg-[#E00025] w-full h-full flex items-center justify-center rounded-xl">
                C
            </span>
        ),
        name: "CalAI",
    },
    {
        icon: (
            <span className="font-bold text-white text-xs bg-[#0066FF] w-full h-full flex items-center justify-center rounded-xl">
                MFP
            </span>
        ),
        name: "MyFitnessPal",
    },
    {
        icon: (
            <span className="font-bold text-white text-xs bg-[#F97316] w-full h-full flex items-center justify-center rounded-xl">
                N
            </span>
        ),
        name: "Nike Run",
    },
    {
        icon: (
            <span className="font-bold text-white text-xs bg-[#FF2D55] w-full h-full flex items-center justify-center rounded-xl">
                P
            </span>
        ),
        name: "Peloton",
    },
    {
        icon: (
            <span className="font-bold text-white text-xs bg-[#6366F1] w-full h-full flex items-center justify-center rounded-xl">
                +
            </span>
        ),
        name: "More",
    },
];

// ─────────────────────────────────────────────────────────────
// Fake user avatars for the "Community" card
// ─────────────────────────────────────────────────────────────
const AVATAR_COLORS = [
    "#F97316", // orange
    "#3B82F6", // blue
    "#10B981", // green
    "#8B5CF6", // purple
];

const AVATAR_INITIALS = ["A", "J", "M", "S"];

// ─────────────────────────────────────────────────────────────
// Topic pills for "Personalized for You" card
// ─────────────────────────────────────────────────────────────
const TOPICS = [
    "Sleep", "Nutrition", "Fitness", "Mental Health",
    "Recovery", "HRV", "Cardio", "Strength",
    "Hydration", "Weight", "Steps", "Macros",
    "Zone 2", "Longevity", "Stress",
];

// ─────────────────────────────────────────────────────────────
// Dashboard metric preview data
// ─────────────────────────────────────────────────────────────
const DASHBOARD_METRICS = [
    { label: "HRV", value: "68ms", change: "+12%", positive: true },
    { label: "Sleep", value: "7h 42m", change: "Deep: 1h 22m", positive: true },
    { label: "Steps", value: "9,820", change: "84% of goal", positive: true },
    { label: "Calories", value: "2,340", change: "Of 2,800 goal", positive: true },
];

// ─────────────────────────────────────────────────────────────
// Connect card steps
// ─────────────────────────────────────────────────────────────
const CONNECT_STEPS = [
    { label: "Link your apps", done: true },
    { label: "ZuraLog reads your data", done: true },
    { label: "AI generates insights", done: false },
];

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

            // Staggered card entrance
            cards.forEach((card, i) => {
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
                {/*
                    Grid layout (desktop):
                    Col 1  | Col 2       | Col 3
                    ────────────────────────────
                    Connect | Community  | Integrations (rows 1-2)
                    Dashboard ──────────| Integrations (cont.)
                    Free   | Personalized ────────────
                */}
                <div
                    className="grid gap-4 lg:gap-5"
                    style={{
                        gridTemplateColumns: "repeat(3, 1fr)",
                        gridTemplateRows: "auto auto auto",
                    }}
                >
                    {/* ══ Card 1: CONNECT ══ */}
                    <div
                        className="bento-card group relative bg-white rounded-3xl p-7 lg:p-8 shadow-xl overflow-hidden
                                   hover:-translate-y-1 hover:shadow-2xl transition-all duration-200 opacity-0"
                        style={{ gridColumn: "1", gridRow: "1" }}
                    >
                        {/* Decorative lime accent dot */}
                        <div className="absolute top-6 right-6 w-3 h-3 rounded-full bg-[#E8F5A8]" />

                        <div className="flex items-center gap-3 mb-5">
                            <div className="w-11 h-11 rounded-2xl bg-[#E8F5A8] flex items-center justify-center flex-shrink-0">
                                <Zap size={20} className="text-gray-900" />
                            </div>
                            <div>
                                <h3 className="text-xl font-bold text-gray-900">Connect</h3>
                                <p className="text-xs text-gray-500 font-medium">One-tap integration</p>
                            </div>
                        </div>

                        <p className="text-sm text-gray-600 leading-relaxed mb-6">
                            Link your favorite apps in seconds. ZuraLog handles the rest — no manual imports, no friction.
                        </p>

                        {/* Steps */}
                        <div className="flex flex-col gap-2.5">
                            {CONNECT_STEPS.map((step, i) => (
                                <div key={i} className="flex items-center gap-3">
                                    <CheckCircle2
                                        size={16}
                                        className={step.done ? "text-[#4CAF50] flex-shrink-0" : "text-gray-300 flex-shrink-0"}
                                    />
                                    <span
                                        className={`text-sm font-medium ${
                                            step.done ? "text-gray-700" : "text-gray-400"
                                        }`}
                                    >
                                        {step.label}
                                    </span>
                                </div>
                            ))}
                        </div>

                        {/* App pills */}
                        <div className="mt-6 flex flex-wrap gap-2">
                            {[
                                { icon: <FaStrava className="text-[#FC4C02]" size={12} />, name: "Strava" },
                                { icon: <FaApple size={12} />, name: "Apple Health" },
                                { icon: <SiFitbit className="text-[#00B0B9]" size={12} />, name: "Fitbit" },
                            ].map((app) => (
                                <div
                                    key={app.name}
                                    className="flex items-center gap-1.5 bg-gray-50 border border-gray-100 rounded-full px-3 py-1.5 text-xs font-medium text-gray-600"
                                >
                                    {app.icon}
                                    {app.name}
                                </div>
                            ))}
                        </div>
                    </div>

                    {/* ══ Card 2: COMMUNITY ══ */}
                    <div
                        className="bento-card group relative bg-white rounded-3xl p-7 lg:p-8 shadow-xl overflow-hidden
                                   hover:-translate-y-1 hover:shadow-2xl transition-all duration-200 opacity-0"
                        style={{ gridColumn: "2", gridRow: "1" }}
                    >
                        {/* Overlapping avatars */}
                        <div className="flex items-center mb-5 -space-x-3">
                            {AVATAR_COLORS.map((color, i) => (
                                <div
                                    key={i}
                                    className="w-10 h-10 rounded-full border-2 border-white flex items-center justify-center text-white text-sm font-bold flex-shrink-0 shadow-sm"
                                    style={{ backgroundColor: color, zIndex: AVATAR_COLORS.length - i }}
                                >
                                    {AVATAR_INITIALS[i]}
                                </div>
                            ))}
                            {/* Plus button */}
                            <div
                                className="w-10 h-10 rounded-full border-2 border-white flex items-center justify-center flex-shrink-0 shadow-sm cursor-pointer hover:scale-110 transition-transform"
                                style={{ backgroundColor: "#E8F5A8", zIndex: 0 }}
                            >
                                <Plus size={16} className="text-gray-900" />
                            </div>
                        </div>

                        <h3 className="text-xl font-bold text-gray-900 mb-2">Join the Community</h3>
                        <p className="text-sm text-gray-600 leading-relaxed">
                            Connect with fellow wellness seekers. Like-minded individuals and experts eager to share health insights.
                        </p>

                        {/* Stat pill */}
                        <div className="mt-6 inline-flex items-center gap-2 bg-[#E8F5A8] rounded-full px-4 py-2">
                            <Users size={14} className="text-gray-800" />
                            <span className="text-xs font-semibold text-gray-800">2,400+ early members</span>
                        </div>
                    </div>

                    {/* ══ Card 3: INTEGRATIONS (tall, spans rows 1-2) ══ */}
                    <div
                        className="bento-card group relative bg-white rounded-3xl p-7 lg:p-8 shadow-xl overflow-hidden
                                   hover:-translate-y-1 hover:shadow-2xl transition-all duration-200 opacity-0"
                        style={{ gridColumn: "3", gridRow: "1 / 3" }}
                    >
                        <h3 className="text-2xl font-bold text-gray-900 mb-1">50+ Integrations</h3>
                        <p className="text-sm text-gray-500 mb-6 leading-relaxed">
                            From Apple Health to Strava, Fitbit to MyFitnessPal — every app you love, connected.
                        </p>

                        {/* App icon grid */}
                        <div className="grid grid-cols-3 gap-3 mb-6">
                            {INTEGRATION_ICONS.map((item, i) => (
                                <div
                                    key={i}
                                    className="group/icon flex flex-col items-center gap-1.5"
                                    title={item.name}
                                >
                                    <div className="w-12 h-12 rounded-2xl bg-gray-50 border border-gray-100 flex items-center justify-center shadow-sm group-hover/icon:scale-110 group-hover/icon:shadow-md transition-all duration-150 overflow-hidden">
                                        {item.icon}
                                    </div>
                                    <span className="text-[10px] text-gray-500 font-medium truncate w-full text-center">
                                        {item.name}
                                    </span>
                                </div>
                            ))}
                        </div>

                        {/* Bottom text */}
                        <div className="mt-auto pt-4 border-t border-gray-100">
                            <p className="text-xs text-gray-500 leading-relaxed">
                                Explore dozens of health tools, all talking to each other.
                            </p>
                            <button className="mt-3 flex items-center gap-1.5 text-sm font-semibold text-gray-900 hover:text-[#2D2D2D] group/btn transition-colors">
                                See all integrations
                                <ChevronRight size={14} className="group-hover/btn:translate-x-0.5 transition-transform" />
                            </button>
                        </div>
                    </div>

                    {/* ══ Card 4: UNIFIED DASHBOARD (wide, spans cols 1-2) ══ */}
                    <div
                        className="bento-card group relative bg-white rounded-3xl p-7 lg:p-8 shadow-xl overflow-hidden
                                   hover:-translate-y-1 hover:shadow-2xl transition-all duration-200 opacity-0"
                        style={{ gridColumn: "1 / 3", gridRow: "2" }}
                    >
                        <div className="flex flex-col lg:flex-row gap-6 h-full">
                            {/* Left: Title */}
                            <div className="flex-shrink-0 lg:w-[220px]">
                                <div className="w-11 h-11 rounded-2xl bg-gray-900 flex items-center justify-center mb-4">
                                    <LayoutDashboard size={20} className="text-[#E8F5A8]" />
                                </div>
                                <h3 className="text-xl font-bold text-gray-900 mb-2">Your Unified Dashboard</h3>
                                <p className="text-sm text-gray-600 leading-relaxed">
                                    All your health data in one beautiful, intelligent view.
                                </p>
                            </div>

                            {/* Right: Metric cards preview */}
                            <div className="flex-1 grid grid-cols-2 gap-3">
                                {DASHBOARD_METRICS.map((metric) => (
                                    <div
                                        key={metric.label}
                                        className="bg-gray-50 rounded-2xl p-4 border border-gray-100"
                                    >
                                        <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1">
                                            {metric.label}
                                        </p>
                                        <p className="text-xl font-bold text-gray-900">{metric.value}</p>
                                        <p className={`text-xs font-medium mt-1 ${metric.positive ? "text-green-600" : "text-red-500"}`}>
                                            {metric.change}
                                        </p>
                                    </div>
                                ))}
                            </div>
                        </div>
                    </div>

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
                                <div
                                    className="h-full bg-gray-900/30 rounded-full"
                                    style={{ width: "65%" }}
                                />
                            </div>
                            <span className="text-xs font-semibold text-gray-700">65% claimed</span>
                        </div>
                        <button className="mt-5 w-full bg-gray-900 text-white text-sm font-semibold py-3 rounded-2xl hover:bg-gray-800 transition-colors shadow-md">
                            Claim Your Spot →
                        </button>
                    </div>

                    {/* ══ Card 6: PERSONALIZED FOR YOU (wide, spans cols 2-3) ══ */}
                    <div
                        className="bento-card group relative bg-white rounded-3xl p-7 lg:p-8 shadow-xl overflow-hidden
                                   hover:-translate-y-1 hover:shadow-2xl transition-all duration-200 opacity-0"
                        style={{ gridColumn: "2 / 4", gridRow: "3" }}
                    >
                        <div className="flex items-center gap-3 mb-4">
                            <div className="w-11 h-11 rounded-2xl bg-gray-900 flex items-center justify-center flex-shrink-0">
                                <Sparkles size={20} className="text-[#E8F5A8]" />
                            </div>
                            <div>
                                <h3 className="text-xl font-bold text-gray-900">Personalized for You</h3>
                                <p className="text-xs text-gray-500 font-medium">AI-powered insights based on YOUR data</p>
                            </div>
                        </div>

                        {/* Topic pills */}
                        <div className="flex flex-wrap gap-2">
                            {TOPICS.map((topic, i) => (
                                <span
                                    key={topic}
                                    className="inline-flex items-center px-3 py-1.5 rounded-full text-xs font-semibold border transition-all duration-150
                                               hover:scale-105 hover:shadow-sm cursor-default"
                                    style={{
                                        backgroundColor: i % 3 === 0 ? "#E8F5A8" : i % 3 === 1 ? "#F3F4F6" : "#F9FAFB",
                                        borderColor: i % 3 === 0 ? "#D4F291" : "#E5E7EB",
                                        color: i % 3 === 0 ? "#1A1A1A" : "#374151",
                                    }}
                                >
                                    {topic}
                                </span>
                            ))}
                        </div>
                    </div>
                </div>
            </div>
        </section>
    );
}
