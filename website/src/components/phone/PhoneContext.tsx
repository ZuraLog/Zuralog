// website/src/components/phone/PhoneContext.tsx
"use client";

import { createContext, useContext, type RefObject } from "react";

export const PhoneContext = createContext<RefObject<HTMLDivElement | null> | null>(null);

/**
 * Returns the ref pointing to the phone's outer wrapper div.
 * Pass this to gsap.to() / gsap.fromTo() to animate the phone's position and scale.
 * Must be called inside a component that is a descendant of ScrollPhone.
 */
export function usePhoneRef(): RefObject<HTMLDivElement | null> | null {
  const ctx = useContext(PhoneContext);
  if (process.env.NODE_ENV !== "production" && ctx === null) {
    console.warn(
      "usePhoneRef: called outside of a PhoneContext.Provider. " +
      "Wrap the section tree in <ScrollPhone>."
    );
  }
  return ctx;
}
