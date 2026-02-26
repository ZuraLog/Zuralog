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

import { useRef, useEffect, useState, useCallback } from "react";
import { useGSAP } from "@gsap/react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/dist/ScrollTrigger";
import dynamic from "next/dynamic";
import {
    Zap,
    Sparkles,
    CheckCircle2,
    ChevronRight,
} from "lucide-react";
import { APPS } from "./hero/FloatingIcons";
import { FaStrava, FaApple, FaGooglePlay, FaAppStoreIos } from "react-icons/fa";
import { SiFitbit } from "react-icons/si";

// Card 4 — Unified Dashboard — opt out of SSR to prevent Math.random() hydration mismatches
const DashboardBento = dynamic(() => import("./DashboardBento"), { ssr: false });

// Register GSAP ScrollTrigger plugin on client side
if (typeof window !== "undefined") {
    gsap.registerPlugin(ScrollTrigger);
}


// ─────────────────────────────────────────────────────────────
// Card-level constants
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

/** Staggered animation delays (seconds) for pill pulse — spread 0–9s for organic feel */
const PILL_DELAYS = [
    0, 0.6, 1.3, 2.0, 2.7, 3.4, 4.1, 4.8, 5.6, 6.3,
    7.0, 7.8, 8.2, 0.3, 1.0, 1.8, 2.4, 3.1, 3.8, 4.5,
    5.2, 5.9, 6.7, 7.4, 8.0, 0.9, 1.6, 2.3, 3.0, 3.7,
    4.4, 5.1, 5.8, 6.5, 7.2, 7.9, 8.5, 0.4, 1.1, 1.9,
    2.6, 3.3, 4.0, 4.7, 5.4, 6.1, 6.8, 7.5, 8.3, 0.7,
    1.4, 2.1, 2.8, 3.5, 4.2, 4.9, 5.7, 6.4, 7.1, 7.9,
];

const CONNECT_STEPS = [
    { label: "Link your apps", done: true },
    { label: "ZuraLog reads your data", done: true },
    { label: "AI generates insights", done: false },
];

// ─────────────────────────────────────────────────────────────
// BentoSection — main export
// ─────────────────────────────────────────────────────────────

/**
 * BentoSection — "How ZuraLog Works"
 *
 * Dark background section with a 6-card bento grid layout.
 * Cards reveal with staggered GSAP scroll animations.
 */
/** Shape returned by /api/waitlist/leaderboard */
interface LeaderboardEntry {
    rank: number;
    display_name: string;
    referral_count: number;
    queue_position: number | null;
}

