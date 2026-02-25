"use client";

/**
 * LenisProvider — initialises Lenis smooth scroll and wires it as the
 * scroll proxy for GSAP ScrollTrigger so both systems share one source
 * of truth. Without this proxy, GSAP uses raw window.scrollY while Lenis
 * uses a virtual position, causing jumpy behaviour at section boundaries.
 *
 * Must wrap the entire page so all ScrollTrigger instances created in
 * child components inherit the Lenis scroll position.
 */

import { useEffect, useRef } from "react";
import Lenis from "lenis";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";

gsap.registerPlugin(ScrollTrigger);

interface LenisProviderProps {
    children: React.ReactNode;
}

export function LenisProvider({ children }: LenisProviderProps) {
    const lenisRef = useRef<Lenis | null>(null);

    useEffect(() => {
        const lenis = new Lenis({
            duration: 1.2,
            easing: (t) => Math.min(1, 1.001 - Math.pow(2, -10 * t)),
            smoothWheel: true,
            // Disable touch smoothing — native feel on mobile is better
            // and avoids fighting with GSAP pin on touch devices
            touchMultiplier: 0,
        });

        lenisRef.current = lenis;

        // Wire Lenis as the GSAP ScrollTrigger scroll proxy.
        // This means every ScrollTrigger reads lenis.scroll instead of
        // window.scrollY — they are now the same virtual position.
        lenis.on("scroll", ScrollTrigger.update);

        // Drive Lenis from GSAP's RAF ticker so both run in the same frame.
        gsap.ticker.add((time) => {
            lenis.raf(time * 1000);
        });

        // Disable GSAP's own lagSmoothing — Lenis handles this instead.
        gsap.ticker.lagSmoothing(0);

        return () => {
            gsap.ticker.remove((time) => lenis.raf(time * 1000));
            lenis.destroy();
            lenisRef.current = null;
        };
    }, []);

    return <>{children}</>;
}
