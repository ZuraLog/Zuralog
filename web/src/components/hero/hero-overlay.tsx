/**
 * HeroOverlay — HTML/CSS/SVG overlay layers for the hero 3D scene.
 *
 * Split into two components for correct z-ordering relative to the phone:
 *
 *   HeroOverlayBehind — convergence lines ONLY, placed at z-[5] in hero.tsx
 *                        (BEHIND the Three.js canvas at z-10). Lines appear to
 *                        flow toward the phone and disappear behind it, matching
 *                        the reference wireframe.
 *
 *   HeroOverlayFront  — floating UI graphics + integration cards, placed at
 *                        z-[15] (IN FRONT of phone canvas). Graphics overlap
 *                        the phone edges; integration cards float at periphery.
 *
 * Both components share the same mouse parallax singleton via useOverlayState().
 * The singleton tick is started once; RAF loops are trivially cheap (reads 2 floats).
 */
"use client";

import { useEffect, useRef, useState } from "react";
import { useMouseParallax, getMouseParallax } from "@/hooks/use-mouse-parallax";
import { IntegrationCards } from "./integration-cards";
import { FloatingGraphics } from "./floating-graphics";
import { ConvergenceLines } from "./convergence-lines";

/** Breakpoint below which we switch to a mobile-optimised layout */
const MOBILE_BREAKPOINT = 768;

/* ─── Shared state hook ──────────────────────────────────────────────── */

/**
 * useOverlayState — shared logic for both overlay components.
 *
 * Bootstraps the mouse parallax singleton, detects viewport size,
 * honours prefers-reduced-motion, and provides smoothed mouse state
 * via a lightweight RAF loop reading from the singleton.
 */
function useOverlayState() {
  // Bootstrap the singleton RAF tick so hero-scene.tsx's getMouseParallax() works
  useMouseParallax();

  const [mouse, setMouse] = useState({ x: 0, y: 0 });
  const [isMobile, setIsMobile] = useState(false);
  const [reducedMotion, setReducedMotion] = useState(
    () =>
      typeof window !== "undefined" &&
      window.matchMedia("(prefers-reduced-motion: reduce)").matches,
  );
  const rafRef = useRef<number | null>(null);
  const reducedMotionRef = useRef(false);

  useEffect(() => {
    const mq = window.matchMedia("(prefers-reduced-motion: reduce)");
    reducedMotionRef.current = reducedMotion;
    const handler = (e: MediaQueryListEvent) => setReducedMotion(e.matches);
    mq.addEventListener("change", handler);
    return () => mq.removeEventListener("change", handler);
  }, [reducedMotion]);

  useEffect(() => {
    const check = () => setIsMobile(window.innerWidth < MOBILE_BREAKPOINT);
    check();
    window.addEventListener("resize", check, { passive: true });
    return () => window.removeEventListener("resize", check);
  }, []);

  useEffect(() => {
    let last = { x: 0, y: 0 };
    const loop = () => {
      const pos = getMouseParallax();
      const x = reducedMotionRef.current ? 0 : pos.x;
      const y = reducedMotionRef.current ? 0 : pos.y;
      if (Math.abs(x - last.x) > 0.001 || Math.abs(y - last.y) > 0.001) {
        last = { x, y };
        setMouse({ x, y });
      }
      rafRef.current = requestAnimationFrame(loop);
    };
    rafRef.current = requestAnimationFrame(loop);
    return () => {
      if (rafRef.current !== null) cancelAnimationFrame(rafRef.current);
    };
  }, []);

  return { mouse, isMobile, reducedMotion };
}

/* ─── HeroOverlayBehind ─────────────────────────────────────────────── */

/**
 * HeroOverlayBehind — convergence lines only, rendered BEHIND the phone.
 *
 * Place at z-[5] in hero.tsx so lines appear behind the z-10 phone canvas.
 * The lines flow from integration cards toward the phone and vanish behind it.
 */
export function HeroOverlayBehind() {
  const { mouse, isMobile, reducedMotion } = useOverlayState();

  return (
    <div className="pointer-events-none absolute inset-0 overflow-hidden" aria-hidden="true">
      <ConvergenceLines
        mouseX={mouse.x}
        mouseY={mouse.y}
        isMobile={isMobile}
        reducedMotion={reducedMotion}
      />
    </div>
  );
}

/* ─── HeroOverlayFront ──────────────────────────────────────────────── */

/**
 * HeroOverlayFront — floating UI graphics + integration cards, in front of phone.
 *
 * Place at z-[15] in hero.tsx so elements appear in front of the z-10 phone canvas.
 * Floating graphics overlap the phone edges; integration cards orbit the periphery.
 */
export function HeroOverlayFront() {
  const { mouse, isMobile, reducedMotion } = useOverlayState();

  return (
    <div className="pointer-events-none absolute inset-0 overflow-hidden" aria-hidden="true">
      {/* Floating ZuraLog UI graphic elements (HRV ring, charts, AI coach, metrics) */}
      <FloatingGraphics
        mouseX={mouse.x}
        mouseY={mouse.y}
        isMobile={isMobile}
        reducedMotion={reducedMotion}
      />

      {/* Glassmorphic integration brand cards at periphery */}
      <IntegrationCards
        mouseX={mouse.x}
        mouseY={mouse.y}
        isMobile={isMobile}
        reducedMotion={reducedMotion}
      />
    </div>
  );
}

/* ─── Legacy export ─────────────────────────────────────────────────── */

/**
 * HeroOverlay — original single-layer orchestrator (all elements in one div).
 *
 * @deprecated Use HeroOverlayBehind + HeroOverlayFront for correct z-ordering.
 */
export function HeroOverlay() {
  const { mouse, isMobile, reducedMotion } = useOverlayState();

  return (
    <div className="pointer-events-none absolute inset-0 overflow-hidden" aria-hidden="true">
      <ConvergenceLines
        mouseX={mouse.x}
        mouseY={mouse.y}
        isMobile={isMobile}
        reducedMotion={reducedMotion}
      />
      <FloatingGraphics
        mouseX={mouse.x}
        mouseY={mouse.y}
        isMobile={isMobile}
        reducedMotion={reducedMotion}
      />
      <IntegrationCards
        mouseX={mouse.x}
        mouseY={mouse.y}
        isMobile={isMobile}
        reducedMotion={reducedMotion}
      />
    </div>
  );
}
