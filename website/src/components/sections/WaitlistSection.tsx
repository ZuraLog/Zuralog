"use client";

/**
 * WaitlistSection.tsx
 *
 * Section 4 — "Secure Your Spot" waitlist conversion layer.
 *
 * Layout:
 *   Stats bar (3 animated counters) → full-width at top
 *   Two-panel split:
 *     LEFT  → Sign-up form (name + email + CTA)
 *     RIGHT → Live leaderboard with ranked entries
 *
 * Color palette: soft pastel lavender (#F0EEFF background) — deliberately
 * distinct from the lime/charcoal language of the bento section.
 *
 * Animations:
 *   - GSAP ScrollTrigger entrances for header, stats, both panels
 *   - GSAP counter tween (0 → target) for stat numbers
 *   - Leaderboard rows stagger-slide from left after panel enters
 *   - Gold #1 row: continuous pulsing glow
 *   - Magnetic 3D tilt on each panel (mousemove)
 *   - Form submit: success state reveal with checkmark
 */

import { useRef, useState } from "react";
import { useGSAP } from "@gsap/react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/dist/ScrollTrigger";
import {
    Trophy,
    CheckCircle2,
    Sparkles,
    ArrowRight,
    Lock,
    Users,
    Medal,
    Star,
} from "lucide-react";

if (typeof window !== "undefined") {
    gsap.registerPlugin(ScrollTrigger);
}

// ─────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────

/** Top-line stats displayed in the bar above the panels */
const STATS = [
    { value: 2847, label: "People Joined", suffix: "" },
    { value: 30, label: "Spots earn 3 months Pro free", suffix: "Top" },
    { value: 100, label: "Referrals unlock VIP tier", suffix: "" },
];

/** Leaderboard entries — #5 is the ghost "your spot" row */
const LEADERBOARD = [
    { rank: 1, initials: "HY", name: "Hyowon B.", badge: "Early Access VIP", isGold: true },
    { rank: 2, initials: "AL", name: "Alice L.", badge: "Pro Tier", isGold: false },
    { rank: 3, initials: "MK", name: "Marcus K.", badge: "Pro Tier", isGold: false },
    { rank: 4, initials: "SR", name: "Sofia R.", badge: "Early Bird", isGold: false },
    { rank: 5, initials: "?", name: "This could be you", badge: "", isGold: false, isGhost: true },
] as const;

/** Perks shown beneath the form inputs */
const PERKS = [
    "Early access before public launch",
    "Top 30 members get 3 months Pro free",
    "Refer friends to climb the ranks",
];

// ─────────────────────────────────────────────────────────────
// WaitlistSection
// ─────────────────────────────────────────────────────────────

/**
 * WaitlistSection — "Secure Your Spot"
 *
 * Full-width lavender-themed section with a sign-up form on the left
 * and an animated leaderboard on the right.
 */
