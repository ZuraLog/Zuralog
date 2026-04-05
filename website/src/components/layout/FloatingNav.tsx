"use client";

import { useState, useRef, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import Image from "next/image";
import Link from "next/link";
import {
    ChevronDown,
    LayoutDashboard,
    Sparkles,
    Smartphone,
    Activity,
    BookOpen,
    Rss,
    Users,
    LifeBuoy,
} from "lucide-react";
import { DSButton } from "@/components/design-system";
import { useSoundContext } from "@/components/design-system/interactions/sound-provider";

/* ─────────────────────────────────────────────────────────────
   Nav data
───────────────────────────────────────────────────────────── */

const FEATURES = [
    { icon: LayoutDashboard, label: "Health Dashboard",  description: "All your metrics in one place" },
    { icon: Sparkles,        label: "AI Insights",       description: "Smart patterns from your data" },
    { icon: Smartphone,      label: "Device Sync",       description: "Apple Health, Strava & more" },
    { icon: Activity,        label: "Activity Tracking", description: "Steps, workouts, sleep" },
];

const RESOURCES = [
    { icon: BookOpen, label: "Documentation", description: "Guides and API reference" },
    { icon: Rss,      label: "Blog",          description: "Health & product updates" },
    { icon: Users,    label: "Community",     description: "Connect with other users" },
    { icon: LifeBuoy, label: "Support",       description: "Get help from our team" },
];

const EXPO_OUT: [number, number, number, number] = [0.16, 1, 0.3, 1];

/* ─────────────────────────────────────────────────────────────
   Dropdown panel
───────────────────────────────────────────────────────────── */

interface DropdownItem {
    icon: React.ElementType;
    label: string;
    description: string;
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
                {items.map(({ icon: Icon, label, description }) => (
                    <button
                        key={label}
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
                    </button>
                ))}
            </div>
        </motion.div>
    );
}

/* ─────────────────────────────────────────────────────────────
   Nav trigger (with optional dropdown)
───────────────────────────────────────────────────────────── */

interface NavTriggerProps {
    label: string;
    items?: DropdownItem[];
}

function NavTrigger({ label, items }: NavTriggerProps) {
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

    return (
        <div
            className="relative"
            onMouseEnter={handleEnter}
            onMouseLeave={handleLeave}
        >
            <button
                className="flex items-center gap-1 font-jakarta text-[0.8125rem] font-medium text-ds-text-secondary transition-colors duration-150 hover:text-ds-text-primary py-1 px-1"
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

            <AnimatePresence>
                {open && items && <DropdownPanel items={items} />}
            </AnimatePresence>
        </div>
    );
}

/* ─────────────────────────────────────────────────────────────
   Main floating nav
───────────────────────────────────────────────────────────── */

export function FloatingNav() {
    const { playSound } = useSoundContext();

    return (
        <motion.header
            initial={{ opacity: 0, y: -16 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5, ease: EXPO_OUT, delay: 0.1 }}
            className="fixed inset-x-0 top-5 z-50 flex justify-center pointer-events-none px-4"
        >
            <nav
                className="pointer-events-auto flex items-center gap-6 rounded-ds-pill border border-ds-border-strong bg-ds-surface/80 backdrop-blur-xl px-4 py-2.5 shadow-sm"
                aria-label="Main navigation"
            >
                {/* Brand */}
                <Link
                    href="/"
                    onMouseEnter={() => playSound("tick")}
                    onClick={() => playSound("click")}
                    className="flex items-center gap-2 shrink-0 transition-opacity duration-200 hover:opacity-75"
                    aria-label="ZuraLog home"
                >
                    <Image
                        src="/logo/ZuraLog-Sage.svg"
                        alt="ZuraLog"
                        width={20}
                        height={20}
                        className="object-contain"
                    />
                    <span className="font-jakarta text-[0.8125rem] font-semibold text-ds-sage tracking-tight">
                        ZuraLog
                    </span>
                </Link>

                {/* Divider */}
                <span className="h-4 w-px bg-ds-border-strong shrink-0" aria-hidden />

                {/* Center links */}
                <div className="flex items-center gap-0.5">
                    <NavTrigger label="Features"  items={FEATURES} />
                    <NavTrigger label="Pricing" />
                    <NavTrigger label="Resources" items={RESOURCES} />
                </div>

                {/* Divider */}
                <span className="h-4 w-px bg-ds-border-strong shrink-0" aria-hidden />

                {/* CTA */}
                <DSButton
                    intent="primary"
                    size="sm"
                    onMouseEnter={() => playSound("tick")}
                    onClick={() => playSound("click")}
                >
                    Join Waitlist
                </DSButton>
            </nav>
        </motion.header>
    );
}
