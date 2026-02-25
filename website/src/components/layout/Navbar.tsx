"use client";

/**
 * Navbar — always-visible top navigation for the ZuraLog marketing site.
 *
 * Two visual states:
 *   - Transparent: fully transparent background at the top of the page.
 *   - Frosted: cream glassmorphism with backdrop-blur when scrolled > 60px.
 *
 * Mobile: animated hamburger → dropdown panel with the same links + CTA.
 */

import { useEffect, useState, useCallback } from "react";
import { motion } from "framer-motion";
import Image from "next/image";

/** Nav link definitions */
const NAV_LINKS = [
    { label: "Features", id: "features" },
    { label: "How It Works", id: "how-it-works" },
    { label: "Waitlist", id: "waitlist" },
] as const;

export function Navbar() {
    const [scrolled, setScrolled] = useState(false);
    const [menuOpen, setMenuOpen] = useState(false);

    /** Track whether the user has scrolled past the threshold. */
    useEffect(() => {
        const handler = () => setScrolled(window.scrollY > 60);
        handler();
        window.addEventListener("scroll", handler, { passive: true });
        return () => window.removeEventListener("scroll", handler);
    }, []);

    /**
     * Smoothly scrolls to a section by ID and closes the mobile menu.
     * @param id - The element ID to scroll to.
     */
    const handleNav = useCallback((id: string) => {
        setMenuOpen(false);
        document.getElementById(id)?.scrollIntoView({ behavior: "smooth" });
    }, []);

    return (
        <motion.header
            initial={{ opacity: 0, y: -8 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.4, ease: "easeOut" }}
            className="fixed inset-x-0 top-0 z-50"
        >
            {/* ── Main bar ── */}
            <div
                className="transition-all duration-300"
                style={{
                    background: scrolled ? "rgba(250, 250, 245, 0.85)" : "transparent",
                    backdropFilter: scrolled ? "blur(24px)" : "none",
                    WebkitBackdropFilter: scrolled ? "blur(24px)" : "none",
                    borderBottom: scrolled
                        ? "1px solid var(--border-light)"
                        : "1px solid transparent",
                }}
            >
                <div
                    className="mx-auto flex h-16 items-center justify-between"
                    style={{ maxWidth: "1280px", padding: "0 clamp(1.5rem, 4vw, 3rem)" }}
                >
                    {/* ── Logo (left) ── */}
                    <button
                        onClick={() => window.scrollTo({ top: 0, behavior: "smooth" })}
                        className="flex items-center gap-2.5 transition-opacity hover:opacity-70"
                        aria-label="Back to top"
                    >
                        <Image
                            src="/logo/Zuralog.png"
                            alt="ZuraLog"
                            width={32}
                            height={32}
                            className="object-contain"
                            priority
                        />
                        <span
                            className="font-semibold"
                            style={{
                                color: "var(--text-primary)",
                                fontSize: "15px",
                            }}
                        >
                            ZuraLog
                        </span>
                    </button>

                    {/* ── Desktop nav links (center) ── */}
                    <nav
                        className="hidden items-center gap-8 md:flex"
                        aria-label="Main navigation"
                    >
                        {NAV_LINKS.map(({ label, id }) => (
                            <button
                                key={id}
                                onClick={() => handleNav(id)}
                                className="transition-colors duration-200 text-sm font-medium"
                                style={{ color: "var(--text-secondary)" }}
                                onMouseEnter={(e) => {
                                    (e.currentTarget as HTMLButtonElement).style.color =
                                        "var(--text-primary)";
                                }}
                                onMouseLeave={(e) => {
                                    (e.currentTarget as HTMLButtonElement).style.color =
                                        "var(--text-secondary)";
                                }}
                            >
                                {label}
                            </button>
                        ))}
                    </nav>

                    {/* ── Right zone: CTA + hamburger ── */}
                    <div className="flex items-center gap-3">
                        {/* Desktop CTA */}
                        <button
                            onClick={() => handleNav("waitlist")}
                            className="hidden md:inline-flex items-center justify-center px-5 py-2 rounded-full text-sm font-semibold text-white animate-pulse-glow transition-opacity hover:opacity-90"
                            style={{
                                background: "#FFAB76",
                                animationDelay: "2000ms",
                            }}
                        >
                            Join Waitlist
                        </button>

                        {/* Mobile hamburger */}
                        <button
                            className="flex flex-col gap-[5px] p-1 md:hidden"
                            onClick={() => setMenuOpen((open) => !open)}
                            aria-label={menuOpen ? "Close menu" : "Open menu"}
                            aria-expanded={menuOpen}
                        >
                            <span
                                className="block h-px w-5 transition-transform duration-200"
                                style={{
                                    backgroundColor: "var(--text-primary)",
                                    transform: menuOpen
                                        ? "translateY(6px) rotate(45deg)"
                                        : "none",
                                }}
                            />
                            <span
                                className="block h-px w-5 transition-opacity duration-200"
                                style={{
                                    backgroundColor: "var(--text-primary)",
                                    opacity: menuOpen ? 0 : 1,
                                }}
                            />
                            <span
                                className="block h-px w-5 transition-transform duration-200"
                                style={{
                                    backgroundColor: "var(--text-primary)",
                                    transform: menuOpen
                                        ? "translateY(-8px) rotate(-45deg)"
                                        : "none",
                                }}
                            />
                        </button>
                    </div>
                </div>
            </div>

            {/* ── Mobile menu panel ── */}
            {menuOpen && (
                <motion.div
                    initial={{ opacity: 0, height: 0 }}
                    animate={{ opacity: 1, height: "auto" }}
                    exit={{ opacity: 0, height: 0 }}
                    transition={{ duration: 0.2, ease: "easeOut" }}
                    className="overflow-hidden border-b backdrop-blur-xl md:hidden"
                    style={{
                        backgroundColor: "rgba(250, 250, 245, 0.95)",
                        borderColor: "var(--border-light)",
                    }}
                >
                    <nav
                        className="flex flex-col gap-1 p-4"
                        aria-label="Mobile navigation"
                    >
                        {NAV_LINKS.map(({ label, id }) => (
                            <button
                                key={id}
                                onClick={() => handleNav(id)}
                                className="rounded-xl px-4 py-3 text-left text-sm font-medium transition-colors duration-150 hover:bg-black/5"
                                style={{ color: "var(--text-primary)" }}
                            >
                                {label}
                            </button>
                        ))}

                        {/* Mobile CTA */}
                        <button
                            onClick={() => handleNav("waitlist")}
                            className="mt-2 w-full rounded-full px-5 py-2.5 text-sm font-semibold text-white animate-pulse-glow transition-opacity hover:opacity-90"
                            style={{
                                background: "#FFAB76",
                                animationDelay: "2000ms",
                            }}
                        >
                            Join Waitlist
                        </button>
                    </nav>
                </motion.div>
            )}
        </motion.header>
    );
}
