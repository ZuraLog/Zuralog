"use client";

import { useRef, useEffect } from "react";
import gsap from "gsap";
import { ScrambleTextPlugin } from "gsap/ScrambleTextPlugin";

gsap.registerPlugin(ScrambleTextPlugin);

export interface ScrambleNumberOptions {
  /** The final text to resolve to (e.g. "78" or "8,432") */
  finalValue: string;
  /** Total animation duration in seconds (default 1.0) */
  duration?: number;
  /** Characters to cycle through while scrambling (default "0123456789") */
  chars?: string;
  /** Only play once (default true) */
  once?: boolean;
}

/**
 * Scrambles the text content of an element through random digits before
 * landing on the final number. Triggered when the element scrolls into
 * the viewport.
 *
 * This gives health metrics (scores, step counts, etc.) a dramatic
 * "counting up" entrance that feels data-driven and alive.
 *
 * Respects the user's "prefers-reduced-motion" setting — if they've asked
 * for less motion, the final value appears instantly with no animation.
 */
export function useScrambleNumber<T extends HTMLElement = HTMLElement>(
  options: ScrambleNumberOptions,
) {
  const {
    finalValue,
    duration = 1.0,
    chars = "0123456789",
    once = true,
  } = options;

  const ref = useRef<T>(null);
  const hasPlayed = useRef(false);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;

    // Already played once — show final value.
    if (hasPlayed.current && once) {
      el.textContent = finalValue;
      return;
    }

    // Respect reduced-motion preference.
    const prefersReducedMotion = window.matchMedia(
      "(prefers-reduced-motion: reduce)",
    ).matches;

    if (prefersReducedMotion) {
      el.textContent = finalValue;
      hasPlayed.current = true;
      return;
    }

    // Start with placeholder characters (same length as final value).
    el.textContent = finalValue.replace(/[0-9]/g, "0");

    const tween = gsap.to(el, {
      duration,
      scrambleText: {
        text: finalValue,
        chars,
        revealDelay: 0.3,
        speed: 0.4,
      },
      ease: "none",
      scrollTrigger: {
        trigger: el,
        start: "top 85%",
        toggleActions: once
          ? "play none none none"
          : "play reverse play reverse",
      },
      onComplete: () => {
        hasPlayed.current = true;
        // Ensure the final value is exactly right (no leftover scramble chars).
        el.textContent = finalValue;
      },
    });

    return () => {
      tween.scrollTrigger?.kill();
      tween.kill();
    };
  }, [finalValue, duration, chars, once]);

  return ref;
}
