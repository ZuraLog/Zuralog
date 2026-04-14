"use client";

import { useState, useRef, useCallback } from "react";
import { useRouter } from "next/navigation";
import { motion, AnimatePresence } from "framer-motion";
import Image from "next/image";
import Link from "next/link";
import {
    ChevronDown,
    Sun,
    BarChart2,
    MessageSquare,
    Trophy,
    TrendingUp,
    Info,
    Mail,
    LifeBuoy,
    Shield,
    FileText,
    BookOpen,
    Volume2,
    VolumeX,
    Menu,
    X,
} from "lucide-react";
import { DSButton } from "@/components/design-system";
import { useSoundContext } from "@/components/design-system/interactions/sound-provider";
import { useCursorParallax } from "@/hooks/use-cursor-parallax";

/* ─────────────────────────────────────────────────────────────
   Nav data
───────────────────────────────────────────────────────────── */

const FEATURES = [
    {
        icon: Sun,
        label: "Today",
        description: "Quick logs & AI insight",
        href: "/#today-section",
    },
    {
        icon: BarChart2,
        label: "Data",
        description: "All your health data, one place",
        href: "/#data-section",
    },
    {
        icon: MessageSquare,
        label: "Coach",
        description: "Smart AI assistant",
        href: "/#coach-section",
    },
    {
        icon: Trophy,
        label: "Progress",
        description: "Goals, achievements & journal",
        href: "/#progress-section",
    },
    {
        icon: TrendingUp,
        label: "Trends",
        description: "Discover data correlations",
        href: "/#trends-section",
    },
];

const RESOURCES = [
    { icon: Info,     label: "About Us",             description: "Our story and mission",         href: "/about" },
    { icon: Mail,     label: "Contact",              description: "Get in touch with us",          href: "/contact" },
    { icon: LifeBuoy, label: "Support",              description: "Get help from our team",        href: "/support" },
    { icon: Shield,   label: "Privacy Policy",       description: "How we handle your data",       href: "/privacy-policy" },
    { icon: FileText, label: "Terms of Service",     description: "Usage terms and conditions",    href: "/terms-of-service" },
    { icon: BookOpen, label: "Community Guidelines", description: "Our community standards",        href: "/community-guidelines" },
];

const EXPO_OUT: [number, number, number, number] = [0.16, 1, 0.3, 1];

/* ─────────────────────────────────────────────────────────────
   Desktop dropdown panel
───────────────────────────────────────────────────────────── */

interface DropdownItem {
    icon: React.ComponentType<{ size?: number; className?: string }>;
    label: string;
    description: string;
    href: string;
}

function DropdownPanel({ items }: { items: DropdownItem[] }) {
    const { playSound } = useSoundContext();

    return (
        <motion.div
            initial={{ opacity: 0, y: -8, scale: 0.97 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: -6, scale: 0.97 }}
            transition={{ duration: 0.2, ease: EXPO_OUT }}
            className="absolute top-full left-1/2 -translate-x-1/2 mt-3 w-64 rounded-ds-xl border border-ds-border-strong bg-ds-surface-raised backdrop-blur-xl shadow-lg overflow-hidden z-50"
        >
            <div className="p-2 flex flex-col gap-0.5">
                {items.map(({ icon: Icon, label, description, href }) => (
                    <Link
                        key={label}
                        href={href}
                        onMouseEnter={() => playSound("tick")}
                        onClick={() => playSound("pop")}
                        className="group flex items-center gap-3 rounded-ds-md px-3 py-2.5 text-left transition-colors duration-150 hover:bg-ds-sage-tint w-full"
                    >
                        <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-ds-sm bg-ds-surface text-ds-sage border border-ds-border-subtle">
                            <Icon size={15} />
                        </span>
                        <span className="flex flex-col">
                            <span className="font-jakarta text-[0.8125rem] font-medium text-ds-text-primary leading-tight">
                                {label}
                            </span>
                            <span className="font-jakarta text-[0.6875rem] font-medium text-ds-text-secondary leading-tight mt-0.5">
                                {description}
                            </span>
                        </span>
                    </Link>
                ))}
            </div>
        </motion.div>
    );
}

