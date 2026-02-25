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
// Register ScrollTrigger
if (typeof window !== "undefined") {
    gsap.registerPlugin(ScrollTrigger);
}

/**
 * Content slides configuration.
 * Each slide has unique content and a distinct layout style.
 * The phone texture swap is handled by PhoneCanvas via CSS custom property.
 */
const SLIDES = [
    {
        id: "unified",
        bgFrom: "#CFE1B9",
        bgTo: "#DAEEF7",
    },
    {
        id: "intelligence",
        bgFrom: "#DAEEF7",
        bgTo: "#F7DAE4",
    },
    {
        id: "actions",
        bgFrom: "#F7DAE4",
        bgTo: "#FDF0E0",
    },
    {
        id: "coach",
        bgFrom: "#FDF0E0",
        bgTo: "#D6F0E0",
    },
];

/** Total number of content slides */
const SLIDE_COUNT = SLIDES.length;

export function MobileSection() {
    const sectionRef = useRef<HTMLElement>(null);
    const pinnedRef = useRef<HTMLDivElement>(null);

    useGSAP(() => {
        if (!sectionRef.current || !pinnedRef.current) return;

        // ──────────────────────────────────────────
        // Master pinned scroll: lock the viewport for
        // SLIDE_COUNT * 100vh of scroll distance
        // ──────────────────────────────────────────
        const pinTrigger = ScrollTrigger.create({
            trigger: sectionRef.current,
            start: "top top",
            end: () => `+=${window.innerHeight * SLIDE_COUNT}`,
            pin: pinnedRef.current,
            scrub: true,
            onUpdate: (self) => {
                // Broadcast progress as a CSS custom property for PhoneCanvas
                document.documentElement.style.setProperty(
                    "--mobile-scroll-progress",
                    String(self.progress)
                );
            },
        });

        // ──────────────────────────────────────────
        // Per-slide text animations
        // Each slide fades in, stays, then fades out
        // ──────────────────────────────────────────
        const slideDuration = 1 / SLIDE_COUNT;

        SLIDES.forEach((slide, i) => {
            const slideEl = pinnedRef.current!.querySelector(`[data-slide="${slide.id}"]`);
            if (!slideEl) return;

            const enterStart = i * slideDuration;
            const enterEnd = enterStart + slideDuration * 0.15;
            const exitStart = enterStart + slideDuration * 0.85;
            const exitEnd = enterStart + slideDuration;

            // Fade in
            ScrollTrigger.create({
                trigger: sectionRef.current,
                start: "top top",
                end: () => `+=${window.innerHeight * SLIDE_COUNT}`,
                scrub: true,
                onUpdate: (self) => {
                    const p = self.progress;

                    // Calculate opacity for this slide
                    let opacity = 0;
                    let translateY = 30;

                    if (i === 0) {
                        // First slide: already visible at start, fades out
                        if (p <= exitStart) {
                            opacity = 1;
                            translateY = 0;
                        } else if (p <= exitEnd) {
                            const fadeOut = (p - exitStart) / (exitEnd - exitStart);
                            opacity = 1 - fadeOut;
                            translateY = -30 * fadeOut;
                        }
                    } else if (i === SLIDE_COUNT - 1) {
                        // Last slide: fades in and stays
                        if (p >= enterStart && p <= enterEnd) {
                            const fadeIn = (p - enterStart) / (enterEnd - enterStart);
                            opacity = fadeIn;
                            translateY = 30 * (1 - fadeIn);
                        } else if (p > enterEnd) {
                            opacity = 1;
                            translateY = 0;
                        }
                    } else {
                        // Middle slides: fade in, stay, fade out
                        if (p >= enterStart && p <= enterEnd) {
                            const fadeIn = (p - enterStart) / (enterEnd - enterStart);
                            opacity = fadeIn;
                            translateY = 30 * (1 - fadeIn);
                        } else if (p > enterEnd && p <= exitStart) {
                            opacity = 1;
                            translateY = 0;
                        } else if (p > exitStart && p <= exitEnd) {
                            const fadeOut = (p - exitStart) / (exitEnd - exitStart);
                            opacity = 1 - fadeOut;
                            translateY = -30 * fadeOut;
                        }
                    }

                    gsap.set(slideEl, {
                        opacity,
                        y: translateY,
                    });
                },
            });
        });

        // ──────────────────────────────────────────
        // Background color transition across slides
        // ──────────────────────────────────────────
        ScrollTrigger.create({
            trigger: sectionRef.current,
            start: "top top",
            end: () => `+=${window.innerHeight * SLIDE_COUNT}`,
            scrub: true,
            onUpdate: (self) => {
                const p = self.progress;
                // Map progress to slide index and interpolate
                const slideFloat = p * (SLIDE_COUNT - 1);
                const slideIndex = Math.min(Math.floor(slideFloat), SLIDE_COUNT - 2);
                const slideFrac = slideFloat - slideIndex;

                const fromColor = SLIDES[slideIndex].bgFrom;
                const toColor = SLIDES[slideIndex].bgTo;

                if (pinnedRef.current) {
                    // Use GSAP's color interpolation
                    const interpolated = gsap.utils.interpolate(fromColor, toColor, slideFrac);
                    pinnedRef.current.style.backgroundColor = interpolated as string;
                }


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
                style={{ backgroundColor: SLIDES[0].bgFrom, overflow: "clip" }}
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
                        <div className="w-full md:w-[50%] flex flex-col items-start">
                            <span className="inline-block text-xs font-semibold tracking-[0.2em] uppercase text-gray-500 mb-4">
                                One App to Rule Them All
                            </span>
                            <h2 className="text-4xl sm:text-5xl lg:text-6xl font-bold text-gray-900 leading-[1.1] tracking-tight">
                                All your apps.
                                <br />
                                <span className="text-[#5A9BD5]">One place.</span>
                            </h2>
                            <p className="mt-6 text-lg text-gray-600 max-w-[420px] leading-relaxed">
                                Strava for runs. CalAI for meals. Fitbit for steps. Oura for sleep. You shouldn&apos;t
                                need five apps to understand one body.
                            </p>

                            {/* App pills */}
                            <div className="mt-8 flex flex-wrap gap-3 pointer-events-auto">
                                {[
                                    { icon: <FaStrava className="text-[#FC4C02]" size={16} />, name: "Strava" },
                                    { icon: <FaApple className="text-black" size={16} />, name: "Apple Health" },
                                    { icon: <FcGoogle size={16} />, name: "Health Connect" },
                                    { icon: <SiFitbit className="text-[#00B0B9]" size={16} />, name: "Fitbit" },
                                    { icon: <IoIosFitness className="text-[#FA114F]" size={16} />, name: "Oura" },
                                ].map((app) => (
                                    <div
                                        key={app.name}
                                        className="flex items-center gap-2 bg-white/70 backdrop-blur-sm border border-black/5 rounded-full px-4 py-2 text-sm font-medium text-gray-700 shadow-sm"
                                    >
                                        {app.icon}
                                        {app.name}
                                    </div>
                                ))}
                            </div>
                        </div>

                        {/* Right: Phone lives here (empty space for the 3D phone) */}
                        <div className="w-full md:w-[50%] h-[60vh]" />
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
                        <div className="w-full md:w-[50%] flex flex-col items-start">
                            <div className="text-7xl lg:text-8xl font-black text-gray-900/5 leading-none select-none mb-[-20px] lg:mb-[-30px]">
                                &ldquo;
                            </div>
                            <h2 className="text-3xl sm:text-4xl lg:text-5xl font-semibold text-gray-900 leading-[1.2] tracking-tight italic">
                                Why am I not
                                <br />
                                losing weight?
                            </h2>
                            <div className="mt-6 w-16 h-1 bg-[#E88BA7] rounded-full" />
                            <p className="mt-6 text-lg text-gray-600 max-w-[440px] leading-relaxed">
                                Other apps store data. Zuralog <span className="font-semibold text-gray-900">reasons</span> with it.
                                It cross-references your nutrition, exercise, sleep, and recovery
                                to surface answers that no single app could find alone.
                            </p>

                            {/* Insight example card */}
                            <div className="mt-8 bg-white/80 backdrop-blur-sm rounded-2xl p-5 shadow-lg border border-black/5 max-w-[440px] pointer-events-auto">
                                <div className="flex items-center gap-2 mb-3">
                                    <TbBrain className="text-[#E88BA7]" size={20} />
                                    <span className="text-xs font-semibold tracking-wide uppercase text-[#E88BA7]">
                                        AI Insight
                                    </span>
                                </div>
                                <p className="text-sm text-gray-700 leading-relaxed">
                                    &ldquo;Your CalAI data shows an avg. 2,180 cal/day, but Strava activity
                                    puts maintenance at ~1,950. You&apos;re in a 230 cal surplus. Running dropped
                                    from 8 to 3 sessions this month.&rdquo;
                                </p>
                            </div>
                        </div>

                        {/* Right: Phone space */}
                        <div className="w-full md:w-[50%] h-[60vh]" />
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
                        <div className="w-full md:w-[50%] flex flex-col items-start">
                            <span className="inline-block text-xs font-semibold tracking-[0.2em] uppercase text-gray-500 mb-4">
                                Your AI Chief of Staff
                            </span>
                            <h2 className="text-4xl sm:text-5xl lg:text-6xl font-bold text-gray-900 leading-[1.1] tracking-tight">
                                Say it.
                                <br />
                                <span className="text-[#E8A855]">It&apos;s done.</span>
                            </h2>

                            {/* Command examples */}
                            <div className="mt-10 flex flex-col gap-5 w-full max-w-[460px]">
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
                                        className="flex items-start gap-4 bg-white/60 backdrop-blur-sm rounded-xl p-4 border border-black/5 pointer-events-auto"
                                    >
                                        <div className="flex-shrink-0 w-10 h-10 rounded-lg bg-white shadow-sm flex items-center justify-center">
                                            {item.icon}
                                        </div>
                                        <div>
                                            <p className="text-sm font-semibold text-gray-900">{item.command}</p>
                                            <p className="text-sm text-gray-500 mt-0.5">{item.result}</p>
                                        </div>
                                    </div>
                                ))}
                            </div>
                        </div>

                        {/* Right: Phone space */}
                        <div className="w-full md:w-[50%] h-[60vh]" />
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
                            <MdOutlineAutoAwesome className="text-[#6BC9A0] mb-4" size={36} />
                            <h2 className="text-4xl sm:text-5xl lg:text-6xl font-bold text-gray-900 leading-[1.1] tracking-tight">
                                Knows you.
                                <br />
                                <span className="text-[#6BC9A0]">Before you ask.</span>
                            </h2>
                            <p className="mt-6 text-lg text-gray-600 max-w-[440px] leading-relaxed">
                                Zuralog isn&apos;t passive. It watches your trends, spots when things slip,
                                and speaks up. A tough-love coach that lives in your pocket.
                            </p>

                            {/* Proactive notification examples */}
                            <div className="mt-8 flex flex-col gap-3 w-full max-w-[400px]">
                                <div className="flex items-center gap-3 bg-white/70 backdrop-blur-sm rounded-full px-5 py-3 border border-black/5 shadow-sm pointer-events-auto">
                                    <TbMoon className="text-indigo-400 flex-shrink-0" size={18} />
                                    <p className="text-sm text-gray-700">
                                        <span className="font-semibold">5hr sleep detected.</span> Keep today&apos;s run in Zone 2.
                                    </p>
                                </div>
                                <div className="flex items-center gap-3 bg-white/70 backdrop-blur-sm rounded-full px-5 py-3 border border-black/5 shadow-sm pointer-events-auto">
                                    <TbRun className="text-orange-400 flex-shrink-0" size={18} />
                                    <p className="text-sm text-gray-700">
                                        <span className="font-semibold">No run in 5 days.</span> Forgetting something?
                                    </p>
                                </div>
                                <div className="flex items-center gap-3 bg-white/70 backdrop-blur-sm rounded-full px-5 py-3 border border-black/5 shadow-sm pointer-events-auto">
                                    <TbApple className="text-green-500 flex-shrink-0" size={18} />
                                    <p className="text-sm text-gray-700">
                                        <span className="font-semibold">Calories up 15%</span> vs last week. Want a plan?
                                    </p>
                                </div>
                            </div>

                            <button className="pointer-events-auto mt-10 bg-gray-900 text-white px-8 py-4 rounded-full text-lg font-semibold hover:bg-gray-800 transition-colors shadow-xl hover:shadow-2xl hover:-translate-y-0.5 transition-all">
                                Join the Waitlist
                            </button>
                        </div>

                        {/* Right: Phone space */}
                        <div className="w-full md:w-[50%] h-[60vh]" />
                    </div>
                </div>

                {/* ═══════════════════════════════════════════
                    Progress indicator dots
                    ═══════════════════════════════════════════ */}
                <div className="absolute bottom-8 left-1/2 -translate-x-1/2 z-30 flex gap-2">
                    {SLIDES.map((slide, i) => (
                        <div
                            key={slide.id}
                            className="slide-dot w-2 h-2 rounded-full bg-gray-900/20 transition-all duration-300"
                            data-dot-index={i}
                        />
                    ))}
                </div>


            </div>
        </section>
    );
}
