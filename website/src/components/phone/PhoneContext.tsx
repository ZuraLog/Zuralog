// website/src/components/phone/PhoneContext.tsx
"use client";

import { createContext, useContext, useRef, type RefObject } from "react";

/**
 * Shape of the phone context — everything sections need to animate
 * the ScrollPhone overlay and crossfade between phone screens.
 *
 * phoneRef             — positioning wrapper div (sections animate x/y here for large moves)
 * containerRef         — full-viewport fixed overlay div (opacity for void zones)
 * parallaxRef          — inner wrapper div (global mouse parallax small x/y offsets)
 * placeholderScreenRef — wrapper div around PlaceholderScreen (crossfade opacity + filter)
 * connectScreenRef     — wrapper div around ConnectScreen (crossfade opacity + filter)
 * nutritionScreenRef   — wrapper div around NutritionScreen (crossfade opacity + filter)
 *
 * Individual convenience hooks exist for phoneRef and containerRef because they
 * are commonly needed alone. Screen refs and parallaxRef are only needed together
 * with the others during a full section transition — use usePhoneContext() for all.
 */
export interface PhoneContextValue {
  phoneRef: RefObject<HTMLDivElement | null>;
  containerRef: RefObject<HTMLDivElement | null>;
  placeholderScreenRef: RefObject<HTMLDivElement | null>;
  connectScreenRef: RefObject<HTMLDivElement | null>;
  nutritionScreenRef: RefObject<HTMLDivElement | null>;
  parallaxRef: RefObject<HTMLDivElement | null>;
}

export const PhoneContext = createContext<PhoneContextValue | null>(null);
PhoneContext.displayName = "PhoneContext";

/**
 * PhoneProvider — owns the six shared DOM refs and makes them available
 * to any descendant via usePhoneContext().
 *
 * Mount this high in the tree (e.g. inside ClientProviders) so that both
 * ScrollPhone (which attaches the refs to DOM nodes) and page sections
 * (which read the refs to drive GSAP animations) are descendants.
 *
 * ScrollPhone is a consumer — it receives refs from context and attaches
 * them to its DOM nodes via the `ref` prop.
 */
export function PhoneProvider({ children }: { children: React.ReactNode }) {
  const phoneRef = useRef<HTMLDivElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const placeholderScreenRef = useRef<HTMLDivElement>(null);
  const connectScreenRef = useRef<HTMLDivElement>(null);
  const nutritionScreenRef = useRef<HTMLDivElement>(null);
  const parallaxRef = useRef<HTMLDivElement>(null); // Wired to DOM node in ScrollPhone

  const contextValue: PhoneContextValue = {
    phoneRef,
    containerRef,
    placeholderScreenRef,
    connectScreenRef,
    nutritionScreenRef,
    parallaxRef,
  };

  return <PhoneContext.Provider value={contextValue}>{children}</PhoneContext.Provider>;
}

/**
 * Returns the full phone context — all 6 refs.
 *
 * Use this in section components that need to control the overlay visibility,
 * phone position, parallax offset, AND screen crossfades (e.g., ConnectSection).
 *
 * Returns null if called outside a PhoneProvider — always null-check
 * before using any ref in a GSAP callback.
 */
export function usePhoneContext(): PhoneContextValue | null {
  const ctx = useContext(PhoneContext);
  if (process.env.NODE_ENV !== "production" && ctx === null) {
    console.warn(
      "usePhoneContext: called outside of a PhoneProvider. " +
        "Wrap the app tree in <PhoneProvider>."
    );
  }
  return ctx;
}

/**
 * Convenience hook — returns just the phoneRef (the PhoneMockup outer div).
 *
 * Use when you only need to animate the phone's position/scale without
 * touching overlay opacity or screens. For full section transitions
 * (fade in + reposition + screen crossfade), use usePhoneContext() instead.
 *
 * Returns null if called outside a PhoneProvider — always null-check
 * before use in GSAP callbacks.
 */
export function usePhoneRef(): RefObject<HTMLDivElement | null> | null {
  const ctx = useContext(PhoneContext);
  if (process.env.NODE_ENV !== "production" && ctx === null) {
    console.warn(
      "usePhoneRef: called outside of a PhoneProvider. " +
        "Wrap the app tree in <PhoneProvider>."
    );
  }
  return ctx?.phoneRef ?? null;
}

/**
 * Convenience hook — returns just the containerRef (the full-viewport fixed overlay div).
 *
 * Use when you only need to control overlay visibility without touching
 * phone position or screens. For full section transitions, use usePhoneContext() instead.
 *
 * Returns null if called outside a PhoneProvider — always null-check
 * before use in GSAP callbacks.
 */
export function usePhoneContainerRef(): RefObject<HTMLDivElement | null> | null {
  const ctx = useContext(PhoneContext);
  if (process.env.NODE_ENV !== "production" && ctx === null) {
    console.warn(
      "usePhoneContainerRef: called outside of a PhoneProvider. " +
        "Wrap the app tree in <PhoneProvider>."
    );
  }
  return ctx?.containerRef ?? null;
}

/**
 * Responsive phone frame width.
 * Scales with viewport width up to a maximum of 420px (the hero design target).
 * Returns 420 on the server (SSR fallback — actual value computed on mount).
 */
export function computeFrameWidth(): number {
  if (typeof window === "undefined") return 420;
  return Math.round(Math.min(window.innerWidth * 0.32, 420));
}

/**
 * GSAP y offset (px) to apply to the phone positioning div so the phone top
 * sits at approximately 78% of the viewport height — the hero "peek from below" position.
 *
 * The positioning div is centered via `top-1/2 -translate-y-1/2`, so its default
 * center is at 50vh. This offset pushes the center down to 78vh + phoneHeight/2,
 * placing the phone top at 78vh.
 *
 * Note: this offset is only correct for elements using the CSS centering pattern `top-1/2 -translate-y-1/2`. It is not applicable to `position: absolute; top: 78vh` elements.
 *
 * @param frameWidth - The current computed phone frame width in pixels
 */
export function computeHeroY(frameWidth: number): number {
  if (typeof window === "undefined") return 0;
  const phoneHeight = Math.round(frameWidth * (864 / 427));
  return Math.round(window.innerHeight * 0.28 + phoneHeight / 2);
}
