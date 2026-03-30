"use client";

import { useEffect, useRef } from 'react';
import gsap from 'gsap';

/**
 * HeroText — Premium dark redesign
 *
 * Dark canvas styling:
 * - Badge: subtle dark border with Sage accent dot
 * - Headline: animated topographic pattern fill (background-clip: text)
 *   synchronized with the section's topo-drift keyframe
 * - Subheadline: Text Primary #F0EEE9
 * - CTA: Sage-filled pill button with glow shadow
 */
export function HeroText() {
    const containerRef = useRef<HTMLDivElement>(null);

    useEffect(() => {
        let handleMouseMove: (e: MouseEvent) => void;

        const ctx = gsap.context(() => {
            const tl = gsap.timeline({ defaults: { ease: 'power3.out', duration: 1 } });

            tl.fromTo('.badge', { opacity: 0, y: -15 }, { opacity: 1, y: 0 }, 0.2)
                .fromTo('.hero-line', { opacity: 0, y: 30 }, { opacity: 1, y: 0, stagger: 0.15 }, 0.3)
                .fromTo('.hero-cta', { opacity: 0, scale: 0.9 }, { opacity: 1, scale: 1 }, 0.8);

            handleMouseMove = (e: MouseEvent) => {
                const mx = (e.clientX / window.innerWidth - 0.5) * 2;
                const my = (e.clientY / window.innerHeight - 0.5) * 2;

                gsap.to('.hero-parallax', {
                    x: mx * 25,
                    y: my * 25,
                    duration: 1.5,
                    ease: 'power2.out'
                });
            };
            if (!window.matchMedia('(max-width: 767px)').matches) {
                window.addEventListener('mousemove', handleMouseMove);
            }
        }, containerRef);

        return () => {
            if (handleMouseMove) window.removeEventListener('mousemove', handleMouseMove);
            ctx.revert();
        };
    }, []);

    return (
        <div
            ref={containerRef}
            className="absolute inset-0 flex flex-col items-center justify-center z-30 pointer-events-none"
        >
            <div className="hero-parallax flex flex-col items-center mt-10 md:mt-20">
                {/* Badge — dark glass style */}
                <div className="badge pointer-events-auto flex items-center gap-2 border border-[rgba(207,225,185,0.2)] rounded-full px-4 py-1.5 mb-8 bg-[rgba(30,30,32,0.6)] backdrop-blur-sm">
                    <div className="w-2 h-2 bg-[#CFE1B9] rounded-full animate-pulse" />
                    <span className="text-sm font-medium text-[#9B9894]">The future of wellbeing</span>
                </div>

                {/* Headline — animated topographic pattern fill */}
                <h1
                    className="text-center font-sans pointer-events-auto max-w-[900px] px-4 md:px-0 font-bold"
                    style={{ fontFamily: 'var(--font-jakarta, var(--font-sans))' }}
                >
                    <div className="hero-line text-4xl sm:text-5xl md:text-7xl lg:text-8xl tracking-tight mb-2 leading-none">
                        <span className="text-topo-pattern">Unified Health.</span>
                    </div>
                    <div className="hero-line text-4xl sm:text-5xl md:text-7xl lg:text-8xl tracking-tight leading-none">
                        <span className="text-topo-pattern">Made Smart.</span>
                    </div>
                </h1>

                {/* Subheadline */}
                <p className="hero-line text-base md:text-xl text-[#9B9894] mt-6 max-w-[500px] text-center pointer-events-auto px-4 md:px-0">
                    Bring all your fitness data into one brilliant interface.
                </p>

                {/* CTA button — Sage + glow */}
                <button
                    className="hero-cta pointer-events-auto mt-8 md:mt-12 btn-pattern-light bg-[#CFE1B9] text-[#141E18] px-6 py-3 md:px-8 md:py-4 rounded-full text-base md:text-lg font-semibold transition-all duration-300 shadow-[0_4px_20px_rgba(207,225,185,0.35)] hover:scale-[1.04] hover:shadow-[0_6px_35px_rgba(207,225,185,0.5)] active:scale-[0.97]"
                    onClick={() => document.getElementById("waitlist")?.scrollIntoView({ behavior: "smooth" })}
                >
                    <span className="relative z-10">Waitlist Now</span>
                </button>
            </div>
        </div>
    );
}
