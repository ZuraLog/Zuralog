"use client";

import { useRef, useEffect } from 'react';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/dist/ScrollTrigger';

if (typeof window !== 'undefined') {
    gsap.registerPlugin(ScrollTrigger);
}

// Soft vertical fade — colour block feathers into the cream background at the
// top and bottom edges (~18 % on each side), matching the reference design.
const MASK =
    'linear-gradient(to bottom, transparent 0%, black 18%, black 82%, transparent 100%)';

// Cream — matches CoachSection and the surrounding page background.
const CREAM = '#F0EEE9';

const COLOR_LAYERS = [
    '#FFD6A5', // orange  (Streak)
    '#CFE1B9', // sage    (Goals)
    '#E8D5F5', // purple  (Journal)
    '#FFF3B0', // yellow  (Achievements)
] as const;

// 6 timeline units × 800 px per unit = 4 800 px of pinned scroll.
const TOTAL_SCROLL = 4800;

const PHASE_DURATION = 1.0; // scroll units between each layer's start
const FADE = 0.5;
const HOLD = 0.5;

export function ProgressSection() {
    const sectionRef = useRef<HTMLElement>(null);
    const layerRefs  = useRef<(HTMLDivElement | null)[]>([]);

    useEffect(() => {
        const section = sectionRef.current;
        if (!section) return;
        if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

        const tl = gsap.timeline({
            scrollTrigger: {
                trigger: section,
                pin: true,
                start: 'top top',
                end: `+=${TOTAL_SCROLL}`,
                scrub: 1,
                // ─── WHY refreshPriority: -1 ─────────────────────────────────
                // CoachSection (the section just before this one) registers its
                // GSAP pin asynchronously — it awaits the @chenglou/pretext
                // library before calling ScrollTrigger.  ProgressSection
                // registers synchronously, so without this flag its trigger
                // position is calculated before CoachSection's ~2 700 px pin
                // spacer exists, causing both sections to pin at wrong offsets.
                //
                // refreshPriority: -1 tells GSAP to refresh this trigger LAST
                // on every ScrollTrigger.refresh() call.  CoachSection keeps its
                // default priority (0), so it always settles first and its spacer
                // is in place when ProgressSection measures its own position.
                //
                // Source: https://gsap.com/resources/st-mistakes
                // "utilize the refreshPriority property to dictate the order of
                //  position calculation for specific ScrollTriggers"
                // ─────────────────────────────────────────────────────────────
                refreshPriority: -1,
            },
        });

        // Per-layer rhythm (units):  fade-in 0.5 → hold 0.5 → fade-out 0.5 (skipped on last)
        // Layer 0 (orange):  0.0 – 1.5    Layer 1 (sage): 1.0 – 2.5
        // Layer 2 (purple):  2.0 – 3.5    Layer 3 (yellow): 3.0 – 3.5 (no fade-out)
        COLOR_LAYERS.forEach((_, i) => {
            const el = layerRefs.current[i];
            if (!el) return;
            const start = i * PHASE_DURATION;
            tl.to(el, { opacity: 1, duration: FADE, ease: 'none' }, start);
            if (i < COLOR_LAYERS.length - 1) {
                tl.to(el, { opacity: 0, duration: FADE, ease: 'none' }, start + FADE + HOLD);
            }
        });

        // End spacer — derived explicitly so it stays correct if constants change.
        // Last layer: fade-in ends at start + FADE + HOLD (it has no fade-out).
        const lastStart = (COLOR_LAYERS.length - 1) * PHASE_DURATION;
        const timelineEnd = lastStart + FADE + HOLD;
        tl.to({}, { duration: FADE }, timelineEnd);

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
            style={{ height: '100vh', backgroundColor: CREAM }}
        >
            {COLOR_LAYERS.map((color, i) => (
                <div
                    key={i}
                    ref={el => { layerRefs.current[i] = el; }}
                    className="absolute inset-0"
                    style={{
                        backgroundColor: color,
                        opacity: 0,
                        maskImage: MASK,
                        WebkitMaskImage: MASK,
                    }}
                />
            ))}
        </section>
    );
}
