"use client";

import { useGSAP } from "@gsap/react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/dist/ScrollTrigger";
import { useRef, useEffect } from "react";
import { FaStrava, FaApple } from "react-icons/fa";
import { FcGoogle } from "react-icons/fc";
import { SiFitbit } from "react-icons/si";
import { IoIosFitness } from "react-icons/io";
import { TbBrain, TbMessages, TbRun, TbMoon, TbApple } from "react-icons/tb";
import { MdOutlineAutoAwesome } from "react-icons/md";
import { mobileScrollProgress } from "@/lib/mobile-scroll-bridge";

// Register ScrollTrigger once at module level
if (typeof window !== "undefined") {
    gsap.registerPlugin(ScrollTrigger);
}

/**
 * Content slides configuration.
 * Each slide has unique content and a distinct background color gradient.
 * The phone texture swap is handled by PhoneCanvas via the mobileScrollProgress bridge.
 */
const SLIDES = [
    { id: "unified",      bgFrom: "#CFE1B9", bgTo: "#DAEEF7" },
    { id: "intelligence", bgFrom: "#DAEEF7", bgTo: "#F7DAE4" },
    { id: "actions",      bgFrom: "#F7DAE4", bgTo: "#FDF0E0" },
    { id: "coach",        bgFrom: "#FDF0E0", bgTo: "#D6F0E0" },
];

/** Total number of content slides */
const SLIDE_COUNT = SLIDES.length;

