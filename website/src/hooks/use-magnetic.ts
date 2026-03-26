"use client";

import { useEffect, useRef } from "react";
import gsap from "gsap";

interface MagneticOptions {
  /** How close the cursor must be to start pulling (default 50px) */
  distance?: number;
  /** Maximum pixel shift toward the cursor (default 3px) */
  strength?: number;
}

/**
 * Makes an element magnetically attract toward the cursor
 * when the pointer gets close. Springs back when the pointer leaves.
 *
 * Usage:
 *   const magnetRef = useMagnetic({ distance: 60, strength: 4 });
 *   <button ref={magnetRef}>Click me</button>
 */
export function useMagnetic<T extends HTMLElement = HTMLElement>(
  options?: MagneticOptions,
) {
  const ref = useRef<T>(null);
  const rafId = useRef(0);
  const dist = options?.distance ?? 50;
  const str = options?.strength ?? 3;

  useEffect(() => {
    const el = ref.current;
    if (!el) return;

    // Skip on touch devices
    if (typeof window !== "undefined" && !window.matchMedia("(pointer: fine)").matches) {
      return;
    }

    const onMove = (e: MouseEvent) => {
      cancelAnimationFrame(rafId.current);
      rafId.current = requestAnimationFrame(() => {
        const rect = el.getBoundingClientRect();
        const cx = rect.left + rect.width / 2;
        const cy = rect.top + rect.height / 2;
        const dx = e.clientX - cx;
        const dy = e.clientY - cy;
        const distance = Math.sqrt(dx * dx + dy * dy);

        if (distance < dist) {
          // Normalize so the shift is proportional to closeness
          const factor = (1 - distance / dist) * str;
          gsap.to(el, {
            x: (dx / distance) * factor,
            y: (dy / distance) * factor,
            duration: 0.3,
            ease: "power2.out",
            overwrite: "auto",
          });
        }
      });
    };

    const onLeave = () => {
      cancelAnimationFrame(rafId.current);
      gsap.to(el, {
        x: 0,
        y: 0,
        duration: 0.6,
        ease: "elastic.out(1, 0.4)",
        overwrite: "auto",
      });
    };

    el.addEventListener("mousemove", onMove, { passive: true });
    el.addEventListener("mouseleave", onLeave, { passive: true });

    return () => {
      cancelAnimationFrame(rafId.current);
      el.removeEventListener("mousemove", onMove);
      el.removeEventListener("mouseleave", onLeave);
    };
  }, [dist, str]);

  return ref;
}
