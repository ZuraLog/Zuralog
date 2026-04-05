"use client";

import { useRef, useEffect } from 'react';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/dist/ScrollTrigger';

if (typeof window !== 'undefined') {
    gsap.registerPlugin(ScrollTrigger);
}

// Soft vertical fade — the colour block bleeds into the surrounding dark canvas
// at the top and bottom (~18% feather on each edge), matching the reference image.
const MASK =
    'linear-gradient(to bottom, transparent 0%, black 18%, black 82%, transparent 100%)';

// 6 timeline units × 800 px per unit = 4 800 px of pinned scroll.
// Each colour holds for ~1 unit (800 px / ~1 viewport height) before crossing.
//
//   0   → 0.5   canvas hold        (starts dark, nothing visible)
//   0.5 → 1.0   → orange
//   1.0 → 2.0   orange hold
//   2.0 → 2.5   → sage
//   2.5 → 3.5   sage hold
//   3.5 → 4.0   → purple
//   4.0 → 5.0   purple hold
//   5.0 → 5.5   → yellow
//   5.5 → 6.0   yellow hold (unpin after)
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

        // Start at canvas dark — identical to the section background, so the
        // colour layer is invisible until the first transition fires.
        gsap.set(color, { backgroundColor: '#161618' });

        const tl = gsap.timeline({
            scrollTrigger: {
                trigger: section,
                pin: true,
                start: 'top top',
                end: `+=${TOTAL_SCROLL}`,
                scrub: 1,
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
            className="relative w-full bg-ds-canvas"
            style={{ height: '100vh' }}
        >
            {/* Colour overlay with soft top/bottom fade */}
            <div
                ref={colorRef}
                className="absolute inset-0"
                style={{
                    backgroundColor: '#161618',
                    maskImage: MASK,
                    WebkitMaskImage: MASK,
                }}
            />
        </section>
    );
}