export function BentoSection() {
    const sectionRef = useRef<HTMLElement>(null);
    const listenersRef = useRef<Array<{ el: Element; event: string; fn: EventListener }>>([]);

    // ── Live waitlist data ──────────────────────────────────────────
    const [totalUsers, setTotalUsers] = useState<number>(0);
    const [leaderboard, setLeaderboard] = useState<LeaderboardEntry[]>([]);

    useEffect(() => {
        /** Fetch total signups from the stats API */
        async function fetchStats() {
            try {
                const res = await fetch('/api/waitlist/stats');
                if (!res.ok) return;
                const json = await res.json() as { totalSignups: number };
                setTotalUsers(json.totalSignups ?? 0);
            } catch {
                // Non-fatal — counter stays at 0
            }
        }

        /** Fetch top referrers for the leaderboard */
        async function fetchLeaderboard() {
            try {
                const res = await fetch('/api/waitlist/leaderboard');
                if (!res.ok) return;
                const json = await res.json() as { leaderboard: LeaderboardEntry[] };
                setLeaderboard(json.leaderboard ?? []);
            } catch {
                // Non-fatal — static entries remain
            }
        }

        void fetchStats();
        void fetchLeaderboard();
    }, []);

    const addTrackedListener = useCallback((el: Element, event: string, fn: EventListener) => {
        el.addEventListener(event, fn);
        listenersRef.current.push({ el, event, fn });
    }, []);

    useEffect(() => {
        return () => {
            listenersRef.current.forEach(({ el, event, fn }) => {
                el.removeEventListener(event, fn);
            });
            listenersRef.current = [];
        };
    }, []);

    // When totalUsers resolves after the GSAP entrance already ran, update the counter.
    // We always animate — if the card hasn't revealed yet the GSAP entrance onComplete
    // will pick up the correct data-target value. If it already revealed (e.g. the fetch
    // resolved late), this effect drives a smooth count-up to the real number.
    useEffect(() => {
        if (!sectionRef.current || totalUsers === 0) return;
        const counterEl = sectionRef.current.querySelector<HTMLElement>('.waitlist-counter-opt');
        if (!counterEl) return;
        gsap.to(counterEl, { innerText: totalUsers, duration: 1.5, ease: "power3.out", snap: { innerText: 1 } });
    }, [totalUsers]);

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
                addTrackedListener(card1, 'mouseenter', () => {
                    gsap.fromTo(sheen, { left: "-100%" }, { left: "200%", duration: 1.2, ease: "power2.inOut" });
                });

                let card1RafId = 0;
                const card1MouseMove = (e: Event) => {
                    if (card1RafId) return;
                    card1RafId = requestAnimationFrame(() => {
                        card1RafId = 0;
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
                };
                addTrackedListener(card1, 'mousemove', card1MouseMove);
                addTrackedListener(card1, 'mouseleave', () => {
                    if (card1RafId) { cancelAnimationFrame(card1RafId); card1RafId = 0; }
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
                                const target = Number(counterNum.getAttribute('data-target') ?? 0);
                                gsap.fromTo(counterNum,
                                    { innerText: 0 },
                                    { innerText: target, duration: 2, ease: "power3.out", snap: { innerText: 1 } }
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
                    addTrackedListener(card2, 'mouseenter', () => {
                        gsap.fromTo(expandMask, { opacity: 0 }, { opacity: 1, duration: 0.3 });
                        gsap.to(entries, { x: 5, duration: 0.3, stagger: 0.05, ease: "power1.out" });
                    });
                    addTrackedListener(card2, 'mouseleave', () => {
                        gsap.to(expandMask, { opacity: 0, duration: 0.3 });
                        gsap.to(entries, { x: 0, duration: 0.3, stagger: -0.05, ease: "power1.out" });
                    });
                }
            }

            // Note: Card 4 (DashboardBento) self-animates via its own useEffect
            // because it is loaded asynchronously via dynamic() and does not exist
            // in the DOM when this useGSAP callback runs.

            // ─────────────────────────────────────────────────────────────
            // Card 5: Get the App — scroll entrance + idle phone float
            // ─────────────────────────────────────────────────────────────
            const card5 = sectionRef.current.querySelector('[data-card="get-app"]');
            if (card5) {
                gsap.fromTo(
                    card5,
                    { opacity: 0, y: 50, scale: 0.93 },
                    {
                        opacity: 1, y: 0, scale: 1,
                        duration: 1.0,
                        ease: "power3.out",
                        scrollTrigger: {
                            trigger: card5,
                            start: "top 82%",
                            toggleActions: "play none none none",
                        },
                        onComplete: () => {
                            // Stagger-reveal the two store badges after card lands
                            const badges = card5.querySelectorAll('.store-badge');
                            gsap.fromTo(badges,
                                { x: -18, opacity: 0 },
                                { x: 0, opacity: 1, stagger: 0.12, duration: 0.5, ease: "back.out(2)" }
                            );
                        }
                    }
                );
            }

            // ─────────────────────────────────────────────────────────────
            // Magnetic 3D tilt — Cards 1, 2, 3, 5, 6
            // Same effect as DashboardBento: rotateX/Y on mousemove,
            // elastic spring-back on mouseleave.
            // ─────────────────────────────────────────────────────────────
            const MAX_TILT = 6;

            /** Attach the magnetic tilt effect to a single card element */
            const attachTilt = (card: Element) => {
                let rafId = 0;
                const onMove = (e: Event) => {
                    if (rafId) return;
                    rafId = requestAnimationFrame(() => {
                        rafId = 0;
                        const ev = e as MouseEvent;
                        const rect = card.getBoundingClientRect();
                        const cx = rect.left + rect.width / 2;
                        const cy = rect.top + rect.height / 2;
                        const dx = ev.clientX - cx;
                        const dy = ev.clientY - cy;
                        gsap.to(card, {
                            rotateX: (-dy / (rect.height / 2)) * MAX_TILT,
                            rotateY: (dx / (rect.width / 2)) * MAX_TILT,
                            transformPerspective: 900,
                            duration: 0.35,
                            ease: "power2.out",
                        });
                    });
                };

                const onLeave = () => {
                    if (rafId) { cancelAnimationFrame(rafId); rafId = 0; }
                    gsap.to(card, {
                        rotateX: 0,
                        rotateY: 0,
                        duration: 0.8,
                        ease: "elastic.out(1, 0.45)",
                    });
                };

                addTrackedListener(card, "mousemove", onMove);
                addTrackedListener(card, "mouseleave", onLeave);
            };

            const tiltSelectors = [
                '[data-card="connect"]',
                '[data-card="waitlist"]',
                '[data-card="integrations"]',   // outer wrapper — inner card untouched
                '[data-card="get-app"]',
                '[data-card="personalized"]',   // outer wrapper — inner card untouched
            ];

            if (window.innerWidth >= 768) {
                tiltSelectors.forEach(sel => {
                    const el = sectionRef.current!.querySelector(sel);
                    if (el) attachTilt(el);
                });
            }
        },
        { scope: sectionRef }
    );

    return (
        <section
            ref={sectionRef}
            id="bento-section"
            className="relative w-full py-16 md:py-28 lg:py-36 overflow-hidden"
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
                <div className="text-center mb-10 md:mb-16 lg:mb-20">
                    <p className="bento-subtitle text-sm font-semibold tracking-[0.25em] uppercase text-[#E8F5A8] mb-4 opacity-0">
                        How It Works
                    </p>
                    <h2 className="bento-title text-4xl sm:text-5xl lg:text-[56px] font-bold text-white leading-[1.1] tracking-tight opacity-0">
                        How ZuraLog Works
                    </h2>
                </div>

                {/* ── Bento Grid ── */}
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 lg:gap-5">
                    {/* ══ Card 1: CONNECT ══ */}
                    <div
                        data-card="connect"
                        className="bento-card group relative bg-white rounded-3xl p-7 lg:p-8 shadow-xl overflow-hidden
                                   hover:shadow-2xl transition-shadow duration-300 opacity-0"
                        style={{ transformStyle: "preserve-3d", willChange: "transform" }}
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
                        style={{ transformStyle: "preserve-3d", willChange: "transform" }}
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
                                <div
                                    className="text-2xl font-black text-gray-900 leading-none waitlist-counter-opt"
                                    data-target={totalUsers}
                                >
                                    0
                                </div>
                                <div className="text-[10px] uppercase font-bold text-gray-400 mt-1">Total Users</div>
                            </div>
                        </div>

                        <div className="flex flex-col gap-2 relative z-10 mb-5">
                            {[0, 1, 2].map((slot) => {
                                const entry = leaderboard[slot];
                                const slotRank = slot + 1;
                                const isFirst = slot === 0;

                                if (entry) {
                                    // Real leaderboard entry from DB
                                    const initials = entry.display_name
                                        .split(' ')
                                        .map((w) => w[0])
                                        .join('')
                                        .toUpperCase()
                                        .slice(0, 2);
                                    return (
                                        <div
                                            key={entry.rank}
                                            className={`leaderboard-entry opacity-0 flex items-center justify-between p-2.5 rounded-xl border ${
                                                isFirst
                                                    ? 'bg-gradient-to-r from-[#FFD700]/10 to-transparent border-[#FFD700]/20'
                                                    : 'bg-gray-50 border-gray-100'
                                            }`}
                                        >
                                            <div className="flex items-center gap-3">
                                                <div className={`w-6 font-bold text-sm text-center ${isFirst ? 'text-[#D4AF37]' : 'text-gray-400'}`}>
                                                    #{entry.rank}
                                                </div>
                                                <div className={`w-7 h-7 rounded-full flex items-center justify-center text-[10px] font-bold shadow-sm ${
                                                    isFirst ? 'bg-gray-900 text-white' : 'bg-[#E8F5A8] text-gray-900'
                                                }`}>
                                                    {initials}
                                                </div>
                                                <span className={`text-sm font-semibold ${isFirst ? 'text-gray-900' : 'text-gray-700'}`}>
                                                    {entry.display_name}
                                                </span>
                                            </div>
                                        </div>
                                    );
                                }

                                // Empty slot — CTA row (always #1 gold style if db returned nothing at all)
                                return (
                                    <div
                                        key={`slot-${slotRank}`}
                                        className={`leaderboard-entry opacity-0 flex items-center justify-between p-2.5 rounded-xl border ${
                                            isFirst && leaderboard.length === 0
                                                ? 'bg-gradient-to-r from-[#FFD700]/10 to-transparent border-[#FFD700]/20'
                                                : 'bg-gray-50 border-gray-100'
                                        }`}
                                    >
                                        <div className="flex items-center gap-3">
                                            <div className={`w-6 font-bold text-sm text-center ${isFirst && leaderboard.length === 0 ? 'text-[#D4AF37]' : 'text-gray-400'}`}>
                                                #{slotRank}
                                            </div>
                                            <div className="w-7 h-7 rounded-full border border-gray-200 border-dashed flex items-center justify-center text-gray-400 text-[10px] font-bold">+</div>
                                            <span className="text-sm font-medium text-gray-400 italic">This could be you</span>
                                        </div>
                                    </div>
                                );
                            })}
                        </div>

                        <p className="text-[10px] text-gray-400 leading-relaxed font-medium relative z-10 text-center">
                            * Top 30 receive 3 months of ZuraLog Pro.
                            <br />First 30 receive 1 month. Refer friends to climb.
                        </p>
                    </div>

                    {/* ══ Card 3: INTEGRATIONS (tall, spans rows 1-2) ══ */}
                    {/* Outer tilt wrapper — GSAP targets this for rotateX/Y so the card's
                        own transform is never touched, keeping child CSS animations fast. */}
                    <div
                        data-card="integrations"
                        className="sm:row-span-2 lg:col-start-3 lg:row-start-1"
                        style={{ willChange: "transform", transformStyle: "preserve-3d" }}
                    >
                    <div
                        className="bento-card group relative bg-white rounded-3xl shadow-xl overflow-hidden opacity-0
                                   hover:shadow-2xl transition-shadow duration-300 h-full min-h-[300px] sm:min-h-0"
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
                                {[0, 1, 2, 3, 4, 5, 6, 7, 8].map(colIndex => {
                                    const speedClass = colIndex % 3 === 0 ? 'animate-drift-slow' : colIndex % 3 === 1 ? 'animate-drift-mid' : 'animate-drift-fast';
                                    return (
                                        <div
                                            key={colIndex}
                                            className={`integrations-column flex flex-col gap-4 w-max h-max ${speedClass}`}
                                            style={{ marginTop: colIndex % 2 !== 0 ? '40px' : '0px' }}
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
                    </div>{/* end integrations tilt wrapper */}

                    {/* ══ Card 4: UNIFIED DASHBOARD ══ */}
                    <DashboardBento />

                    {/* ══ Card 5: GET THE APP (coming soon) ══ */}
                    <div
                        data-card="get-app"
                        className="bento-card group relative rounded-3xl overflow-hidden shadow-xl opacity-0"
                        style={{
                            background: "linear-gradient(160deg, #141414 0%, #1E1E1E 60%, #0f1f0f 100%)",
                            transformStyle: "preserve-3d",
                            willChange: "transform",
                        }}
                    >
                        {/* Lime corner glow */}
                        <div
                            className="absolute -top-12 -right-12 w-44 h-44 rounded-full pointer-events-none"
                            style={{ background: "radial-gradient(circle, rgba(232,245,168,0.10) 0%, transparent 70%)" }}
                        />

                        {/* Compact phone — top-right corner with mini chat analytics */}
                        <div className="absolute top-3 right-3 phone-float" aria-hidden="true">
                            <div
                                className="relative w-[68px] h-[128px] rounded-[16px] border-[1.5px] border-white/15 overflow-hidden"
                                style={{
                                    background: "linear-gradient(170deg, #333 0%, #1a1a1a 100%)",
                                    boxShadow: "0 8px 32px rgba(0,0,0,0.5), 0 0 16px rgba(232,245,168,0.06)",
                                }}
                            >
                                {/* Dynamic Island */}
                                <div className="absolute top-[4px] left-1/2 -translate-x-1/2 w-[18px] h-[4px] rounded-full bg-black z-10" />
                                {/* Screen */}
                                <div className="absolute inset-[2px] top-[3px] rounded-[13px] overflow-hidden" style={{ background: "#FAFAF5" }}>
                                    {/* Mini header */}
                                    <div className="flex items-center gap-[3px] px-1.5 pt-[9px] pb-[3px]">
                                        <div className="w-[7px] h-[7px] rounded-[2px] bg-[#CFE1B9]" />
                                        <div className="text-[4px] font-bold text-black/60 leading-none">ZuraLog</div>
                                    </div>
                                    {/* Mini bar chart */}
                                    <div className="mx-1.5 rounded-[4px] bg-white p-[3px]" style={{ boxShadow: "0 0.5px 2px rgba(0,0,0,0.04)" }}>
                                        <div className="flex items-end gap-[1.5px] h-[16px]">
                                            <div className="flex-1 rounded-t-[1px] bg-[#CFE1B9]/50" style={{ height: "8px" }} />
                                            <div className="flex-1 rounded-t-[1px] bg-[#CFE1B9]/70" style={{ height: "11px" }} />
                                            <div className="flex-1 rounded-t-[1px] bg-[#CFE1B9]/45" style={{ height: "6px" }} />
                                            <div className="flex-1 rounded-t-[1px] bg-[#E8F5A8]" style={{ height: "15px" }} />
                                            <div className="flex-1 rounded-t-[1px] bg-[#CFE1B9]/65" style={{ height: "10px" }} />
                                            <div className="flex-1 rounded-t-[1px] bg-[#CFE1B9]/40" style={{ height: "7px" }} />
                                            <div className="flex-1 rounded-t-[1px] bg-[#CFE1B9]/55" style={{ height: "12px" }} />
                                        </div>
                                    </div>
                                    {/* Mini stats */}
                                    <div className="flex gap-[2px] px-1.5 mt-[3px]">
                                        <div className="flex-1 rounded-[3px] bg-white py-[2px] text-center" style={{ boxShadow: "0 0.5px 2px rgba(0,0,0,0.04)" }}>
                                            <div className="text-[4.5px] font-bold text-black/65 leading-none">8.4k</div>
                                            <div className="text-[3px] text-black/25">Steps</div>
                                        </div>
                                        <div className="flex-1 rounded-[3px] bg-white py-[2px] text-center" style={{ boxShadow: "0 0.5px 2px rgba(0,0,0,0.04)" }}>
                                            <div className="text-[4.5px] font-bold text-[#4A7C3F] leading-none">82</div>
                                            <div className="text-[3px] text-black/25">Score</div>
                                        </div>
                                    </div>
                                    {/* Mini chat */}
                                    <div className="flex flex-col gap-[2px] px-1.5 mt-[3px]">
                                        <div className="rounded-[3px] bg-black/[0.04] px-[3px] py-[2px] w-[82%]">
                                            <div className="h-[2px] rounded-full bg-black/12 w-[90%]" />
                                            <div className="h-[2px] rounded-full bg-black/8 w-[55%] mt-[1.5px]" />
                                        </div>
                                        <div className="rounded-[3px] bg-[#E8F5A8]/40 px-[3px] py-[2px] w-[50%] ml-auto">
                                            <div className="h-[2px] rounded-full bg-black/12 w-[75%]" />
                                        </div>
                                        <div className="rounded-[3px] bg-black/[0.04] px-[3px] py-[2px] w-[65%]">
                                            <div className="h-[2px] rounded-full bg-black/12 w-[80%]" />
                                        </div>
                                    </div>
                                </div>
                                {/* Home indicator */}
                                <div className="absolute bottom-[3px] left-1/2 -translate-x-1/2 w-6 h-[1.5px] rounded-full bg-white/20" />
                            </div>
                        </div>

                        {/* Content */}
                        <div className="relative z-10 flex flex-col h-full p-6">
                            {/* Coming soon pill */}
                            <div className="inline-flex items-center gap-1.5 bg-white/5 border border-white/10 text-white/50 rounded-full px-2.5 py-1 mb-4 w-fit">
                                <div className="w-1.5 h-1.5 rounded-full bg-[#E8F5A8]/60 animate-pulse" />
                                <span className="text-[9px] font-bold uppercase tracking-widest">Coming Soon</span>
                            </div>

                            {/* Headline */}
                            <h3 className="text-lg font-bold text-white leading-tight mb-1">
                                Get the App
                            </h3>
                            <p className="text-[11px] text-white/40 leading-relaxed mb-5">
                                iOS &amp; Android — dropping soon.
                            </p>

                            {/* Locked store badges */}
                            <div className="flex flex-col gap-2 mb-5">
                                {/* App Store — locked */}
                                <div
                                    className="store-badge flex items-center gap-2.5 rounded-xl px-3 py-2.5 opacity-40 cursor-not-allowed select-none"
                                    style={{ background: "#1c1c1e" }}
                                    aria-label="App Store — coming soon"
                                >
                                    <FaAppStoreIos size={18} className="text-white/70 flex-shrink-0" />
                                    <div className="leading-none">
                                        <div className="text-[8px] text-white/50 uppercase tracking-widest mb-0.5">Download on the</div>
                                        <div className="text-[13px] font-semibold text-white/70">App Store</div>
                                    </div>
                                    <div className="ml-auto text-white/30 text-base">🔒</div>
                                </div>

                                {/* Google Play — locked */}
                                <div
                                    className="store-badge flex items-center gap-2.5 rounded-xl px-3 py-2.5 opacity-40 cursor-not-allowed select-none"
                                    style={{ background: "#1c1c1e" }}
                                    aria-label="Google Play — coming soon"
                                >
                                    <FaGooglePlay size={16} className="text-white/70 flex-shrink-0" />
                                    <div className="leading-none">
                                        <div className="text-[8px] text-white/50 uppercase tracking-widest mb-0.5">Get it on</div>
                                        <div className="text-[13px] font-semibold text-white/70">Google Play</div>
                                    </div>
                                    <div className="ml-auto text-white/30 text-base">🔒</div>
                                </div>
                            </div>

                            {/* Waitlist CTA */}
                            <button
                                className="mt-auto w-full bg-[#E8F5A8] text-gray-900 text-xs font-bold py-2.5 rounded-xl hover:bg-[#d4f291] active:scale-95 transition-all duration-150 shadow-md shadow-black/30"
                                onClick={() => document.getElementById("waitlist")?.scrollIntoView({ behavior: "smooth" })}
                            >
                                Join the Waitlist →
                            </button>
                        </div>
                    </div>

                    {/* ══ Card 6: PERSONALIZED FOR YOU (wide, spans cols 2-3) ══ */}
                    {/* Outer tilt wrapper — same isolation pattern as Card 3 */}
                    <div
                        data-card="personalized"
                        className="sm:col-span-2 lg:col-span-2 lg:col-start-2 lg:row-start-3"
                        style={{ willChange: "transform", transformStyle: "preserve-3d" }}
                    >
                    <div
                        className="bento-card personalized-card group relative bg-white rounded-3xl shadow-xl overflow-hidden
                                   hover:shadow-2xl transition-shadow duration-200 opacity-0 h-full"
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
                    </div>{/* end personalized tilt wrapper */}
                </div>
            </div>
        </section>
    );
}
