"use client";

import { useEffect, useRef, useCallback } from "react";

/**
 * SpotlightFollow — a radial gradient that follows the mouse cursor,
 * giving the page a subtle "flashlight" feel. Skipped entirely on
 * touch devices where there is no persistent pointer.
 */
export function SpotlightFollow() {
  const spotRef = useRef<HTMLDivElement>(null);
  const rafId = useRef(0);
  const mouse = useRef({ x: 0, y: 0 });

  const onMove = useCallback((e: MouseEvent) => {
    mouse.current = { x: e.clientX, y: e.clientY };
  }, []);

  useEffect(() => {
    // Only run on devices with a precise pointer (mouse / trackpad)
    if (!window.matchMedia("(pointer: fine)").matches) return;

    document.addEventListener("mousemove", onMove);

    const tick = () => {
      if (spotRef.current) {
        spotRef.current.style.background = `radial-gradient(300px circle at ${mouse.current.x}px ${mouse.current.y}px, rgba(207,225,185,0.04), transparent 70%)`;
      }
      rafId.current = requestAnimationFrame(tick);
    };
    rafId.current = requestAnimationFrame(tick);

    return () => {
      cancelAnimationFrame(rafId.current);
      document.removeEventListener("mousemove", onMove);
    };
  }, [onMove]);

  return (
    <div
      ref={spotRef}
      className="fixed inset-0 -z-10 pointer-events-none"
      aria-hidden="true"
    />
  );
}