export function WaitlistSection() {
    const sectionRef = useRef<HTMLElement>(null);
    const [submitted, setSubmitted] = useState(false);
    const [name, setName] = useState("");
    const [email, setEmail] = useState("");

    // ── Animations ──────────────────────────────────────────
    useGSAP(
        () => {
            if (!sectionRef.current) return;

            const header = sectionRef.current.querySelector(".wl-header");
            const statsItems = sectionRef.current.querySelectorAll<HTMLElement>(".wl-stat");
            const leftPanel = sectionRef.current.querySelector(".wl-left");
            const rightPanel = sectionRef.current.querySelector(".wl-right");
            const rows = sectionRef.current.querySelectorAll<HTMLElement>(".lb-row");

            // Header fade-up
            if (header) {
                gsap.fromTo(
                    header,
                    { opacity: 0, y: 50 },
                    {
                        opacity: 1,
                        y: 0,
                        duration: 0.9,
                        ease: "power3.out",
                        scrollTrigger: {
                            trigger: header,
                            start: "top 85%",
                            toggleActions: "play none none none",
                        },
                    }
                );
            }

            // Stats counters — animate numbers on scroll
            statsItems.forEach((stat) => {
                const numEl = stat.querySelector<HTMLElement>(".wl-stat-num");
                const targetStr = numEl?.dataset.target ?? "0";
                const target = parseInt(targetStr, 10);

                gsap.fromTo(
                    stat,
                    { opacity: 0, y: 30, scale: 0.92 },
                    {
                        opacity: 1,
                        y: 0,
                        scale: 1,
                        duration: 0.7,
                        ease: "power3.out",
                        scrollTrigger: {
                            trigger: stat,
                            start: "top 88%",
                            toggleActions: "play none none none",
                        },
                        onComplete: () => {
                            if (numEl) {
                                gsap.fromTo(
                                    numEl,
                                    { innerText: 0 },
                                    {
                                        innerText: target,
                                        duration: 1.8,
                                        ease: "power3.out",
                                        snap: { innerText: 1 },
                                    }
                                );
                            }
                        },
                    }
                );
            });

            // Left panel — slide in from left
            if (leftPanel) {
                gsap.fromTo(
                    leftPanel,
                    { opacity: 0, x: -60 },
                    {
                        opacity: 1,
                        x: 0,
                        duration: 0.9,
                        ease: "cubic-bezier(0.16, 1, 0.3, 1)",
                        scrollTrigger: {
                            trigger: leftPanel,
                            start: "top 80%",
                            toggleActions: "play none none none",
                        },
                    }
                );
            }

            // Right panel — slide in from right
            if (rightPanel) {
                gsap.fromTo(
                    rightPanel,
                    { opacity: 0, x: 60 },
                    {
                        opacity: 1,
                        x: 0,
                        duration: 0.9,
                        ease: "cubic-bezier(0.16, 1, 0.3, 1)",
                        delay: 0.15,
                        scrollTrigger: {
                            trigger: rightPanel,
                            start: "top 80%",
                            toggleActions: "play none none none",
                            onEnter: () => {
                                // Stagger leaderboard rows after panel lands
                                gsap.fromTo(
                                    rows,
                                    { x: -20, opacity: 0 },
                                    {
                                        x: 0,
                                        opacity: 1,
                                        stagger: 0.12,
                                        duration: 0.55,
                                        ease: "power2.out",
                                        delay: 0.35,
                                    }
                                );

                                // Gold #1 badge glow pulse
                                const goldBadge = rightPanel.querySelector<HTMLElement>(".lb-gold-badge");
                                if (goldBadge) {
                                    gsap.to(goldBadge, {
                                        boxShadow: "0 0 18px rgba(217,119,6,0.5)",
                                        scale: 1.06,
                                        duration: 1.4,
                                        yoyo: true,
                                        repeat: -1,
                                        ease: "sine.inOut",
                                    });
                                }
                            },
                        },
                    }
                );

                // Idle float on leaderboard rows
                rows.forEach((row, i) => {
                    gsap.to(row, {
                        y: -3,
                        rotation: i % 2 === 0 ? 0.3 : -0.3,
                        duration: 3.2,
                        yoyo: true,
                        repeat: -1,
                        ease: "sine.inOut",
                        delay: i * 0.25,
                    });
                });
            }

            // ── Magnetic 3D tilt ──────────────────────────────
            const MAX_TILT = 5;
            const panels = [leftPanel, rightPanel].filter(Boolean) as Element[];

            panels.forEach((panel) => {
                const onMove = (e: Event) => {
                    const ev = e as MouseEvent;
                    const rect = panel.getBoundingClientRect();
                    const cx = rect.left + rect.width / 2;
                    const cy = rect.top + rect.height / 2;
                    gsap.to(panel, {
                        rotateX: (-(ev.clientY - cy) / (rect.height / 2)) * MAX_TILT,
                        rotateY: ((ev.clientX - cx) / (rect.width / 2)) * MAX_TILT,
                        transformPerspective: 900,
                        duration: 0.35,
                        ease: "power2.out",
                    });
                };
                const onLeave = () => {
                    gsap.to(panel, {
                        rotateX: 0,
                        rotateY: 0,
                        duration: 0.8,
                        ease: "elastic.out(1, 0.45)",
                    });
                };
                panel.addEventListener("mousemove", onMove);
                panel.addEventListener("mouseleave", onLeave);
            });
        },
        { scope: sectionRef }
    );

    // ── Form submit handler (simulated) ─────────────────────
    const handleSubmit = (e: React.FormEvent) => {
        e.preventDefault();
        if (!email) return;
        setSubmitted(true);
    };

    // ── Render ───────────────────────────────────────────────
    return (
        <section
            ref={sectionRef}
            id="waitlist-section"
            className="relative w-full overflow-hidden"
            style={{ backgroundColor: "#F0EEFF" }}
        >
            {/* ── Transition gradient from dark bento ── */}
            <div
                className="absolute top-0 left-0 w-full h-24 pointer-events-none z-10"
                style={{
                    background: "linear-gradient(to bottom, #2D2D2D 0%, #F0EEFF 100%)",
                }}
            />

            {/* ── Soft radial glow blobs in background ── */}
            <div
                className="absolute top-32 left-1/4 w-[600px] h-[600px] rounded-full pointer-events-none opacity-40"
                style={{
                    background:
                        "radial-gradient(circle, rgba(196,181,253,0.35) 0%, transparent 70%)",
                    filter: "blur(80px)",
                }}
            />
            <div
                className="absolute bottom-20 right-1/4 w-[400px] h-[400px] rounded-full pointer-events-none opacity-30"
                style={{
                    background:
                        "radial-gradient(circle, rgba(167,139,250,0.3) 0%, transparent 70%)",
                    filter: "blur(60px)",
                }}
            />

            <div className="relative z-20 max-w-[1280px] mx-auto px-6 lg:px-12 pt-36 pb-28 lg:pb-36">

                {/* ── Section Header ── */}
                <div className="wl-header text-center mb-14 opacity-0">
                    {/* Founding Members chip */}
                    <div className="inline-flex items-center gap-2 rounded-full px-4 py-1.5 mb-5 border"
                        style={{
                            backgroundColor: "#EDE9FE",
                            borderColor: "#C4B5FD",
                        }}
                    >
                        <Sparkles size={12} style={{ color: "#7C3AED" }} />
                        <span className="text-[11px] font-bold uppercase tracking-widest"
                            style={{ color: "#7C3AED" }}>
                            Founding Members
                        </span>
                    </div>

                    <h2
                        className="text-4xl sm:text-5xl lg:text-[56px] font-bold leading-[1.1] tracking-tight mb-4"
                        style={{ color: "#1E1B4B" }}
                    >
                        Secure Your Spot.
                    </h2>
                    <p className="text-base sm:text-lg font-medium max-w-xl mx-auto"
                        style={{ color: "#6B7280" }}>
                        Launch is closer than you think. Join the waitlist today and shape
                        ZuraLog&apos;s future.
                    </p>
                </div>

                {/* ── Stats Bar ── */}
                <div className="flex flex-col sm:flex-row items-center justify-center gap-6 sm:gap-12 mb-14">
                    {STATS.map((stat, i) => (
                        <div
                            key={i}
                            className="wl-stat flex flex-col items-center opacity-0"
                        >
                            {/* Glow pill behind number */}
                            <div className="relative flex items-baseline gap-1.5 mb-1">
                                {stat.suffix && (
                                    <span
                                        className="text-sm font-bold uppercase tracking-wide"
                                        style={{ color: "#7C3AED" }}
                                    >
                                        {stat.suffix}
                                    </span>
                                )}
                                <span
                                    className="wl-stat-num text-4xl sm:text-5xl font-black tabular-nums"
                                    data-target={stat.value}
                                    style={{ color: "#1E1B4B" }}
                                >
                                    0
                                </span>
                                {/* Decorative glow blob behind the number */}
                                <div
                                    className="absolute inset-0 -z-10 rounded-full"
                                    style={{
                                        background:
                                            "radial-gradient(circle, rgba(196,181,253,0.4) 0%, transparent 70%)",
                                        filter: "blur(20px)",
                                        transform: "scale(1.8)",
                                    }}
                                />
                            </div>
                            <span className="text-xs font-semibold uppercase tracking-widest"
                                style={{ color: "#9CA3AF" }}>
                                {stat.label}
                            </span>
                        </div>
                    ))}
                </div>

                {/* ── Divider ── */}
                <div
                    className="w-full h-px mb-14 opacity-40"
                    style={{ background: "linear-gradient(to right, transparent, #C4B5FD, transparent)" }}
                />

                {/* ── Two-panel layout ── */}
                <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 lg:gap-8 items-start">

                    {/* ════ LEFT PANEL — Sign-up Form ════ */}
                    <div
                        className="wl-left relative bg-white rounded-3xl p-8 lg:p-10 shadow-xl opacity-0"
                        style={{
                            transformStyle: "preserve-3d",
                            willChange: "transform",
                            boxShadow: "0 20px 60px rgba(124,58,237,0.08), 0 4px 20px rgba(0,0,0,0.04)",
                        }}
                    >
                        {/* Lavender corner accent */}
                        <div
                            className="absolute top-0 right-0 w-48 h-48 rounded-3xl pointer-events-none opacity-60"
                            style={{
                                background:
                                    "radial-gradient(circle at top right, rgba(196,181,253,0.25) 0%, transparent 65%)",
                            }}
                        />

                        {/* ── Form Header ── */}
                        <div className="mb-8 relative z-10">
                            <div
                                className="inline-flex items-center gap-2 rounded-full px-3 py-1 mb-4"
                                style={{ backgroundColor: "#EDE9FE" }}
                            >
                                <div
                                    className="w-1.5 h-1.5 rounded-full animate-pulse"
                                    style={{ backgroundColor: "#7C3AED" }}
                                />
                                <span
                                    className="text-[10px] font-bold uppercase tracking-wider"
                                    style={{ color: "#7C3AED" }}
                                >
                                    Early Access
                                </span>
                            </div>
                            <h3
                                className="text-2xl lg:text-3xl font-bold mb-2"
                                style={{ color: "#1E1B4B" }}
                            >
                                Join the Waitlist
                            </h3>
                            <p className="text-sm leading-relaxed" style={{ color: "#6B7280" }}>
                                Be among the first to experience ZuraLog. Top waitlisters earn
                                Pro access — completely free.
                            </p>
                        </div>

                        {/* ── Form / Success state ── */}
                        {!submitted ? (
                            <form onSubmit={handleSubmit} className="relative z-10">
                                {/* Name input */}
                                <div className="mb-4">
                                    <label
                                        htmlFor="wl-name"
                                        className="block text-xs font-semibold mb-1.5 uppercase tracking-wide"
                                        style={{ color: "#6B7280" }}
                                    >
                                        First Name
                                    </label>
                                    <input
                                        id="wl-name"
                                        type="text"
                                        value={name}
                                        onChange={(e) => setName(e.target.value)}
                                        placeholder="Your first name"
                                        className="wl-input w-full rounded-xl px-4 py-3 text-sm font-medium outline-none transition-all duration-200"
                                        style={{
                                            border: "1.5px solid #E5E7EB",
                                            color: "#1E1B4B",
                                            backgroundColor: "#FAFAFA",
                                        }}
                                    />
                                </div>

                                {/* Email input */}
                                <div className="mb-6">
                                    <label
                                        htmlFor="wl-email"
                                        className="block text-xs font-semibold mb-1.5 uppercase tracking-wide"
                                        style={{ color: "#6B7280" }}
                                    >
                                        Email Address
                                    </label>
                                    <input
                                        id="wl-email"
                                        type="email"
                                        value={email}
                                        onChange={(e) => setEmail(e.target.value)}
                                        placeholder="you@example.com"
                                        required
                                        className="wl-input w-full rounded-xl px-4 py-3 text-sm font-medium outline-none transition-all duration-200"
                                        style={{
                                            border: "1.5px solid #E5E7EB",
                                            color: "#1E1B4B",
                                            backgroundColor: "#FAFAFA",
                                        }}
                                    />
                                </div>

                                {/* CTA button */}
                                <button
                                    type="submit"
                                    className="wl-cta w-full flex items-center justify-center gap-2 rounded-2xl py-3.5 text-sm font-bold text-white transition-all duration-200 active:scale-[0.98] shadow-lg"
                                    style={{
                                        backgroundColor: "#7C3AED",
                                        boxShadow: "0 8px 24px rgba(124,58,237,0.35)",
                                    }}
                                    onMouseEnter={(e) => {
                                        (e.currentTarget as HTMLElement).style.backgroundColor = "#6D28D9";
                                        (e.currentTarget as HTMLElement).style.transform = "scale(1.02)";
                                    }}
                                    onMouseLeave={(e) => {
                                        (e.currentTarget as HTMLElement).style.backgroundColor = "#7C3AED";
                                        (e.currentTarget as HTMLElement).style.transform = "scale(1)";
                                    }}
                                >
                                    Join Waitlist
                                    <ArrowRight size={15} />
                                </button>

                                {/* Trust line */}
                                <p
                                    className="flex items-center justify-center gap-1.5 text-[11px] font-medium mt-4"
                                    style={{ color: "#9CA3AF" }}
                                >
                                    <Lock size={10} />
                                    No spam. Unsubscribe anytime. Join 2,847 others.
                                </p>
                            </form>
                        ) : (
                            /* Success state */
                            <div className="relative z-10 flex flex-col items-center justify-center py-8 text-center">
                                <div
                                    className="w-16 h-16 rounded-full flex items-center justify-center mb-5 shadow-lg"
                                    style={{
                                        backgroundColor: "#EDE9FE",
                                        boxShadow: "0 0 30px rgba(124,58,237,0.25)",
                                    }}
                                >
                                    <CheckCircle2 size={32} style={{ color: "#7C3AED" }} />
                                </div>
                                <h4
                                    className="text-xl font-bold mb-2"
                                    style={{ color: "#1E1B4B" }}
                                >
                                    You&apos;re on the list!
                                </h4>
                                <p
                                    className="text-sm leading-relaxed max-w-xs"
                                    style={{ color: "#6B7280" }}
                                >
                                    Welcome to ZuraLog&apos;s founding community. Refer friends to
                                    climb the leaderboard and unlock Pro early.
                                </p>
                            </div>
                        )}

                        {/* ── Perks list ── */}
                        <div
                            className="mt-7 pt-7 relative z-10"
                            style={{ borderTop: "1px solid #F3F4F6" }}
                        >
                            <div className="flex flex-col gap-3">
                                {PERKS.map((perk, i) => (
                                    <div key={i} className="flex items-start gap-3">
                                        <div
                                            className="mt-0.5 w-5 h-5 rounded-full flex items-center justify-center flex-shrink-0"
                                            style={{ backgroundColor: "#EDE9FE" }}
                                        >
                                            <CheckCircle2 size={12} style={{ color: "#7C3AED" }} />
                                        </div>
                                        <span
                                            className="text-sm font-medium leading-relaxed"
                                            style={{ color: "#4B5563" }}
                                        >
                                            {perk}
                                        </span>
                                    </div>
                                ))}
                            </div>
                        </div>
                    </div>

                    {/* ════ RIGHT PANEL — Leaderboard ════ */}
                    <div
                        className="wl-right relative bg-white rounded-3xl p-8 lg:p-10 shadow-xl opacity-0"
                        style={{
                            transformStyle: "preserve-3d",
                            willChange: "transform",
                            boxShadow: "0 20px 60px rgba(124,58,237,0.08), 0 4px 20px rgba(0,0,0,0.04)",
                        }}
                    >
                        {/* Lavender corner accent */}
                        <div
                            className="absolute bottom-0 left-0 w-64 h-64 rounded-3xl pointer-events-none opacity-60"
                            style={{
                                background:
                                    "radial-gradient(circle at bottom left, rgba(196,181,253,0.2) 0%, transparent 65%)",
                            }}
                        />

                        {/* ── Panel Header ── */}
                        <div className="flex items-center justify-between mb-7 relative z-10">
                            <div>
                                <div className="flex items-center gap-2 mb-2">
                                    <div
                                        className="w-2 h-2 rounded-full animate-pulse"
                                        style={{ backgroundColor: "#7C3AED" }}
                                    />
                                    <span
                                        className="text-[10px] font-bold uppercase tracking-widest"
                                        style={{ color: "#7C3AED" }}
                                    >
                                        Live Rankings
                                    </span>
                                </div>
                                <h3
                                    className="text-2xl lg:text-3xl font-bold"
                                    style={{ color: "#1E1B4B" }}
                                >
                                    Current Rankings
                                </h3>
                            </div>
                            <div
                                className="flex items-center gap-1.5 rounded-full px-3 py-1.5"
                                style={{ backgroundColor: "#EDE9FE" }}
                            >
                                <Users size={13} style={{ color: "#7C3AED" }} />
                                <span
                                    className="text-xs font-bold"
                                    style={{ color: "#7C3AED" }}
                                >
                                    2,847
                                </span>
                            </div>
                        </div>

                        {/* ── Leaderboard rows ── */}
                        <div className="flex flex-col gap-3 relative z-10">
                            {LEADERBOARD.map((entry) => {
                                if ((entry as typeof entry & { isGhost?: boolean }).isGhost) {
                                    // Ghost row — "Your spot awaits"
                                    return (
                                        <div
                                            key={entry.rank}
                                            className="lb-row opacity-0 flex items-center gap-4 p-4 rounded-2xl border border-dashed"
                                            style={{
                                                borderColor: "#C4B5FD",
                                                backgroundColor: "#F5F3FF",
                                            }}
                                        >
                                            <div
                                                className="text-sm font-black w-6 text-center"
                                                style={{ color: "#C4B5FD" }}
                                            >
                                                #{entry.rank}
                                            </div>
                                            <div
                                                className="w-9 h-9 rounded-full border-2 border-dashed flex items-center justify-center flex-shrink-0"
                                                style={{ borderColor: "#C4B5FD" }}
                                            >
                                                <span style={{ color: "#C4B5FD" }} className="text-sm font-bold">+</span>
                                            </div>
                                            <span
                                                className="text-sm font-medium italic"
                                                style={{ color: "#C4B5FD" }}
                                            >
                                                Your spot awaits
                                            </span>
                                            <div className="ml-auto">
                                                <ArrowRight size={14} style={{ color: "#C4B5FD" }} />
                                            </div>
                                        </div>
                                    );
                                }

                                if (entry.isGold) {
                                    // Gold #1 row
                                    return (
                                        <div
                                            key={entry.rank}
                                            className="lb-row opacity-0 flex items-center gap-4 p-4 rounded-2xl"
                                            style={{
                                                background:
                                                    "linear-gradient(135deg, #FEF3C7 0%, #FDE68A 100%)",
                                                border: "1px solid #FCD34D",
                                            }}
                                        >
                                            {/* Rank */}
                                            <div className="w-6 text-center">
                                                <Trophy size={16} style={{ color: "#D97706" }} />
                                            </div>
                                            {/* Avatar */}
                                            <div
                                                className="w-9 h-9 rounded-full flex items-center justify-center text-xs font-black flex-shrink-0 shadow-sm"
                                                style={{
                                                    backgroundColor: "#1E1B4B",
                                                    color: "#FDE68A",
                                                }}
                                            >
                                                {entry.initials}
                                            </div>
                                            {/* Name + badge */}
                                            <div className="flex-1 min-w-0">
                                                <div
                                                    className="text-sm font-bold leading-none mb-1"
                                                    style={{ color: "#92400E" }}
                                                >
                                                    {entry.name}
                                                </div>
                                                <div
                                                    className="lb-gold-badge inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[9px] font-black uppercase tracking-wider"
                                                    style={{
                                                        backgroundColor: "#D97706",
                                                        color: "#FEF3C7",
                                                    }}
                                                >
                                                    <Star size={8} />
                                                    {entry.badge}
                                                </div>
                                            </div>
                                            {/* Medal */}
                                            <Medal size={18} style={{ color: "#D97706" }} className="flex-shrink-0" />
                                        </div>
                                    );
                                }

                                // Standard rows #2–#4
                                const avatarColors = [
                                    { bg: "#EDE9FE", text: "#7C3AED" },
                                    { bg: "#F3F4F6", text: "#4B5563" },
                                    { bg: "#F3F4F6", text: "#4B5563" },
                                ];
                                const colorIdx = entry.rank - 2;
                                const avatarColor = avatarColors[colorIdx] ?? avatarColors[2];

                                return (
                                    <div
                                        key={entry.rank}
                                        className="lb-row opacity-0 flex items-center gap-4 p-4 rounded-2xl border"
                                        style={{
                                            borderColor: "#F3F4F6",
                                            backgroundColor: "#FAFAFA",
                                        }}
                                    >
                                        {/* Rank */}
                                        <div
                                            className="text-sm font-black w-6 text-center"
                                            style={{ color: "#9CA3AF" }}
                                        >
                                            #{entry.rank}
                                        </div>
                                        {/* Avatar */}
                                        <div
                                            className="w-9 h-9 rounded-full flex items-center justify-center text-xs font-black flex-shrink-0 shadow-sm"
                                            style={{
                                                backgroundColor: avatarColor.bg,
                                                color: avatarColor.text,
                                            }}
                                        >
                                            {entry.initials}
                                        </div>
                                        {/* Name + badge */}
                                        <div className="flex-1 min-w-0">
                                            <div
                                                className="text-sm font-semibold leading-none mb-1"
                                                style={{ color: "#1E1B4B" }}
                                            >
                                                {entry.name}
                                            </div>
                                            {entry.badge && (
                                                <div
                                                    className="inline-flex items-center rounded-full px-2 py-0.5 text-[9px] font-bold uppercase tracking-wider"
                                                    style={{
                                                        backgroundColor: "#EDE9FE",
                                                        color: "#7C3AED",
                                                    }}
                                                >
                                                    {entry.badge}
                                                </div>
                                            )}
                                        </div>
                                    </div>
                                );
                            })}
                        </div>

                        {/* ── Bottom note ── */}
                        <p
                            className="text-[11px] font-medium text-center mt-6 leading-relaxed relative z-10"
                            style={{ color: "#9CA3AF" }}
                        >
                            * Top 30 receive 3 months of ZuraLog Pro.
                            <br />
                            First 30 receive 1 month. Refer friends to climb.
                        </p>
                    </div>
                </div>
            </div>
        </section>
    );
}
