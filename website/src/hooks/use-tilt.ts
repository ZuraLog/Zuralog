"use client";

import { useEffect, useRef } from "react";
import gsap from "gsap";

interface TiltOptions {
  /** Maximum rotation in degrees (default 3) */
  maxTilt?: number;
  /** CSS perspective value in px (default 900) */
  perspective?: number;
  /** Scale factor on hover (default 1.02) */
  scale?: number;
}

/**
 * useTilt — attaches a GSAP-based 3D magnetic tilt to any element.
 * Based on the proven pattern from DashboardBento.tsx.
 *
 * Automatically skips on touch devices and when the user prefers
 * reduced motion, so callers don't need to worry about accessibility.
 */
export function useTilt<T extends HTMLElement = HTMLDivElement>(
  options?: TiltOptions
) {
  const ref = useRef<T>(null);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    if (!window.matchMedia("(pointer: fine)").matches) return;

    const maxT = options?.maxTilt ?? 3;
    const persp = options?.perspective ?? 900;
    const sc = options?.scale ?? 1.02;
    let rafId = 0;

    el.style.perspective = `${persp}px`;
    el.style.willChange = "transform";

    const onMove = (e: MouseEvent) => {
      cancelAnimationFrame(rafId);
      rafId = requestAnimationFrame(() => {
        const rect = el.getBoundingClientRect();
        const cx = rect.left + rect.width / 2;
        const cy = rect.top + rect.height / 2;
        const dx = (e.clientX - cx) / (rect.width / 2);
        const dy = (e.clientY - cy) / (rect.height / 2);

        gsap.to(el, {
          rotateY: dx * maxT,
          rotateX: -dy * maxT,
          scale: sc,
          duration: 0.35,
          ease: "power2.out",
          overwrite: "auto",
        });
      });
    };

    const onLeave = () => {
      cancelAnimationFrame(rafId);
      gsap.to(el, {
        rotateY: 0,
        rotateX: 0,
        scale: 1,
        duration: 0.6,
        ease: "elastic.out(1, 0.4)",
        overwrite: "auto",
      });
    };

    el.addEventListener("mousemove", onMove);
    el.addEventListener("mouseleave", onLeave);

    return () => {
      cancelAnimationFrame(rafId);
      gsap.killTweensOf(el);
      el.removeEventListener("mousemove", onMove);
      el.removeEventListener("mouseleave", onLeave);
    };
  }, [options?.maxTilt, options?.perspective, options?.scale]);

  return ref;
}
