"use client";

import { useRef, useEffect } from 'react';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/dist/ScrollTrigger';

if (typeof window !== 'undefined') {
    gsap.registerPlugin(ScrollTrigger);
}

// Pastel palette — each derived from the brand's health-category color for that concept.
// Streak Warm #FF9500 → pastel #FFD6A5
// Brand Sage  #CFE1B9 → used directly (already pastel)
// Wellness    #BF5AF2 → pastel #E8D5F5
// Mobility    #FFD60A → pastel #FFF3B0
const PHASES = [
    { key: 'streak',       label: 'Streak',        color: '#FFD6A5' },
    { key: 'goals',        label: 'Goals',         color: '#CFE1B9' },
    { key: 'journal',      label: 'Journal',       color: '#E8D5F5' },
    { key: 'achievements', label: 'Achievements',  color: '#FFF3B0' },
];

// Total pinned scroll distance in px.
// 1 000 px per phase — 4 phases — gives a comfortable hold before each transition.
const TOTAL_SCROLL = 4000;

export function ProgressSection() {
    const sectionRef  = useRef<HTMLElement>(null);
    const bgRef       = useRef<HTMLDivElement>(null);
    const labelRefs   = useRef<(HTMLDivElement | null)[]>([]);

    useEffect(() => {
        const section = sectionRef.current;
        const bg      = bgRef.current;
        if (!section || !bg) return;
        if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

        // ── Starting state ──────────────────────────────────────────────────
        gsap.set(bg, { backgroundColor: PHASES[0].color });
        labelRefs.current.forEach((el, i) => {
            if (el) gsap.set(el, { opacity: i === 0 ? 1 : 0 });
        });

        // ── Master timeline — drives both bg color and label swaps ──────────
        // Timeline has 5 units of duration → each maps to 800 px of scroll.
        //
        //   0.0 → 1.0  Streak  (orange)   — hold
        //   1.0 → 1.5  transition → Goals (sage)
        //   1.5 → 2.5  Goals   (sage)     — hold
        //   2.5 → 3.0  transition → Journal (purple)
        //   3.0 → 4.0  Journal (purple)   — hold
        //   4.0 → 4.5  transition → Achievements (yellow)
        //   4.5 → 5.0  Achievements (yellow) — hold
        //
        const tl = gsap.timeline({
            scrollTrigger: {
                trigger: section,
                pin: true,
                start: 'top top',
                end: `+=${TOTAL_SCROLL}`,
                scrub: 1,
            },
        });

        // Background colour transitions
        tl.to(bg, { backgroundColor: PHASES[1].color, duration: 0.5, ease: 'none' }, 1.0)
          .to(bg, { backgroundColor: PHASES[2].color, duration: 0.5, ease: 'none' }, 2.5)
          .to(bg, { backgroundColor: PHASES[3].color, duration: 0.5, ease: 'none' }, 4.0)
          .to({}, { duration: 0.5 }, 4.5); // hold yellow before unpin

        // Label fade — each old label fades out just before the colour crosses,
        // the next fades in just after.
        const [l0, l1, l2, l3] = labelRefs.current;

        if (l0) tl.to(l0, { opacity: 0, duration: 0.25, ease: 'none' }, 0.9);
        if (l1) tl.fromTo(l1, { opacity: 0 }, { opacity: 1, duration: 0.25, ease: 'none' }, 1.2);
        if (l1) tl.to(l1, { opacity: 0, duration: 0.25, ease: 'none' }, 2.4);
        if (l2) tl.fromTo(l2, { opacity: 0 }, { opacity: 1, duration: 0.25, ease: 'none' }, 2.7);
        if (l2) tl.to(l2, { opacity: 0, duration: 0.25, ease: 'none' }, 3.9);
        if (l3) tl.fromTo(l3, { opacity: 0 }, { opacity: 1, duration: 0.25, ease: 'none' }, 4.2);

        return () => {
            tl.scrollTrigger?.kill();
            tl.kill();
        };
    }, []);

    return (
        <section
            ref={sectionRef}
            id="progress-section"
            className="relative w-full overflow-hidden"
            style={{ height: '100vh' }}
        >
            {/* ── Colour background ── */}
            <div
                ref={bgRef}
                className="absolute inset-0"
                style={{ backgroundColor: PHASES[0].color, transition: 'none' }}
            />

            {/* ── Section identifier — top left ── */}
            <div
                className="absolute flex items-center gap-3"
                style={{ top: '64px', left: '96px', zIndex: 10 }}
            >
                <span
                    className="block"
                    style={{ width: '28px', height: '1px', backgroundColor: '#344E41', opacity: 0.5 }}
                />
                <span
                    className="font-jakarta font-semibold"
                    style={{
                        fontSize: '11px',
                        letterSpacing: '0.13em',
                        textTransform: 'uppercase',
                        color: '#6B6864',
                    }}
                >
                    Progress Tab
                </span>
            </div>

            {/* ── Phase labels — bottom centre ── */}
            {/* Positioned below the landscape phone, which sits in the vertical middle */}
            <div
                className="absolute left-0 right-0 flex justify-center"
                style={{ bottom: '52px', zIndex: 10 }}
            >
                {PHASES.map((phase, i) => (
                    <div
                        key={phase.key}
                        ref={(el: HTMLDivElement | null) => { labelRefs.current[i] = el; }}
                        className="absolute font-jakarta font-extrabold"
                        style={{
                            fontSize: 'clamp(40px, 5vw, 76px)',
                            letterSpacing: '-0.04em',
                            color: '#1A2E22',
                            opacity: i === 0 ? 1 : 0,
                            whiteSpace: 'nowrap',
                        }}
                    >
                        {phase.label}
                    </div>
                ))}
            </div>
        </section>
    );
}
