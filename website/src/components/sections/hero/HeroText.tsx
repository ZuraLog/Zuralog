"use client";

import { useEffect, useRef } from 'react';
import gsap from 'gsap';

export function HeroText() {
    const containerRef = useRef<HTMLDivElement>(null);

    useEffect(() => {
        let handleMouseMove: (e: MouseEvent) => void;

        const ctx = gsap.context(() => {
            // Timeline for entrance animations
            const tl = gsap.timeline({ defaults: { ease: 'power3.out', duration: 1 } });

            tl.fromTo('.badge', { opacity: 0, y: -15 }, { opacity: 1, y: 0 }, 0.2)
                .fromTo('.hero-line', { opacity: 0, y: 30 }, { opacity: 1, y: 0, stagger: 0.15 }, 0.3)
                .fromTo('.hero-cta', { opacity: 0, scale: 0.9 }, { opacity: 1, scale: 1 }, 0.8);

            // Mouse parallax configuration
            handleMouseMove = (e: MouseEvent) => {
                const mx = (e.clientX / window.innerWidth - 0.5) * 2;
                const my = (e.clientY / window.innerHeight - 0.5) * 2;

                gsap.to('.hero-parallax', {
                    x: mx * 25, // Move with mouse
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
        <div ref={containerRef} className="absolute inset-0 flex flex-col items-center justify-center z-30 pointer-events-none">
            <div className="hero-parallax flex flex-col items-center mt-10 md:mt-20">
                <div className="badge pointer-events-auto flex items-center gap-2 border border-black/10 rounded-full px-4 py-1.5 mb-8 bg-white/50 backdrop-blur-sm shadow-sm">
                    <div className="w-2 h-2 bg-[#CFE1B9] rounded-full animate-pulse" />
                    <span className="text-sm font-medium text-black/70">The future of wellbeing</span>
                </div>

                <h1 className="text-center text-dark-charcoal font-sans pointer-events-auto max-w-[900px] px-4 md:px-0">
                    <div className="hero-line text-4xl sm:text-5xl md:text-7xl lg:text-8xl tracking-tight mb-2">
                        Unified <span className="text-[#CFE1B9]">Health.</span>
                    </div>
                    <div className="hero-line text-4xl sm:text-5xl md:text-7xl lg:text-8xl font-bold tracking-tight">
                        Made <span className="text-[#CFE1B9]">Smart.</span>
                    </div>
                </h1>

                <p className="hero-line text-base md:text-xl text-black mt-6 max-w-[500px] text-center pointer-events-auto px-4 md:px-0">
                    Bring all your fitness data into one brilliant interface.
                </p>

                <button
                    className="hero-cta pointer-events-auto mt-8 md:mt-12 bg-dark-charcoal text-white px-6 py-3 md:px-8 md:py-4 rounded-full text-base md:text-lg font-semibold hover:bg-black transition-colors shadow-xl"
                    onClick={() => document.getElementById("waitlist")?.scrollIntoView({ behavior: "smooth" })}
                >
                    Waitlist Now
                </button>
            </div>
        </div>
    );
}
