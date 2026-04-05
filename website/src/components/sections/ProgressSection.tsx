"use client";

import { useRef, useEffect } from 'react';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/dist/ScrollTrigger';

if (typeof window !== 'undefined') {
    gsap.registerPlugin(ScrollTrigger);
}

const PHASES = [
    { color: '#FFD6A5' },  // Streak  — orange pastel
    { color: '#CFE1B9' },  // Goals   — sage pastel
    { color: '#E8D5F5' },  // Journal — purple pastel
    { color: '#FFF3B0' },  // Achievements — yellow pastel
];

// Soft vertical fade — transparent at very top and bottom, solid in the middle.
// Mirrors the reference image: ~20% feather on each edge.
const MASK =
    'linear-gradient(to bottom, transparent 0%, black 18%, black 82%, transparent 100%)';

export function ProgressSection() {
    const sectionRef = useRef<HTMLElement>(null);
    const colorRef   = useRef<HTMLDivElement>(null);

    useEffect(() => {
        const section = sectionRef.current;
        const color   = colorRef.current;
        if (!section || !color) return;
        if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

        gsap.set(color, { backgroundColor: PHASES[0].color });

        // Scroll from orange → sage → purple → yellow as the user scrolls
        // through the 500vh section (top-top to bottom-bottom = 400vh of travel).
        // Timeline = 5 units → 1 unit ≈ 80vh of scroll.
        //
        //   0   → 1.0  orange hold   (~80vh)
        //   1.0 → 1.5  → sage        (~40vh)
        //   1.5 → 2.5  sage hold     (~80vh)
        //   2.5 → 3.0  → purple      (~40vh)
        //   3.0 → 4.0  purple hold   (~80vh)
        //   4.0 → 4.5  → yellow      (~40vh)
        //   4.5 → 5.0  yellow hold   (~40vh)
        const tl = gsap.timeline({
            scrollTrigger: {
                trigger: section,
                start: 'top top',
                end: 'bottom bottom',
                scrub: 1,
            },
        });

        tl.to(color, { backgroundColor: PHASES[1].color, duration: 0.5, ease: 'none' }, 1.0)
          .to(color, { backgroundColor: PHASES[2].color, duration: 0.5, ease: 'none' }, 2.5)
          .to(color, { backgroundColor: PHASES[3].color, duration: 0.5, ease: 'none' }, 4.0)
          .to({}, { duration: 0.5 }, 4.5);

        return () => {
            tl.scrollTrigger?.kill();
            tl.kill();
        };
    }, []);

    return (
        // 500vh tall so scrolling through it drives the color transitions.
        // No overflow:hidden here — it breaks position:sticky in Safari/Chrome.
        <section
            ref={sectionRef}
            id="progress-section"
            className="relative w-full"
            style={{ height: '500vh' }}
        >
            {/* Sticky panel holds the visual at 100vh while the section scrolls */}
            <div
                className="sticky top-0 w-full"
                style={{ height: '100vh', overflow: 'hidden' }}
            >
                {/* Layer 1: warm-white base — matches surrounding sections */}
                <div className="absolute inset-0 bg-[#F0EEE9]" />

                {/* Layer 2: phase color with soft top/bottom fade */}
                <div
                    ref={colorRef}
                    className="absolute inset-0"
                    style={{
                        backgroundColor: PHASES[0].color,
                        maskImage: MASK,
                        WebkitMaskImage: MASK,
                    }}
                />
            </div>
        </section>
    );
}
