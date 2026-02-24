/**
 * SectionColorTransition — GSAP ScrollTrigger-driven body background color morph.
 *
 * Wires a smooth cream (#FAFAF5) → lime (#E8F5A8) transition on `document.body`
 * as the user scrolls from the Hero section into the Full Mobile (#your-gateway)
 * section. Returns null — purely a side-effect component with no DOM output.
 *
 * Trigger geometry:
 *   - start: top of #your-gateway reaches 80% from the viewport top
 *   - end:   top of #your-gateway reaches 20% from the viewport top
 *   - scrub: 1  (1-second lag behind pointer for buttery smoothness)
 *
 * Accessibility: honours `prefers-reduced-motion` — if active, the animation
 * is skipped entirely and the body backgroundColor is left unchanged.
 *
 * Cleanup: kills the ScrollTrigger and resets `document.body.style.backgroundColor`
 * on component unmount to prevent style leaks when the component is removed.
 */
'use client';

import { gsap, ScrollTrigger } from '@/lib/gsap';
import { useGSAP } from '@/hooks/use-gsap';

/** Cream section color — matches Hero bg-[var(--section-cream)] */
const COLOR_CREAM = '#FAFAF5';

/** Lime section color — matches Full Mobile bg-[var(--section-lime)] */
const COLOR_LIME = '#E8F5A8';

/**
 * Headless component that registers a GSAP ScrollTrigger to morph the
 * body background color from cream to lime as the user scrolls into
 * the Full Mobile section, and back again on reverse scroll.
 *
 * Must be rendered as a child of a layout that has Lenis + GSAP ScrollTrigger
 * set up (see SmoothScroll in layout.tsx).
 *
 * @returns null — no DOM output.
 */
export function SectionColorTransition() {
  useGSAP(() => {
    // Bail out early if the user prefers reduced motion — no colour animation.
    const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (prefersReducedMotion) return;

    // Verify the trigger element exists before wiring anything up.
    const triggerEl = document.querySelector<HTMLElement>('#your-gateway');
    if (!triggerEl) return;

    // Prime the body with the Hero/cream colour as the initial background.
    // This ensures the interpolation starts from the correct value and that
    // the body has a backgroundColor set before GSAP takes over.
    document.body.style.backgroundColor = COLOR_CREAM;

    // Animate body backgroundColor from cream → lime as #your-gateway scrolls
    // into view. GSAP handles the interpolation and scrub automatically.
    const tween = gsap.to(document.body, {
      backgroundColor: COLOR_LIME,
      ease: 'none',
      scrollTrigger: {
        trigger: triggerEl,
        start: 'top 80%',
        end: 'top 20%',
        scrub: 1,
      },
    });

    // Cleanup: kill the tween + its embedded ScrollTrigger and reset the
    // body style so subsequent navigations start from a clean state.
    return () => {
      tween.scrollTrigger?.kill();
      tween.kill();
      document.body.style.backgroundColor = '';
    };
  });

  return null;
}
