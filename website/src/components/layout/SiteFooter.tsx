"use client";

import { useRef, useEffect } from "react";
import Link from "next/link";
import Image from "next/image";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { MorphSVGPlugin } from "gsap/MorphSVGPlugin";
import {
    FaXTwitter,
    FaInstagram,
    FaLinkedinIn,
    FaTiktok,
    FaAppStoreIos,
    FaGooglePlay,
} from "react-icons/fa6";
import { ManageCookiesButton } from "@/components/ui/ManageCookiesButton";

if (typeof window !== "undefined") {
    gsap.registerPlugin(ScrollTrigger, MorphSVGPlugin);
}

/* ─────────────────────────────────────────────────────────────
   Wave paths — tall viewBox (0 0 1200 200) for dramatic shape
   RESTING:   gentle flat line at y=80
   STRETCHED: deep upward arch — enters fast → biggest bounce
───────────────────────────────────────────────────────────── */
const RESTING =
    "M0,80 C300,80 900,80 1200,80 L1200,200 L0,200 Z";
const STRETCHED =
    "M0,190 C200,0 1000,0 1200,190 L1200,200 L0,200 Z";

/* ─────────────────────────────────────────────────────────────
   Nav columns
───────────────────────────────────────────────────────────── */
const NAV_COLUMNS = [
    {
        heading: "Product",
        links: [
            { label: "Features",      href: "/#features" },
            { label: "How It Works",  href: "/#how-it-works" },
            { label: "Pricing",       href: "/pricing" },
            { label: "Join Waitlist", href: "/#waitlist" },
        ],
    },
    {
        heading: "Company",
        links: [
            { label: "About Us",   href: "/about" },
            { label: "Contact",    href: "/contact" },
            { label: "Support Us", href: "/support" },
            { label: "Blog",       href: "/blog" },
        ],
    },
    {
        heading: "Legal",
        links: [
            { label: "Privacy Policy",       href: "/privacy-policy" },
            { label: "Terms of Service",     href: "/terms-of-service" },
            { label: "Cookie Policy",        href: "/cookie-policy" },
            { label: "Community Guidelines", href: "/community-guidelines" },
        ],
    },
];

const SOCIAL_LINKS = [
    { label: "X (Twitter)", href: "https://twitter.com/zuralog",                icon: FaXTwitter },
    { label: "Instagram",   href: "https://instagram.com/zuralog",              icon: FaInstagram },
    { label: "LinkedIn",    href: "https://www.linkedin.com/company/112446156/", icon: FaLinkedinIn },
    { label: "TikTok",      href: "https://www.tiktok.com/@zuralog",            icon: FaTiktok },
];

const BOTTOM_LINKS = [
    { label: "Privacy Policy",       href: "/privacy-policy" },
    { label: "Terms of Service",     href: "/terms-of-service" },
    { label: "Cookie Policy",        href: "/cookie-policy" },
    { label: "Community Guidelines", href: "/community-guidelines" },
];