/* ─────────────────────────────────────────────────────────────
   Desktop nav trigger (with optional dropdown)
───────────────────────────────────────────────────────────── */

interface NavTriggerProps {
    label: string;
    href?: string;
    items?: DropdownItem[];
}

function NavTrigger({ label, href, items }: NavTriggerProps) {
    const [open, setOpen]   = useState(false);
    const closeTimer        = useRef<ReturnType<typeof setTimeout> | null>(null);
    const { playSound }     = useSoundContext();

    const handleEnter = useCallback(() => {
        if (closeTimer.current) clearTimeout(closeTimer.current);
        playSound("tick");
        if (items) setOpen(true);
    }, [items, playSound]);

    const handleLeave = useCallback(() => {
        if (!items) return;
        closeTimer.current = setTimeout(() => setOpen(false), 120);
    }, [items]);

    const buttonClass = "flex items-center gap-1 font-jakarta text-[0.8125rem] font-medium text-ds-text-secondary transition-colors duration-150 hover:text-ds-text-primary py-1 px-1";

    return (
        <div
            className="relative"
            onMouseEnter={handleEnter}
            onMouseLeave={handleLeave}
        >
            {href ? (
                <Link
                    href={href}
                    className={buttonClass}
                    onClick={() => playSound("click")}
                >
                    {label}
                </Link>
            ) : (
                <button
                    className={buttonClass}
                    aria-expanded={open}
                    onClick={() => { items && setOpen((o) => !o); playSound("click"); }}
                >
                    {label}
                    {items && (
                        <motion.span
                            animate={{ rotate: open ? 180 : 0 }}
                            transition={{ duration: 0.2, ease: EXPO_OUT }}
                            className="inline-flex"
                        >
                            <ChevronDown size={13} className="text-ds-text-secondary" />
                        </motion.span>
                    )}
                </button>
            )}

            <AnimatePresence>
                {open && items && <DropdownPanel items={items} />}
            </AnimatePresence>
        </div>
    );
}

/* ─────────────────────────────────────────────────────────────
   Mobile full-screen menu
───────────────────────────────────────────────────────────── */

