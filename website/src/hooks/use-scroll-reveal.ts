"use client";

import { useRef, useEffect } from "react";
import gsap from "gsap";

export interface ScrollRevealOptions {
  /** Initial translateY offset in pixels (default 30) */
  y?: number;
  /** Initial opacity (default 0) */
  opacity?: number;
  /** Animation duration in seconds (default 0.6) */
  duration?: number;
  /** Delay before animation starts in seconds (default 0) */
  delay?: number;
  /** Stagger delay between direct children in seconds (default 0) */
  stagger?: number;
  /** Only play the animation once (default true) */
  once?: boolean;
}

/**
 * Animates an element (or its children) into view when it scrolls into the
 * viewport. Uses GSAP ScrollTrigger under the hood — ScrollTrigger is already
 * registered globally via LenisProvider so we don't re-register it here.
 *
 * Attach the returned ref to the container element you want to reveal.
 *
 * Respects the user's "prefers-reduced-motion" setting — if they've asked
 * for less motion, the element snaps to its final visible state immediately
 * with no animation at all.
 */
export function useScrollReveal<T extends HTMLElement = HTMLElement>(
  options: ScrollRevealOptions = {},
) {
  const {
    y = 30,
    opacity = 0,
    duration = 0.6,
    delay = 0,
    stagger = 0,
    once = true,
  } = options;

  const ref = useRef<T>(null);
  const hasPlayed = useRef(false);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;

    // If the animation already played once, keep content visible and skip.
    if (hasPlayed.current && once) {
      gsap.set(stagger > 0 ? el.children : el, { opacity: 1, y: 0 });
      return;
    }

    // Respect reduced-motion preference — show content instantly.
    const prefersReducedMotion = window.matchMedia(
      "(prefers-reduced-motion: reduce)",
    ).matches;

    if (prefersReducedMotion) {
      gsap.set(stagger > 0 ? el.children : el, { opacity: 1, y: 0 });
      hasPlayed.current = true;
      return;
    }

    const targets = stagger > 0 ? el.children : el;

    // Set initial hidden state.
    gsap.set(targets, { opacity, y });

    const tween = gsap.to(targets, {
      opacity: 1,
      y: 0,
      duration,
      delay,
      stagger: stagger > 0 ? stagger : undefined,
      ease: "power2.out",
      scrollTrigger: {
        trigger: el,
        start: "top 85%",
        toggleActions: once
          ? "play none none none"
          : "play reverse play reverse",
      },
      onComplete: () => {
        hasPlayed.current = true;
      },
    });

    return () => {
      // Kill the tween and its associated ScrollTrigger instance.
      tween.scrollTrigger?.kill();
      tween.kill();
    };
  }, [y, opacity, duration, delay, stagger, once]);

  return ref;
}
