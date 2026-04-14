"use client";

import { useEffect, useRef } from "react";
import gsap from "gsap";

// ── Module-level singleton ────────────────────────────────────────────────────
// One window listener shared across all subscribers. Registers itself on the
// first component mount and removes itself when the last one unmounts.

type CursorHandler = (mx: number, my: number) => void;

const subscribers = new Set<CursorHandler>();
let rafPending = false;
let latestMx = 0;
let latestMy = 0;

function dispatch() {
  rafPending = false;
  subscribers.forEach((fn) => fn(latestMx, latestMy));
}

function onMouseMove(e: MouseEvent) {
  latestMx = (e.clientX / window.innerWidth - 0.5) * 2;
  latestMy = (e.clientY / window.innerHeight - 0.5) * 2;
  if (!rafPending) {
    rafPending = true;
    requestAnimationFrame(dispatch);
  }
}

function addSubscriber(fn: CursorHandler) {
  if (subscribers.size === 0) {
    window.addEventListener("mousemove", onMouseMove, { passive: true });
  }
  subscribers.add(fn);
}

function removeSubscriber(fn: CursorHandler) {
  subscribers.delete(fn);
  if (subscribers.size === 0) {
    window.removeEventListener("mousemove", onMouseMove);
    rafPending = false;
  }
}

// ── Options ───────────────────────────────────────────────────────────────────

export interface CursorParallaxOptions {
  /** 0–1 scalar applied to movement amounts. Default: 0.5 */
  depth?: number;
  /** Max horizontal shift in px. Default: 12 * depth */
  xAmt?: number;
  /** Max vertical shift in px. Default: 8 * depth */
  yAmt?: number;
  /** GSAP quickTo duration in seconds. Default: 1.2 */
  duration?: number;
  /** GSAP ease. Default: "power2.out" */
  ease?: string;
}

// ── Hook ─────────────────────────────────────────────────────────────────────

/**
 * Attaches cursor-driven parallax drift to a DOM element via a shared global
 * mouse listener — zero extra window listeners per component.
 *
 * Desktop + fine-pointer only. Respects prefers-reduced-motion.
 *
 * Usage:
 *   const ref = useCursorParallax({ depth: 0.7 });
 *   <div ref={ref} className="will-change-transform">…</div>
 */
export function useCursorParallax<T extends HTMLElement = HTMLDivElement>(
  options: CursorParallaxOptions = {},
) {
  const ref = useRef<T>(null);
  const optsRef = useRef(options);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    if (typeof window === "undefined") return;
    if (!window.matchMedia("(pointer: fine)").matches) return;
    if (window.matchMedia("(max-width: 767px)").matches) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

    const { depth = 0.5, duration = 1.2, ease = "power2.out" } = optsRef.current;
    const xAmt = optsRef.current.xAmt ?? 12 * depth;
    const yAmt = optsRef.current.yAmt ?? 8 * depth;

    const xTo = gsap.quickTo(el, "x", { duration, ease });
    const yTo = gsap.quickTo(el, "y", { duration, ease });

    const handler: CursorHandler = (mx, my) => {
      xTo(mx * xAmt);
      yTo(my * yAmt);
    };

    addSubscriber(handler);

    return () => {
      removeSubscriber(handler);
      gsap.killTweensOf(el, "x,y");
    };
  }, []); // options are frozen on mount — static by design

  return ref;
}