function MobileMenu({ onClose }: { onClose: () => void }) {
    const { playSound, muted, toggleMute } = useSoundContext();
    const router = useRouter();

    const handleLink = useCallback((href: string) => {
        playSound("click");
        onClose();
        setTimeout(() => router.push(href), 180);
    }, [playSound, onClose, router]);

    return (
        <motion.div
            initial={{ opacity: 0, y: -12 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -8 }}
            transition={{ duration: 0.22, ease: EXPO_OUT }}
            className="fixed inset-0 z-[60] flex flex-col font-jakarta"
            style={{ backgroundColor: "#F0EEE9" }}
        >
            {/* Subtle brand pattern */}
            <div
                aria-hidden="true"
                className="absolute inset-0 pointer-events-none"
                style={{
                    backgroundImage: "url('/patterns/original.png')",
                    backgroundSize: "300px auto",
                    backgroundRepeat: "repeat",
                    opacity: 0.04,
                }}
            />

            {/* Top bar */}
            <div className="relative flex items-center justify-between px-5 py-4 flex-shrink-0">
                <button
                    onClick={() => handleLink("/")}
                    className="flex items-center gap-2"
                    aria-label="ZuraLog home"
                >
                    <Image
                        src="/logo/ZuraLog-Forest-Green.svg"
                        alt="ZuraLog"
                        width={22}
                        height={22}
                        className="object-contain"
                    />
                    <span className="text-[0.9rem] font-semibold tracking-tight" style={{ color: "#344E41" }}>
                        ZuraLog
                    </span>
                </button>

                <button
                    onClick={() => { playSound("pop"); onClose(); }}
                    className="flex h-9 w-9 items-center justify-center rounded-full transition-colors"
                    style={{ background: "rgba(52,78,65,0.08)" }}
                    aria-label="Close menu"
                >
                    <X size={17} style={{ color: "#344E41" }} />
                </button>
            </div>

            <div className="h-px mx-5" style={{ background: "rgba(52,78,65,0.08)" }} />

            {/* Scrollable body */}
            <div className="relative flex-1 overflow-y-auto px-5 py-5 flex flex-col gap-5">

                {/* Features */}
                <div>
                    <p
                        className="text-[10px] font-semibold uppercase tracking-[0.2em] mb-2 px-2"
                        style={{ color: "rgba(52,78,65,0.4)" }}
                    >
                        Features
                    </p>
                    {FEATURES.map(({ icon: Icon, label, description, href }) => (
                        <button
                            key={label}
                            onClick={() => handleLink(href)}
                            onTouchStart={() => playSound("tick")}
                            className="flex items-center gap-3 w-full px-2 py-3 rounded-xl text-left transition-colors active:bg-[rgba(52,78,65,0.06)]"
                        >
                            <span
                                className="flex h-9 w-9 shrink-0 items-center justify-center rounded-[10px]"
                                style={{ background: "rgba(52,78,65,0.07)" }}
                            >
                                <Icon size={17} style={{ color: "#344E41" }} />
                            </span>
                            <span className="flex flex-col">
                                <span className="font-semibold text-[15px]" style={{ color: "#161618" }}>
                                    {label}
                                </span>
                                <span className="text-[12px]" style={{ color: "#6B6864" }}>
                                    {description}
                                </span>
                            </span>
                        </button>
                    ))}
                </div>

                <div className="h-px" style={{ background: "rgba(52,78,65,0.08)" }} />

                {/* Pages */}
                <div>
                    {[
                        { label: "Pricing",  href: "/pricing" },
                        { label: "About Us", href: "/about" },
                        { label: "Contact",  href: "/contact" },
                        { label: "Support",  href: "/support" },
                    ].map(({ label, href }) => (
                        <button
                            key={label}
                            onClick={() => handleLink(href)}
                            onTouchStart={() => playSound("tick")}
                            className="flex items-center justify-between w-full px-2 py-3.5 rounded-xl transition-colors active:bg-[rgba(52,78,65,0.06)]"
                        >
                            <span className="font-semibold text-[15px]" style={{ color: "#161618" }}>
                                {label}
                            </span>
                            <ChevronDown
                                size={14}
                                style={{ color: "rgba(52,78,65,0.35)", transform: "rotate(-90deg)" }}
                            />
                        </button>
                    ))}
                </div>

                <div className="h-px" style={{ background: "rgba(52,78,65,0.08)" }} />

                {/* Sound toggle */}
                <button
                    onClick={() => { toggleMute(); if (muted) playSound("pop"); }}
                    className="flex items-center justify-between w-full px-2 py-3.5 rounded-xl transition-colors active:bg-[rgba(52,78,65,0.06)]"
                >
                    <span className="font-semibold text-[15px]" style={{ color: "#161618" }}>
                        Sound Effects
                    </span>
                    <div className="flex items-center gap-2">
                        <span className="text-[13px]" style={{ color: "rgba(52,78,65,0.5)" }}>
                            {muted ? "Off" : "On"}
                        </span>
                        {muted
                            ? <VolumeX size={15} style={{ color: "rgba(52,78,65,0.4)" }} />
                            : <Volume2 size={15} style={{ color: "#344E41" }} />
                        }
                    </div>
                </button>
            </div>

            {/* Sticky CTA */}
            <div
                className="relative px-5 pb-8 pt-4 flex-shrink-0"
                style={{ borderTop: "1px solid rgba(52,78,65,0.08)" }}
            >
                <DSButton
                    intent="primary"
                    size="lg"
                    className="w-full justify-center"
                    onClick={() => handleLink("/#waitlist")}
                >
                    Join Waitlist
                </DSButton>
            </div>
        </motion.div>
    );
}

/* ─────────────────────────────────────────────────────────────
   Main floating nav
───────────────────────────────────────────────────────────── */