export function MobileSection() {
    const sectionRef = useRef<HTMLElement>(null);
    const pinnedRef = useRef<HTMLDivElement>(null);

    /**
     * Cache pre-queried slide element references so the onUpdate callback
     * never touches the DOM for element lookups — only style writes.
     */
    const slideEls = useRef<(Element | null)[]>([]);

    // Populate slide element cache once on mount
    useEffect(() => {
        if (!pinnedRef.current) return;
        slideEls.current = SLIDES.map((slide) =>
            pinnedRef.current!.querySelector(`[data-slide="${slide.id}"]`)
        );

        // Promote each slide to its own compositor layer so the browser
        // doesn't repaint the whole section on opacity/transform changes.
        slideEls.current.forEach((el) => {
            if (el) {
                (el as HTMLElement).style.willChange = "transform, opacity";
            }
        });

        return () => {
            slideEls.current = [];
        };
    }, []);

    useGSAP(() => {
        if (!sectionRef.current || !pinnedRef.current) return;

        const slideDuration = 1 / SLIDE_COUNT;

        // ──────────────────────────────────────────────────────────────────────
        // Single master ScrollTrigger
        //
        // Previously there were 6 separate ScrollTrigger instances (1 pin +
        // 4 per-slide text + 1 background) each firing onUpdate on every scroll
        // frame. Consolidating into one means a single callback per frame for
        // all slide logic — ~6× fewer JS evaluations per scroll tick.
        //
        // This trigger also:
        //   • writes mobileScrollProgress.value (read by PhoneCanvas useFrame,
        //     replaces the CSS custom-property round-trip)
        //   • handles all slide opacity/translateY via direct gsap.set calls
        //   • handles background color interpolation
        // ──────────────────────────────────────────────────────────────────────
        const pinTrigger = ScrollTrigger.create({
            trigger: sectionRef.current,
            start: "top top",
            end: () => `+=${window.innerHeight * SLIDE_COUNT}`,
            pin: pinnedRef.current,
            scrub: true,
            onUpdate: (self) => {
                const p = self.progress;

                // ── 1. Write progress to the shared bridge (no CSS variable) ──
                mobileScrollProgress.value = p;

                // ── 2. Per-slide opacity + translateY ────────────────────────
                SLIDES.forEach((slide, i) => {
                    const slideEl = slideEls.current[i];
                    if (!slideEl) return;

                    const enterStart = i * slideDuration;
                    const enterEnd   = enterStart + slideDuration * 0.15;
                    const exitStart  = enterStart + slideDuration * 0.85;
                    const exitEnd    = enterStart + slideDuration;

                    let opacity    = 0;
                    let translateY = 30;

                    if (i === 0) {
                        // First slide: visible from start, fades out
                        if (p <= exitStart) {
                            opacity    = 1;
                            translateY = 0;
                        } else if (p <= exitEnd) {
                            const fadeOut = (p - exitStart) / (exitEnd - exitStart);
                            opacity    = 1 - fadeOut;
                            translateY = -30 * fadeOut;
                        }
                    } else if (i === SLIDE_COUNT - 1) {
                        // Last slide: fades in and stays
                        if (p >= enterStart && p <= enterEnd) {
                            const fadeIn = (p - enterStart) / (enterEnd - enterStart);
                            opacity    = fadeIn;
                            translateY = 30 * (1 - fadeIn);
                        } else if (p > enterEnd) {
                            opacity    = 1;
                            translateY = 0;
                        }
                    } else {
                        // Middle slides: fade in → hold → fade out
                        if (p >= enterStart && p <= enterEnd) {
                            const fadeIn = (p - enterStart) / (enterEnd - enterStart);
                            opacity    = fadeIn;
                            translateY = 30 * (1 - fadeIn);
                        } else if (p > enterEnd && p <= exitStart) {
                            opacity    = 1;
                            translateY = 0;
                        } else if (p > exitStart && p <= exitEnd) {
                            const fadeOut = (p - exitStart) / (exitEnd - exitStart);
                            opacity    = 1 - fadeOut;
                            translateY = -30 * fadeOut;
                        }
                    }

                    gsap.set(slideEl, { opacity, y: translateY });
                });

                // Background color is driven by PageBackground (scroll-driven global layer).
            },
        });

        return () => {
            pinTrigger.kill();
        };
    }, { scope: sectionRef });



    return (
        <section
            ref={sectionRef}
            id="mobile-section"
            className="relative w-full"
            style={{ height: `${(SLIDE_COUNT + 1) * 100}vh` }}
        >
            {/* Pinned viewport container */}
            <div
                ref={pinnedRef}
                className="w-full h-screen relative"
                style={{ backgroundColor: "transparent", overflow: "clip" }}
            >
                {/* ═══════════════════════════════════════════
                    SLIDE 1: "All Your Apps. One Place."
                    Layout: Large centered headline + app pill tags
                    ═══════════════════════════════════════════ */}
                <div
                    data-slide="unified"
                    className="absolute inset-0 flex items-center justify-center z-20 pointer-events-none"
                >
                    <div className="container mx-auto px-6 lg:px-12 flex flex-col md:flex-row items-center gap-8 lg:gap-16">
                        {/* Left: Typography block */}
                        <div className="w-full md:w-[50%] flex flex-col items-center md:items-start">
                            <span className="inline-block text-xs font-semibold tracking-[0.2em] uppercase mb-4" style={{ color: "#9B9894" }}>
                                One App to Rule Them All
                            </span>
                            <h2 className="text-4xl sm:text-5xl lg:text-6xl font-bold leading-[1.1] tracking-tight" style={{ color: "#F0EEE9" }}>
                                All your apps.
                                <br />
                                <span style={{ color: "#CFE1B9" }}>One place.</span>
                            </h2>
                            <p className="mt-6 text-lg max-w-[420px] leading-relaxed" style={{ color: "#9B9894" }}>
                                Strava for runs. CalAI for meals. Fitbit for steps. Oura for sleep. You shouldn&apos;t
                                need five apps to understand one body.
                            </p>

                            {/* App pills */}
                            <div className="mt-8 flex flex-wrap gap-3 justify-center md:justify-start pointer-events-auto">
                                {[
                                    { icon: <FaStrava className="text-[#FC4C02]" size={16} />, name: "Strava" },
                                    { icon: <FaApple className="text-[#F0EEE9]" size={16} />, name: "Apple Health" },
                                    { icon: <FcGoogle size={16} />, name: "Health Connect" },
                                    { icon: <SiFitbit className="text-[#00B0B9]" size={16} />, name: "Fitbit" },
                                    { icon: <IoIosFitness className="text-[#FA114F]" size={16} />, name: "Oura" },
                                ].map((app) => (
                                    <div
                                        key={app.name}
                                        className="flex items-center gap-2 backdrop-blur-sm rounded-full px-4 py-2 text-sm font-medium"
                                        style={{ backgroundColor: "rgba(30,30,32,0.72)", border: "1px solid rgba(207,225,185,0.10)", color: "#F0EEE9" }}
                                    >
                                        {app.icon}
                                        {app.name}
                                    </div>
                                ))}
                            </div>
                        </div>

                        {/* Right: Phone lives here (empty space for the 3D phone) */}
                        <div className="hidden md:block md:w-[50%] md:h-[60vh]" />
                    </div>
                </div>

                {/* ═══════════════════════════════════════════
                    SLIDE 2: "Not a Database. An Intelligence."
                    Layout: Large quote on left, insight card on right
                    ═══════════════════════════════════════════ */}
                <div
                    data-slide="intelligence"
                    className="absolute inset-0 flex items-center justify-center z-20 pointer-events-none opacity-0"
                >
                    <div className="container mx-auto px-6 lg:px-12 flex flex-col md:flex-row items-center gap-8 lg:gap-16">
                        {/* Left: Large quote style */}
                        <div className="w-full md:w-[50%] flex flex-col items-center md:items-start">
                            <div className="text-5xl sm:text-7xl lg:text-8xl font-black leading-none select-none mb-[-20px] lg:mb-[-30px]" style={{ color: "rgba(207,225,185,0.08)" }}>
                                &ldquo;
                            </div>
                            <h2 className="text-3xl sm:text-4xl lg:text-5xl font-semibold leading-[1.2] tracking-tight italic text-center md:text-left" style={{ color: "#F0EEE9" }}>
                                Why am I not
                                <br />
                                losing weight?
                            </h2>
                            <div className="mt-6 w-16 h-1 bg-[#E88BA7] rounded-full mx-auto md:mx-0" />
                            <p className="mt-6 text-lg max-w-[440px] leading-relaxed" style={{ color: "#9B9894" }}>
                                Other apps store data. Zuralog <span className="font-semibold" style={{ color: "#F0EEE9" }}>reasons</span> with it.
                                It cross-references your nutrition, exercise, sleep, and recovery
                                to surface answers that no single app could find alone.
                            </p>

                            {/* Insight example card */}
                            <div className="mt-8 backdrop-blur-sm rounded-2xl p-5 max-w-[440px] mx-auto md:mx-0 pointer-events-auto" style={{ backgroundColor: "rgba(30,30,32,0.72)", border: "1px solid rgba(207,225,185,0.10)" }}>
                                <div className="flex items-center gap-2 mb-3">
                                    <TbBrain className="text-[#E88BA7]" size={20} />
                                    <span className="text-xs font-semibold tracking-wide uppercase text-[#E88BA7]">
                                        AI Insight
                                    </span>
                                </div>
                                <p className="text-sm leading-relaxed" style={{ color: "#9B9894" }}>
                                    &ldquo;Your CalAI data shows an avg. 2,180 cal/day, but Strava activity
                                    puts maintenance at ~1,950. You&apos;re in a 230 cal surplus. Running dropped
                                    from 8 to 3 sessions this month.&rdquo;
                                </p>
                            </div>
                        </div>

                        {/* Right: Phone space */}
                        <div className="hidden md:block md:w-[50%] md:h-[60vh]" />
                    </div>
                </div>

                {/* ═══════════════════════════════════════════
                    SLIDE 3: "Say it. It's Done."
                    Layout: Horizontal command list with icons
                    ═══════════════════════════════════════════ */}
                <div
                    data-slide="actions"
                    className="absolute inset-0 flex items-center justify-center z-20 pointer-events-none opacity-0"
                >
                    <div className="container mx-auto px-6 lg:px-12 flex flex-col md:flex-row items-center gap-8 lg:gap-16">
                        {/* Left: Feature list */}
                        <div className="w-full md:w-[50%] flex flex-col items-center md:items-start">
                            <span className="inline-block text-xs font-semibold tracking-[0.2em] uppercase mb-4 text-center md:text-left" style={{ color: "#9B9894" }}>
                                Your AI Chief of Staff
                            </span>
                            <h2 className="text-4xl sm:text-5xl lg:text-6xl font-bold leading-[1.1] tracking-tight text-center md:text-left" style={{ color: "#F0EEE9" }}>
                                Say it.
                                <br />
                                <span style={{ color: "#CFE1B9" }}>It&apos;s done.</span>
                            </h2>

                            {/* Command examples */}
                            <div className="mt-10 flex flex-col gap-5 w-full max-w-[460px] mx-auto md:mx-0">
                                {[
                                    {
                                        icon: <TbRun size={22} className="text-[#FC4C02]" />,
                                        command: "\"Start a run for me\"",
                                        result: "Opens Strava to the recording screen",
                                    },
                                    {
                                        icon: <TbApple size={22} className="text-[#8BC34A]" />,
                                        command: "\"Log yesterday's lunch\"",
                                        result: "Burrito logged via Apple Health, backdated",
                                    },
                                    {
                                        icon: <TbMessages size={22} className="text-[#2196F3]" />,
                                        command: "\"What should I eat tonight?\"",
                                        result: "Checks your remaining calorie budget",
                                    },
                                ].map((item) => (
                                    <div
                                        key={item.command}
                                        className="flex items-start gap-4 backdrop-blur-sm rounded-xl p-4 pointer-events-auto"
                                        style={{ backgroundColor: "rgba(30,30,32,0.72)", border: "1px solid rgba(207,225,185,0.10)" }}
                                    >
                                        <div className="flex-shrink-0 w-10 h-10 rounded-lg flex items-center justify-center" style={{ backgroundColor: "rgba(207,225,185,0.08)" }}>
                                            {item.icon}
                                        </div>
                                        <div>
                                            <p className="text-sm font-semibold" style={{ color: "#F0EEE9" }}>{item.command}</p>
                                            <p className="text-sm mt-0.5" style={{ color: "#9B9894" }}>{item.result}</p>
                                        </div>
                                    </div>
                                ))}
                            </div>
                        </div>

                        {/* Right: Phone space */}
                        <div className="hidden md:block md:w-[50%] md:h-[60vh]" />
                    </div>
                </div>

                {/* ═══════════════════════════════════════════
                    SLIDE 4: "Knows You. Before You Ask."
                    Layout: Dramatic centered statement + CTA
                    ═══════════════════════════════════════════ */}
                <div
                    data-slide="coach"
                    className="absolute inset-0 flex items-center justify-center z-20 pointer-events-none opacity-0"
                >
                    <div className="container mx-auto px-6 lg:px-12 flex flex-col md:flex-row items-center gap-8 lg:gap-16">
                        {/* Left: Centered dramatic statement */}
                        <div className="w-full md:w-[50%] flex flex-col items-center md:items-start text-center md:text-left">
                            <MdOutlineAutoAwesome className="text-[#CFE1B9] mb-4" size={36} />
                            <h2 className="text-4xl sm:text-5xl lg:text-6xl font-bold leading-[1.1] tracking-tight" style={{ color: "#F0EEE9" }}>
                                Knows you.
                                <br />
                                <span style={{ color: "#CFE1B9" }}>Before you ask.</span>
                            </h2>
                            <p className="mt-6 text-lg max-w-[440px] leading-relaxed" style={{ color: "#9B9894" }}>
                                Zuralog isn&apos;t passive. It watches your trends, spots when things slip,
                                and speaks up. A tough-love coach that lives in your pocket.
                            </p>

                            {/* Proactive notification examples */}
                            <div className="mt-8 flex flex-col gap-3 w-full max-w-[400px]">
                                <div className="flex items-center gap-3 backdrop-blur-sm rounded-full px-5 py-3 pointer-events-auto" style={{ backgroundColor: "rgba(30,30,32,0.72)", border: "1px solid rgba(207,225,185,0.10)" }}>
                                     <TbMoon className="text-indigo-400 flex-shrink-0" size={18} />
                                     <p className="text-xs sm:text-sm" style={{ color: "#9B9894" }}>
                                         <span className="font-semibold" style={{ color: "#F0EEE9" }}>5hr sleep detected.</span> Keep today&apos;s run in Zone 2.
                                     </p>
                                </div>
                                <div className="flex items-center gap-3 backdrop-blur-sm rounded-full px-5 py-3 pointer-events-auto" style={{ backgroundColor: "rgba(30,30,32,0.72)", border: "1px solid rgba(207,225,185,0.10)" }}>
                                     <TbRun className="text-orange-400 flex-shrink-0" size={18} />
                                     <p className="text-xs sm:text-sm" style={{ color: "#9B9894" }}>
                                         <span className="font-semibold" style={{ color: "#F0EEE9" }}>No run in 5 days.</span> Forgetting something?
                                     </p>
                                </div>
                                <div className="flex items-center gap-3 backdrop-blur-sm rounded-full px-5 py-3 pointer-events-auto" style={{ backgroundColor: "rgba(30,30,32,0.72)", border: "1px solid rgba(207,225,185,0.10)" }}>
                                     <TbApple className="text-green-500 flex-shrink-0" size={18} />
                                     <p className="text-xs sm:text-sm" style={{ color: "#9B9894" }}>
                                         <span className="font-semibold" style={{ color: "#F0EEE9" }}>Calories up 15%</span> vs last week. Want a plan?
                                     </p>
                                </div>
                            </div>

                            <button
                                className="pointer-events-auto mt-10 btn-pattern-light bg-[#CFE1B9] text-[#141E18] px-8 py-4 rounded-full text-base md:text-lg font-semibold transition-all duration-300 shadow-[0_4px_20px_rgba(207,225,185,0.45)] hover:shadow-[0_6px_35px_rgba(207,225,185,0.6)] hover:scale-[1.04] hover:-translate-y-0.5 active:scale-[0.97]"
                                onClick={() => document.getElementById("waitlist")?.scrollIntoView({ behavior: "smooth" })}
                            >
                                <span className="relative z-2">Join the Waitlist</span>
                            </button>
                        </div>

                        {/* Right: Phone space */}
                        <div className="hidden md:block md:w-[50%] md:h-[60vh]" />
                    </div>
                </div>

                {/* ═══════════════════════════════════════════
                    Progress indicator dots
                    ═══════════════════════════════════════════ */}
                <div className="absolute bottom-6 md:bottom-8 left-1/2 -translate-x-1/2 z-30 flex gap-2">
                    {SLIDES.map((slide, i) => (
                        <div
                            key={slide.id}
                            className="slide-dot w-2 h-2 rounded-full transition-all duration-300"
                            style={{ backgroundColor: "rgba(207,225,185,0.25)" }}
                            data-dot-index={i}
                        />
                    ))}
                </div>

            </div>
        </section>
    );
}
