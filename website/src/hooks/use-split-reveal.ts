"use client";

import { useRef, useEffect } from "react";
import gsap from "gsap";
import { SplitText } from "gsap/SplitText";

gsap.registerPlugin(SplitText);

export interface SplitRevealOptions {
  /** Per-character stagger delay in seconds (default 0.03) */
  stagger?: number;
  /** Animation duration per character in seconds (default 0.5) */
  duration?: number;
  /** Initial Y offset in pixels (default 20) */
  y?: number;
  /** Only play once (default true) */
  once?: boolean;
}

/**
 * Splits an element's text into individual characters and animates them
 * into view one by one when the element scrolls into the viewport.
 *
 * If the element has the `ds-pattern-text` class (topographic pattern fill),
 * the pattern fades in after the characters land, so the texture appears
 * to "paint" onto the fully-revealed text.
 *
 * Respects the user's "prefers-reduced-motion" setting — if they've asked
 * for less motion, the text appears instantly with no animation.
 */
export function useSplitReveal<T extends HTMLElement = HTMLElement>(
  options: SplitRevealOptions = {},
) {
  const { stagger = 0.03, duration = 0.5, y = 20, once = true } = options;

  const ref = useRef<T>(null);
  const hasPlayed = useRef(false);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;

    // Already played once — keep visible.
    if (hasPlayed.current && once) return;

    // Respect reduced-motion preference.
    const prefersReducedMotion = window.matchMedia(
      "(prefers-reduced-motion: reduce)",
    ).matches;

    if (prefersReducedMotion) {
      hasPlayed.current = true;
      return;
    }

    // Check if this element uses the pattern-fill class.
    const hasPattern =
      el.classList.contains("ds-pattern-text") ||
      el.classList.contains("ds-pattern-text-static");

    // If it has a pattern, temporarily make the text solid so the split
    // characters are visible during the entrance animation. We'll fade
    // the pattern back in after the characters land.
    const originalColor = el.style.color;
    const originalBgClip = el.style.webkitBackgroundClip;

    if (hasPattern) {
      // Show the text as the pattern color (sage) during the reveal,
      // then swap back to the clipped pattern after the animation.
      el.style.color = "";
      el.style.webkitBackgroundClip = "";
      el.classList.remove("ds-pattern-text", "ds-pattern-text-static");
      el.style.color = "var(--color-ds-sage)";
    }

    // Split the text into individual characters.
    const split = SplitText.create(el, {
      type: "chars",
      charsClass: "ds-split-char",
    });

    // Set initial hidden state for each character.
    gsap.set(split.chars, { y, opacity: 0, display: "inline-block" });

    const tl = gsap.timeline({
      scrollTrigger: {
        trigger: el,
        start: "top 85%",
        toggleActions: once
          ? "play none none none"
          : "play reverse play reverse",
      },
      onComplete: () => {
        hasPlayed.current = true;

        // Restore the pattern fill after the text has fully landed.
        if (hasPattern) {
          // Revert SplitText so we get the original text node back,
          // then re-apply the pattern class.
          split.revert();
          el.style.color = originalColor;
          el.style.webkitBackgroundClip = originalBgClip;

          // Determine which class to restore.
          const isBold =
            window.getComputedStyle(el).fontWeight >= "700" ||
            el.dataset.patternAnimate === "true";
          el.classList.add(
            isBold ? "ds-pattern-text" : "ds-pattern-text-static",
          );

          // Fade the pattern in with a brief opacity pulse.
          gsap.fromTo(
            el,
            { opacity: 0.7 },
            { opacity: 1, duration: 0.4, ease: "power2.out" },
          );
        }
      },
    });

    // Stagger each character into view.
    tl.to(split.chars, {
      y: 0,
      opacity: 1,
      duration,
      stagger,
      ease: "power2.out",
    });

    return () => {
      tl.scrollTrigger?.kill();
      tl.kill();
      // Only revert if SplitText hasn't already been reverted.
      try {
        split.revert();
      } catch {
        // Already reverted — ignore.
      }
    };
  }, [stagger, duration, y, once]);

  return ref;
}
