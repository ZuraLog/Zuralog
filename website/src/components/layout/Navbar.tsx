"use client";

/**
 * Navbar — compact fixed top navigation for the ZuraLog marketing site.
 *
 * Two visual states:
 *   - Transparent: at the very top of the page.
 *   - Frosted: cream glassmorphism with backdrop-blur when scrolled > 40px.
 *
 * Nav links map to real section IDs on the page.
 * Mobile: hamburger → compact dropdown.
 */

import { useEffect, useState, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import Image from "next/image";

const NAV_LINKS = [
    { label: "How It Works", id: "mobile-section" },
    { label: "Features",     id: "bento-section"  },
    { label: "Early Access", id: "waitlist"        },
] as const;

export function Navbar() {
    const [scrolled, setScrolled] = useState(false);
    const [menuOpen, setMenuOpen] = useState(false);

    useEffect(() => {
        const handler = () => setScrolled(window.scrollY > 40);
        handler();
        window.addEventListener("scroll", handler, { passive: true });
        return () => window.removeEventListener("scroll", handler);
    }, []);

    const handleNav = useCallback((id: string) => {
        setMenuOpen(false);
        document.getElementById(id)?.scrollIntoView({ behavior: "smooth" });
    }, []);

    return (
        <motion.header
            initial={{ opacity: 0, y: -6 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.35, ease: "easeOut" }}
            className="fixed inset-x-0 top-0 z-50"
        >
            {/* ── Main bar ── */}
            <div
                className="transition-all duration-300"
                style={{
                    background: scrolled ? "rgba(250, 250, 245, 0.88)" : "transparent",
                    backdropFilter: scrolled ? "blur(20px)" : "none",
                    WebkitBackdropFilter: scrolled ? "blur(20px)" : "none",
                    borderBottom: scrolled
                        ? "1px solid var(--border-light)"
                        : "1px solid transparent",
                }}
            >
                <div
                    className="mx-auto flex h-11 items-center justify-between"
                    style={{ maxWidth: "1280px", padding: "0 clamp(1rem, 3vw, 2.5rem)" }}
                >
                    {/* ── Logo ── */}
                    <button
                        onClick={() => window.scrollTo({ top: 0, behavior: "smooth" })}
                        className="flex items-center gap-2 transition-opacity hover:opacity-70"
                        aria-label="Back to top"
                    >
                        <Image
                            src="/logo/Zuralog.png"
                            alt="ZuraLog"
                            width={22}
                            height={22}
                            className="object-contain"
                            priority
                        />
                        <span
                            className="font-semibold tracking-tight"
                            style={{ color: "var(--text-primary)", fontSize: "13px" }}
                        >
                            ZuraLog
                        </span>
                    </button>

                    {/* ── Desktop nav links ── */}
                    <nav className="hidden items-center gap-6 md:flex" aria-label="Main navigation">
                        {NAV_LINKS.map(({ label, id }) => (
                            <button
                                key={id}
                                onClick={() => handleNav(id)}
                                className="text-xs font-medium transition-colors duration-150"
                                style={{ color: "var(--text-secondary)" }}
                                onMouseEnter={(e) =>
                                    ((e.currentTarget as HTMLButtonElement).style.color = "var(--text-primary)")
                                }
                                onMouseLeave={(e) =>
                                    ((e.currentTarget as HTMLButtonElement).style.color = "var(--text-secondary)")
                                }
                            >
                                {label}
                            </button>
                        ))}
                    </nav>

                    {/* ── Right: CTA + hamburger ── */}
                    <div className="flex items-center gap-2.5">
                        {/* Desktop CTA */}
                        <button
                            onClick={() => handleNav("waitlist")}
                            className="hidden md:inline-flex items-center justify-center px-3.5 py-1.5 rounded-full text-xs font-semibold animate-pulse-glow transition-opacity hover:opacity-90"
                            style={{
                                background: "#E8F5A8",
                                color: "#2D2D2D",
                                animationDelay: "2000ms",
                            }}
                        >
                            Join Waitlist
                        </button>

                        {/* Mobile hamburger */}
                        <button
                            className="flex flex-col gap-[4px] p-1 md:hidden"
                            onClick={() => setMenuOpen((o) => !o)}
                            aria-label={menuOpen ? "Close menu" : "Open menu"}
                            aria-expanded={menuOpen}
                        >
                            <span
                                className="block h-px w-4 transition-transform duration-200"
                                style={{
                                    backgroundColor: "var(--text-primary)",
                                    transform: menuOpen ? "translateY(5px) rotate(45deg)" : "none",
                                }}
                            />
                            <span
                                className="block h-px w-4 transition-opacity duration-200"
                                style={{
                                    backgroundColor: "var(--text-primary)",
                                    opacity: menuOpen ? 0 : 1,
                                }}
                            />
                            <span
                                className="block h-px w-4 transition-transform duration-200"
                                style={{
                                    backgroundColor: "var(--text-primary)",
                                    transform: menuOpen ? "translateY(-7px) rotate(-45deg)" : "none",
                                }}
                            />
                        </button>
                    </div>
                </div>
            </div>

            {/* ── Mobile dropdown ── */}
            <AnimatePresence>
                {menuOpen && (
                    <motion.div
                        key="mobile-menu"
                        initial={{ opacity: 0, y: -4 }}
                        animate={{ opacity: 1, y: 0 }}
                        exit={{ opacity: 0, y: -4 }}
                        transition={{ duration: 0.15, ease: "easeOut" }}
                        className="border-b backdrop-blur-xl md:hidden"
                        style={{
                            backgroundColor: "rgba(250, 250, 245, 0.96)",
                            borderColor: "var(--border-light)",
                        }}
                    >
                        <nav className="flex flex-col gap-0.5 px-4 py-3" aria-label="Mobile navigation">
                            {NAV_LINKS.map(({ label, id }) => (
                                <button
                                    key={id}
                                    onClick={() => handleNav(id)}
                                    className="rounded-lg px-3 py-2 text-left text-xs font-medium transition-colors duration-150 hover:bg-black/5"
                                    style={{ color: "var(--text-primary)" }}
                                >
                                    {label}
                                </button>
                            ))}
                            <button
                                onClick={() => handleNav("waitlist")}
                                className="mt-1.5 w-full rounded-full px-4 py-2 text-xs font-semibold animate-pulse-glow transition-opacity hover:opacity-90"
                                style={{
                                    background: "#E8F5A8",
                                    color: "#2D2D2D",
                                    animationDelay: "2000ms",
                                }}
                            >
                                Join Waitlist
                            </button>
                        </nav>
                    </motion.div>
                )}
            </AnimatePresence>
        </motion.header>
    );
}
