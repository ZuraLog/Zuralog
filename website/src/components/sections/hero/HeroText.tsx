"use client";

import { useEffect, useRef } from 'react';
import gsap from 'gsap';

export function HeroText() {
    const containerRef = useRef<HTMLDivElement>(null);

    useEffect(() => {
        const ctx = gsap.context(() => {
            // Timeline for entrance animations
            const tl = gsap.timeline({ defaults: { ease: 'power3.out', duration: 1 } });

            tl.fromTo('.badge', { opacity: 0, y: -15 }, { opacity: 1, y: 0 }, 0.2)
                .fromTo('.hero-line', { opacity: 0, y: 30 }, { opacity: 1, y: 0, stagger: 0.15 }, 0.3)
                .fromTo('.hero-cta', { opacity: 0, scale: 0.9 }, { opacity: 1, scale: 1 }, 0.8);
        }, containerRef);

        return () => ctx.revert();
    }, []);

    return (
        <div ref={containerRef} className="absolute inset-0 flex flex-col items-center justify-center z-10 pointer-events-none">
            <div className="badge pointer-events-auto flex items-center gap-2 border border-black/10 rounded-full px-4 py-1.5 mb-8 bg-white/50 backdrop-blur-sm">
                <div className="w-4 h-4 rounded-full border border-black/20 flex items-center justify-center">
                    <div className="w-1.5 h-1.5 bg-black rounded-full" />
                </div>
                <span className="text-sm font-medium text-black/70">special offer for early birds</span>
            </div>

            <h1 className="text-center text-dark-charcoal font-sans pointer-events-auto">
                <div className="hero-line text-6xl md:text-7xl lg:text-8xl tracking-tight mb-2">
                    Unified Health.
                </div>
                <div className="hero-line text-6xl md:text-7xl lg:text-8xl font-bold tracking-tight">
                    Made Smart.
                </div>
            </h1>

            <button className="hero-cta pointer-events-auto mt-12 bg-dark-charcoal text-white px-8 py-4 rounded-full text-lg font-semibold hover:-translate-y-1 transition-transform shadow-xl">
                Start Now
            </button>
        </div>
    );
}
