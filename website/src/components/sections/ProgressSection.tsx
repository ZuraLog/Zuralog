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

// Section is 500vh tall. CSS sticky keeps the visual at 100vh.
// Effective scroll range = 500vh − 100vh = 400vh (from top-top to bottom-bottom).
// With a timeline of 5 units → each unit ≈ 80vh of scroll.
//
//   0   → 1.0  Streak  (orange) — hold   (~80vh)
//   1.0 → 1.5  → Goals (sage)   — cross  (~40vh)
//   1.5 → 2.5  Goals   (sage)   — hold   (~80vh)
//   2.5 → 3.0  → Journal (purple)— cross (~40vh)
//   3.0 → 4.0  Journal (purple) — hold   (~80vh)
//   4.0 → 4.5  → Achievements   — cross  (~40vh)
//   4.5 → 5.0  Achievements     — hold   (~40vh)
//
const SECTION_HEIGHT = '500vh';

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

        // ── Master timeline ─────────────────────────────────────────────────
        // NOTE: No GSAP pin here. The 100vh visible area is held by CSS
        // `position: sticky` on the inner div. This avoids conflicts with
        // CoachSection's asynchronous GSAP pin registration.
        const tl = gsap.timeline({
            scrollTrigger: {
                trigger: section,
                start: 'top top',
                end: 'bottom bottom',
                scrub: 1,
            },
        });

        // Background colour transitions
        tl.to(bg, { backgroundColor: PHASES[1].color, duration: 0.5, ease: 'none' }, 1.0)
          .to(bg, { backgroundColor: PHASES[2].color, duration: 0.5, ease: 'none' }, 2.5)
          .to(bg, { backgroundColor: PHASES[3].color, duration: 0.5, ease: 'none' }, 4.0)
          .to({}, { duration: 0.5 }, 4.5); // hold yellow before section ends

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
            className="relative w-full"
            style={{ height: SECTION_HEIGHT }}
            // NOTE: Do NOT add overflow:hidden here — it breaks position:sticky.
        >
            {/* ── Sticky visible panel (stays at viewport top while section scrolls) ── */}
            <div
                className="sticky top-0 w-full overflow-hidden"
                style={{ height: '100vh' }}
            >
                {/* ── Colour background ── */}
                <div
                    ref={bgRef}
                    className="absolute inset-0"
                    style={{ backgroundColor: PHASES[0].color }}
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
                {/* All 4 labels occupy the same position; only one is visible at a time. */}
                <div
                    className="absolute"
                    style={{ bottom: '52px', left: 0, right: 0, zIndex: 10 }}
                >
                    {PHASES.map((phase, i) => (
                        <div
                            key={phase.key}
                            ref={(el: HTMLDivElement | null) => { labelRefs.current[i] = el; }}
                            className="absolute font-jakarta font-extrabold"
                            style={{
                                left: '50%',
                                transform: 'translateX(-50%)',
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
            </div>
        </section>
    );
}