/* ─────────────────────────────────────────────────────────────
   Component
───────────────────────────────────────────────────────────── */
export function SiteFooter() {
    const footerRef   = useRef<HTMLElement>(null);
    const pathRef     = useRef<SVGPathElement>(null);
    const triggerRef  = useRef<ScrollTrigger | null>(null);
    const currentYear = new Date().getFullYear();

    useEffect(() => {
        const footer = footerRef.current;
        const path   = pathRef.current;
        if (!footer || !path) return;

        const prefersReducedMotion = window.matchMedia(
            "(prefers-reduced-motion: reduce)"
        ).matches;

        gsap.set(path, { attr: { d: RESTING } });
        if (prefersReducedMotion) return;

        triggerRef.current = ScrollTrigger.create({
            trigger: footer,
            start: "top 95%",
            onEnter: (self) => {
                const velocity  = Math.abs(self.getVelocity());
                // Guarantee a minimum intensity so the bounce is always visible
                const intensity = Math.min(Math.max(velocity / 2000, 0.4), 1.0);
                const amplitude = 1.2 + intensity * 1.2;
                const period    = Math.max(0.18, 0.5 - intensity * 0.25);

                gsap.timeline()
                    .set(path, { morphSVG: { shape: STRETCHED, shapeIndex: "auto" } })
                    .to(path, {
                        morphSVG: { shape: RESTING, shapeIndex: "auto" },
                        duration: 1.6,
                        ease: `elastic.out(${amplitude}, ${period})`,
                    });
            },
            onLeaveBack: () => {
                gsap.set(path, { morphSVG: { shape: RESTING } });
            },
        });

        return () => { triggerRef.current?.kill(); };
    }, []);

    return (
        <footer ref={footerRef} aria-label="Site footer">

            {/* ── Wave ─────────────────────────────────────────────────
                Solid sage fill — no pattern here so the background
                pattern reads clearly without doubling up.
            ──────────────────────────────────────────────────────── */}
            <svg
                viewBox="0 0 1200 200"
                preserveAspectRatio="none"
                className="w-full block"
                style={{ height: "clamp(60px, 10vw, 120px)", display: "block", marginBottom: "-1px" }}
                aria-hidden="true"
            >
                <path
                    ref={pathRef}
                    d={RESTING}
                    fill="var(--color-ds-sage)"
                />
            </svg>

            {/* ── Pattern frame ─────────────────────────────────────────
                The brand pattern tiles across the entire footer area.
                background-size keeps tiles at natural size — no stretch.
            ──────────────────────────────────────────────────────── */}
            <div
                className="relative"
                style={{
                    backgroundColor: "var(--color-ds-sage)",
                    backgroundImage: "url('/patterns/original.png')",
                    backgroundSize: "300px auto",
                    backgroundRepeat: "repeat",
                }}
            >
                {/* ── Floating content card ────────────────────────── */}
                <div className="px-4 sm:px-6 lg:px-10 pt-2 pb-8">
                    <div className="bg-ds-canvas rounded-[28px] overflow-hidden">

                        {/* Top content grid */}
                        <div className="grid grid-cols-1 gap-12 px-8 lg:px-12 pt-12 pb-10 sm:grid-cols-2 lg:grid-cols-[2fr_1fr_1fr_1fr]">

                            {/* Brand column */}
                            <div className="flex flex-col gap-5">
                                <Link
                                    href="/"
                                    className="inline-flex items-center gap-2 transition-opacity duration-200 hover:opacity-75"
                                    aria-label="Zuralog home"
                                >
                                    <Image
                                        src="/logo/ZuraLog-Forest-Green.svg"
                                        alt="Zuralog logo"
                                        width={26}
                                        height={26}
                                        className="object-contain"
                                    />
                                    <span className="font-jakarta text-[0.8125rem] font-semibold tracking-tight text-ds-text-primary">
                                        ZuraLog
                                    </span>
                                </Link>

                                <p className="font-jakarta text-[0.6875rem] font-semibold uppercase tracking-[0.22em] text-ds-sage">
                                    Unified Health. Made Smart.
                                </p>

                                <p className="font-jakarta text-[0.875rem] leading-relaxed text-ds-text-secondary max-w-xs">
                                    The AI that connects your fitness apps and actually
                                    thinks — so your health data finally works for you.
                                </p>

                                {/* App store badges */}
                                <div className="flex flex-col gap-2 pt-1">
                                    {[
                                        { icon: FaAppStoreIos, top: "Download on the", label: "App Store" },
                                        { icon: FaGooglePlay,  top: "Get it on",       label: "Google Play" },
                                    ].map(({ icon: Icon, top, label }) => (
                                        <div
                                            key={label}
                                            aria-label={`${label} — coming soon`}
                                            title="Coming soon"
                                            className="inline-flex w-fit cursor-not-allowed select-none items-center gap-2.5 rounded-ds-sm px-3.5 py-2.5 opacity-50 border border-ds-border-subtle bg-ds-surface-raised"
                                        >
                                            <Icon className="h-4 w-4 shrink-0 text-ds-sage" />
                                            <div className="leading-none">
                                                <div className="font-jakarta text-[8px] font-medium uppercase tracking-widest text-ds-text-secondary">
                                                    {top}
                                                </div>
                                                <div className="font-jakarta text-[12px] font-semibold text-ds-text-primary">
                                                    {label}
                                                </div>
                                            </div>
                                            <span className="ml-1 font-jakarta text-[10px] text-ds-text-secondary">
                                                Soon
                                            </span>
                                        </div>
                                    ))}
                                </div>

                                {/* Support email */}
                                <a
                                    href="mailto:support@zuralog.com"
                                    className="inline-flex items-center gap-1.5 font-jakarta text-[0.75rem] font-medium text-ds-text-secondary transition-colors duration-200 hover:text-ds-sage"
                                >
                                    <svg aria-hidden="true" viewBox="0 0 16 16" fill="none" className="h-3.5 w-3.5 shrink-0" stroke="currentColor" strokeWidth="1.5">
                                        <path d="M2 4l6 5 6-5M2 4h12v8H2V4z" strokeLinejoin="round" />
                                    </svg>
                                    support@zuralog.com
                                </a>

                                {/* Socials */}
                                <div className="flex items-center gap-2">
                                    {SOCIAL_LINKS.map(({ label, href, icon: Icon }) => (
                                        <a
                                            key={label}
                                            href={href}
                                            target="_blank"
                                            rel="noopener noreferrer"
                                            aria-label={label}
                                            className="flex h-8 w-8 items-center justify-center rounded-full border border-ds-border-subtle bg-ds-surface-raised text-ds-text-secondary transition-all duration-200 hover:border-ds-border-strong hover:bg-ds-sage-tint hover:text-ds-sage"
                                        >
                                            <Icon className="h-3.5 w-3.5" />
                                        </a>
                                    ))}
                                </div>
                            </div>

                            {/* Nav columns */}
                            {NAV_COLUMNS.map((col) => (
                                <div key={col.heading} className="flex flex-col gap-4">
                                    <h3 className="font-jakarta text-[10px] font-semibold uppercase tracking-[0.22em] text-ds-text-secondary">
                                        {col.heading}
                                    </h3>
                                    <ul className="flex flex-col gap-3">
                                        {col.links.map(({ label, href }) => (
                                            <li key={label}>
                                                <Link
                                                    href={href}
                                                    className="font-jakarta text-[0.875rem] font-medium text-ds-text-secondary transition-colors duration-200 hover:text-ds-text-primary"
                                                >
                                                    {label}
                                                </Link>
                                            </li>
                                        ))}
                                    </ul>
                                </div>
                            ))}
                        </div>

                        {/* Divider */}
                        <div className="mx-8 lg:mx-12 h-px bg-ds-border-subtle" />

                        {/* Bottom bar */}
                        <div className="flex flex-col items-center justify-between gap-4 px-8 lg:px-12 py-6 sm:flex-row">
                            <p className="font-jakarta text-[0.75rem] text-ds-text-secondary">
                                &copy; {currentYear} ZuraLog. All rights reserved.
                            </p>

                            <nav aria-label="Legal navigation" className="flex flex-wrap items-center gap-x-4 gap-y-1">
                                {BOTTOM_LINKS.map(({ label, href }, i, arr) => (
                                    <span key={label} className="inline-flex items-center gap-x-4">
                                        <Link
                                            href={href}
                                            className="font-jakarta text-[0.75rem] font-medium text-ds-text-secondary transition-colors duration-200 hover:text-ds-text-primary"
                                        >
                                            {label}
                                        </Link>
                                        {i < arr.length - 1 && (
                                            <span aria-hidden="true" className="text-ds-text-secondary opacity-30">·</span>
                                        )}
                                    </span>
                                ))}
                                <span aria-hidden="true" className="text-ds-text-secondary opacity-30">·</span>
                                <ManageCookiesButton />
                            </nav>
                        </div>

                    </div>
                </div>

                {/* Bottom padding — pattern shows below the card */}
                <div className="h-6" />
            </div>
        </footer>
    );
}
