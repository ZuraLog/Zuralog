// website/src/components/phone/ScrollPhone.tsx
"use client";

import { useState, useEffect } from "react";
import gsap from "gsap";
import { PhoneMockup } from "./PhoneMockup";
import { usePhoneContext, computeFrameWidth, computeHeroY } from "./PhoneContext";
import { PlaceholderScreen } from "./screens/PlaceholderScreen";
import { ConnectScreen } from "./screens/ConnectScreen";
import { NutritionScreen } from "./screens/NutritionScreen";
import { loadingBridge } from "@/lib/loading-bridge";

/**
 * Single fixed phone overlay — the only phone instance on the page.
 *
 * DOM structure:
 *   containerRef div  — full-viewport fixed layer (z-40, pointer-events-none)
 *     └── phoneRef div  — centering wrapper (absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2)
 *                         Sections animate large positional moves (x/y) here.
 *                         On mount a GSAP y-offset positions the phone top at ~78vh (hero peek).
 *          └── parallaxRef div  — global mouse parallax small x/y offsets
 *               └── PhoneMockup  — responsive frameWidth computed from viewport
 *                    └── screen stack div  — three screens stacked absolutely
 *                         ├── placeholderScreenRef div  (opacity:1, filter:blur(0px))
 *                         ├── connectScreenRef div      (opacity:0, filter:blur(10px))
 *                         └── nutritionScreenRef div    (opacity:0, filter:blur(10px))
 *
 * Always-visible behavior:
 *   The container has NO opacity-0 class — the phone is rendered from the very first
 *   frame. The hero y-offset (set in the mount effect) makes it peek from below the
 *   fold. HeroSection's scroll animation lifts it into its final hero position.
 *
 * Screen crossfades:
 *   Sections drive opacity + filter transitions on the screen wrapper divs via GSAP.
 *   Initial inline styles are set here so GSAP owns the values from frame one —
 *   no Tailwind class conflicts. blur-fade pattern: opacity 0→1 paired with
 *   blur 10px→0px creates a soft reveal.
 *
 * PhoneContext.Provider lives in PhoneProvider (mounted in ClientProviders), so
 * the context is available to both this component and to sibling section components.
 */
export function ScrollPhone() {
  const phoneCtx = usePhoneContext();

  // Default 420 is the SSR/first-render fallback (matches computeFrameWidth SSR guard).
  // The mount effect immediately computes the real viewport-responsive value.
  const [frameWidth, setFrameWidth] = useState(420);

  // Effect 1 — signal to the loading screen that there are no 3D assets to load.
  // LoadingScreen dismisses after its 1.5s minimum display time once this fires.
  useEffect(() => {
    loadingBridge.setProgress(100);
  }, []);

  // Effect 2 — compute responsive frameWidth and set the hero y-offset on mount.
  // The y-offset positions the phone top at ~78vh so it peeks from below the fold.
  useEffect(() => {
    const fw = computeFrameWidth();
    setFrameWidth(fw);

    const phone = phoneCtx?.phoneRef.current;
    if (phone) {
      gsap.set(phone, { y: computeHeroY(fw) });
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Effect 3 — keep frameWidth in sync when the browser is resized.
  // Also re-apply the hero y-position to keep it current with the new frameWidth.
  useEffect(() => {
    const handleResize = () => {
      const fw = computeFrameWidth();
      setFrameWidth(fw);
      const phone = phoneCtx?.phoneRef.current;
      if (phone) {
        gsap.set(phone, { y: computeHeroY(fw) });
      }
    };
    window.addEventListener("resize", handleResize);
    return () => window.removeEventListener("resize", handleResize);
  }, []);

  // Effect 4 — global mouse parallax on the parallaxRef wrapper.
  // Skipped entirely when the user prefers reduced motion.
  useEffect(() => {
    const parallax = phoneCtx?.parallaxRef.current;
    if (!parallax) return;

    const prefersReduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (prefersReduced) return;

    const xTo = gsap.quickTo(parallax, "x", { duration: 1.4, ease: "power2.out" });
    const yTo = gsap.quickTo(parallax, "y", { duration: 1.4, ease: "power2.out" });

    const handleMouseMove = (e: MouseEvent) => {
      const dx = (e.clientX / window.innerWidth - 0.5) * 2;
      const dy = (e.clientY / window.innerHeight - 0.5) * 2;
      xTo(dx * 18);
      yTo(dy * 12);
    };

    window.addEventListener("mousemove", handleMouseMove);
    return () => window.removeEventListener("mousemove", handleMouseMove);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Guard: on mobile the ClientShellGate never mounts this component, but
  // also protect against context being unavailable for any reason.
  if (!phoneCtx) return null;

  const {
    containerRef,
    phoneRef,
    parallaxRef,
    placeholderScreenRef,
    connectScreenRef,
    nutritionScreenRef,
  } = phoneCtx;

  return (
    /* Fixed full-viewport layer — phone overlay above page content, always visible */
    <div
      ref={containerRef}
      className="hidden md:block fixed inset-0 z-40 pointer-events-none"
      aria-hidden="true"
    >
      {/* phoneRef: centering + large GSAP position moves (scroll-driven). will-change-transform
          keeps the GPU layer warm so GSAP animations don't cause layout jank. */}
      <div
        ref={phoneRef}
        className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 will-change-transform"
      >
        {/* parallaxRef: small mouse-tracking x/y offsets layered on top of scroll position */}
        <div ref={parallaxRef} className="will-change-transform">
          <PhoneMockup frameWidth={frameWidth}>
            {/* Screen stack — three screens absolutely fill the phone content area.
                Initial opacity/filter values are set via inline style so GSAP owns
                them from the first frame and Tailwind classes never conflict. */}
            <div className="relative w-full h-full">
              <div
                ref={placeholderScreenRef}
                className="absolute inset-0"
                style={{ opacity: 1, filter: "blur(0px)" }}
              >
                <PlaceholderScreen label="ZuraLog" />
              </div>
              <div
                ref={connectScreenRef}
                className="absolute inset-0"
                style={{ opacity: 0, filter: "blur(10px)" }}
              >
                <ConnectScreen />
              </div>
              <div
                ref={nutritionScreenRef}
                className="absolute inset-0"
                style={{ opacity: 0, filter: "blur(10px)" }}
              >
                <NutritionScreen />
              </div>
            </div>
          </PhoneMockup>
        </div>
      </div>
    </div>
  );
}
