/**
 * mobile-scroll-bridge.ts
 *
 * A tiny shared mutable reference used to pass the MobileSection scroll
 * progress value from MobileSection.tsx → PhoneCanvas.tsx without going
 * through the CSS custom-property round-trip.
 *
 * WHY: PhoneCanvas previously read `--mobile-scroll-progress` via
 * `getComputedStyle(document.documentElement)` inside `useFrame` at ~60 fps.
 * `getComputedStyle` forces a style recalculation on every call, which is
 * expensive and a known cause of jank on scroll-heavy pages.
 *
 * HOW: MobileSection's ScrollTrigger `onUpdate` writes directly to
 * `mobileScrollProgress.value`. PhoneCanvas's `useFrame` reads that same
 * number. No DOM reads, no style recalculations.
 */

export const mobileScrollProgress = { value: 0 };
