/**
 * HeroOverlay — HTML/CSS/SVG overlay layer for the hero 3D scene.
 *
 * Composes three sub-layers (back → front):
 *   1. ConvergenceLines  — animated SVG bezier paths from each integration to phone center
 *   2. FloatingGraphics  — decorative ZuraLog UI elements (charts, pills, chat bubbles)
 *   3. IntegrationCards  — glassmorphic floating brand cards
 *
 * Reads the shared mouse parallax singleton reactively via a RAF loop so that
 * all three children receive the same smoothed mouse values every frame without
 * adding extra event listeners or React re-renders beyond the RAF tick.
 *
 * Responsibilities:
 *   - Bootstrap the singleton by calling `useMouseParallax()` (required for the
 *     RAF tick to start — hero-scene.tsx uses `getMouseParallax()` directly)
 *   - Detect mobile viewport (≤768 px) and pass `isMobile` to children
 *   - Honour `prefers-reduced-motion` by freezing parallax at zero when set
 */
"use client";

import { useEffect, useRef, useState } from "react";
import { useMouseParallax, getMouseParallax } from "@/hooks/use-mouse-parallax";
import { IntegrationCards } from "./integration-cards";
import { FloatingGraphics } from "./floating-graphics";
import { ConvergenceLines } from "./convergence-lines";

/** Breakpoint below which we switch to a mobile-optimised layout */
const MOBILE_BREAKPOINT = 768;

/**
 * HeroOverlay renders the composite HTML/SVG overlay sitting between the
 * Three.js canvas and the hero text content.
 *
 * It owns the mouse parallax subscription and distributes the current
 * smoothed position to all child components each frame.
 */
export function HeroOverlay() {
  // Bootstrap the singleton RAF tick — required so that hero-scene.tsx's
  // getMouseParallax() escape hatch returns live values.
  useMouseParallax();

  const [mouse, setMouse] = useState({ x: 0, y: 0 });
  const [isMobile, setIsMobile] = useState(false);
  const rafRef = useRef<number | null>(null);

  // Detect `prefers-reduced-motion` once on mount
  const reducedMotion = useRef(false);

  useEffect(() => {
    const mq = window.matchMedia("(prefers-reduced-motion: reduce)");
    reducedMotion.current = mq.matches;
    const handler = (e: MediaQueryListEvent) => {
      reducedMotion.current = e.matches;
    };
    mq.addEventListener("change", handler);
    return () => mq.removeEventListener("change", handler);
  }, []);

  // Viewport width detection
  useEffect(() => {
    const check = () => setIsMobile(window.innerWidth < MOBILE_BREAKPOINT);
    check();
    window.addEventListener("resize", check, { passive: true });
    return () => window.removeEventListener("resize", check);
  }, []);

  // RAF loop that copies the singleton smoothed values into React state.
  // Running at rAF frequency (~60 fps) is intentional — these are CSS transforms,
  // not layout — the browser batches them efficiently.
  useEffect(() => {
    let last = { x: 0, y: 0 };
    const loop = () => {
      const pos = getMouseParallax();
      const x = reducedMotion.current ? 0 : pos.x;
      const y = reducedMotion.current ? 0 : pos.y;
      // Only trigger a re-render if values changed meaningfully (> 0.001)
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

  return (
    <div className="pointer-events-none absolute inset-0 overflow-hidden" aria-hidden="true">
      {/* Layer 1 (back): animated SVG convergence lines */}
      <ConvergenceLines mouseX={mouse.x} mouseY={mouse.y} isMobile={isMobile} />

      {/* Layer 2 (mid): floating ZuraLog UI graphic elements */}
      <FloatingGraphics mouseX={mouse.x} mouseY={mouse.y} isMobile={isMobile} />

      {/* Layer 3 (front): glassmorphic integration brand cards */}
      <IntegrationCards mouseX={mouse.x} mouseY={mouse.y} isMobile={isMobile} />
    </div>
  );
}
