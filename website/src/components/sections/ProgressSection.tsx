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
// The overlay starts here (invisible against background) before the first colour fires.
const CREAM = '#F0EEE9';

// 6 timeline units × 800 px per unit = 4 800 px of pinned scroll.
//
//   0   → 0.5   cream hold       (overlay invisible against background)
//   0.5 → 1.0   cream → orange
//   1.0 → 2.0   orange hold
//   2.0 → 2.5   orange → sage
//   2.5 → 3.5   sage hold
//   3.5 → 4.0   sage → purple
//   4.0 → 5.0   purple hold
//   5.0 → 5.5   purple → yellow
//   5.5 → 6.0   yellow hold  (unpin after)
//
const TOTAL_SCROLL = 4800;

export function ProgressSection() {
    const sectionRef = useRef<HTMLElement>(null);
    const colorRef   = useRef<HTMLDivElement>(null);

    useEffect(() => {
        const section = sectionRef.current;
        const color   = colorRef.current;
        if (!section || !color) return;
        if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

        // Start at cream — same as the section background, so the overlay is
        // invisible until the first transition fires.
        gsap.set(color, { backgroundColor: CREAM });

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

        tl.to(color, { backgroundColor: '#FFD6A5', duration: 0.5, ease: 'none' }, 0.5) // → orange
          .to(color, { backgroundColor: '#CFE1B9', duration: 0.5, ease: 'none' }, 2.0) // → sage
          .to(color, { backgroundColor: '#E8D5F5', duration: 0.5, ease: 'none' }, 3.5) // → purple
          .to(color, { backgroundColor: '#FFF3B0', duration: 0.5, ease: 'none' }, 5.0) // → yellow
          .to({}, { duration: 0.5 }, 5.5);                                              // hold yellow

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
            {/* Colour overlay with soft top/bottom fade via CSS mask */}
            <div
                ref={colorRef}
                className="absolute inset-0"
                style={{
                    backgroundColor: CREAM,
                    maskImage: MASK,
                    WebkitMaskImage: MASK,
                }}
            />
        </section>
    );
}
