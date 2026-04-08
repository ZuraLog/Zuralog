// website/src/components/phone/PhoneContext.tsx
"use client";

import { createContext, useContext, useRef, useMemo, type RefObject } from "react";

/**
 * Shape of the phone context — everything sections need to animate
 * the ScrollPhone overlay and crossfade between phone screens.
 *
 * phoneRef             — the PhoneMockup outer div (animate x/y/scale via GSAP)
 * containerRef         — the full-viewport fixed overlay div (animate opacity via GSAP)
 * placeholderScreenRef — wrapper div around PlaceholderScreen (crossfade opacity)
 * connectScreenRef     — wrapper div around ConnectScreen (crossfade opacity)
 *
 * Individual convenience hooks exist for phoneRef and containerRef because they
 * are commonly needed alone. Screen refs (placeholderScreenRef, connectScreenRef)
 * are only needed together with the others during a full section transition — use
 * usePhoneContext() to access all four at once.
 */
export interface PhoneContextValue {
  phoneRef: RefObject<HTMLDivElement | null>;
  containerRef: RefObject<HTMLDivElement | null>;
  placeholderScreenRef: RefObject<HTMLDivElement | null>;
  connectScreenRef: RefObject<HTMLDivElement | null>;
}

export const PhoneContext = createContext<PhoneContextValue | null>(null);

/**
 * PhoneProvider — owns the four shared DOM refs and makes them available
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

  const value = useMemo<PhoneContextValue>(
    () => ({ phoneRef, containerRef, placeholderScreenRef, connectScreenRef }),
    []
  );

  return <PhoneContext.Provider value={value}>{children}</PhoneContext.Provider>;
}

/**
 * Returns the full phone context — all 4 refs.
 *
 * Use this in section components that need to control the overlay visibility,
 * phone position, AND screen crossfades (e.g., ConnectSection).
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