export function FloatingNav() {
    const { playSound, muted, toggleMute } = useSoundContext();
    const router = useRouter();
    const [mobileOpen, setMobileOpen] = useState(false);
    const navRef = useCursorParallax<HTMLElement>({ depth: 0.12 });

    return (
        <>
            <motion.header
                initial={{ opacity: 0, y: -16 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.5, ease: EXPO_OUT, delay: 0.1 }}
                className="fixed inset-x-0 top-5 z-50 flex justify-center pointer-events-none px-4"
            >
                <nav
                    ref={navRef}
                    className="pointer-events-auto will-change-transform flex items-center rounded-ds-pill border border-ds-border-strong bg-ds-surface/80 backdrop-blur-xl px-4 py-2.5 shadow-sm w-full md:w-auto gap-3 md:gap-6"
                    aria-label="Main navigation"
                >
                    {/* Brand — always visible */}
                    <Link
                        href="/"
                        onMouseEnter={() => playSound("tick")}
                        onClick={() => playSound("click")}
                        className="flex items-center gap-2 shrink-0 transition-opacity duration-200 hover:opacity-75"
                        aria-label="ZuraLog home"
                    >
                        <Image
                            src="/logo/ZuraLog-Forest-Green.svg"
                            alt="ZuraLog"
                            width={20}
                            height={20}
                            className="object-contain"
                        />
                        <span className="font-jakarta text-[0.8125rem] font-semibold text-ds-sage tracking-tight">
                            ZuraLog
                        </span>
                    </Link>

                    {/* ── Desktop only ── */}
                    <span className="hidden md:block h-4 w-px bg-ds-border-strong shrink-0" aria-hidden />

                    <div className="hidden md:flex items-center gap-0.5">
                        <NavTrigger label="Features"  items={FEATURES} />
                        <NavTrigger label="Pricing"   href="/pricing" />
                        <NavTrigger label="Resources" items={RESOURCES} />
                    </div>

                    <span className="hidden md:block h-4 w-px bg-ds-border-strong shrink-0" aria-hidden />

                    <button
                        type="button"
                        onClick={() => {
                            toggleMute();
                            if (muted) playSound("pop");
                        }}
                        className="hidden md:flex h-8 w-8 items-center justify-center rounded-full text-ds-text-secondary transition-colors duration-150 hover:text-ds-sage hover:bg-ds-sage-tint focus-visible:ring-2 focus-visible:ring-ds-sage focus-visible:ring-offset-1 focus-visible:outline-none"
                        aria-label={muted ? "Unmute sounds" : "Mute sounds"}
                        aria-pressed={!muted}
                    >
                        {muted ? <VolumeX size={15} /> : <Volume2 size={15} />}
                    </button>

                    <DSButton
                        intent="primary"
                        size="sm"
                        className="hidden md:inline-flex"
                        onMouseEnter={() => playSound("tick")}
                        onClick={() => { playSound("click"); router.push("/#waitlist"); }}
                    >
                        Join Waitlist
                    </DSButton>

                    {/* ── Mobile only ── */}
                    <div className="flex md:hidden items-center gap-2 ml-auto">
                        <DSButton
                            intent="primary"
                            size="sm"
                            onClick={() => { playSound("click"); router.push("/#waitlist"); }}
                        >
                            Join Waitlist
                        </DSButton>

                        <button
                            type="button"
                            onClick={() => { playSound("pop"); setMobileOpen(true); }}
                            className="flex h-8 w-8 items-center justify-center rounded-full text-ds-text-secondary transition-colors hover:text-ds-sage hover:bg-ds-sage-tint"
                            aria-label="Open menu"
                        >
                            <Menu size={17} />
                        </button>
                    </div>
                </nav>
            </motion.header>

            {/* Mobile menu overlay */}
            <AnimatePresence>
                {mobileOpen && (
                    <MobileMenu onClose={() => setMobileOpen(false)} />
                )}
            </AnimatePresence>
        </>
    );
}
