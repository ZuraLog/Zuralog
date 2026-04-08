// website/src/components/phone/ScrollPhone.tsx
"use client";

import { useRef, useEffect, useMemo } from "react";
import { useGSAP } from "@gsap/react";
import gsap from "gsap";
import ScrollTrigger from "gsap/ScrollTrigger";
import { PhoneMockup } from "./PhoneMockup";
import { PhoneContext } from "./PhoneContext";
import type { PhoneContextValue } from "./PhoneContext";
import { PlaceholderScreen } from "./screens/PlaceholderScreen";
import { ConnectScreen } from "./screens/ConnectScreen";
import { loadingBridge } from "@/lib/loading-bridge";

if (typeof window !== "undefined") {
  gsap.registerPlugin(ScrollTrigger);
}

export function ScrollPhone() {
  const containerRef = useRef<HTMLDivElement>(null);
  const phoneRef = useRef<HTMLDivElement>(null);
  const placeholderScreenRef = useRef<HTMLDivElement>(null);
  const connectScreenRef = useRef<HTMLDivElement>(null);

  // No 3D assets to load — signal complete immediately so LoadingScreen
  // dismisses after its 1.5s minimum display time.
  useEffect(() => {
    loadingBridge.setProgress(100);
  }, []);

  useGSAP(
    () => {
      // Each section manages its own GSAP scroll animations by calling
      // useGSAP() with its own scope in its own component. That pattern
      // ensures ScrollTrigger instances are cleaned up when the section
      // unmounts. Do NOT add section-specific animations here.
    },
    { scope: containerRef, dependencies: [] }
  );

  const contextValue = useMemo<PhoneContextValue>(
    () => ({
      phoneRef,
      containerRef,
      placeholderScreenRef,
      connectScreenRef,
    }),
    []
  );

  return (
    <PhoneContext.Provider value={contextValue}>
      {/* Same fixed full-viewport layering as the old ScrollPhoneCanvas */}
      <div
        ref={containerRef}
        className="hidden md:block fixed inset-0 z-40 pointer-events-none opacity-0"
        aria-hidden="true"
      >
        <div className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2">
          <PhoneMockup ref={phoneRef} frameWidth={320}>
            {/* Screen stack — both screens are absolutely positioned.
                PlaceholderScreen starts visible (opacity 1), ConnectScreen starts hidden (opacity 0).
                Sections animate these opacities to crossfade between them. */}
            <div className="relative w-full h-full">
              <div
                ref={placeholderScreenRef}
                className="absolute inset-0"
                style={{ opacity: 1 }}
              >
                <PlaceholderScreen label="ZuraLog" />
              </div>
              <div
                ref={connectScreenRef}
                className="absolute inset-0"
                style={{ opacity: 0 }}
              >
                <ConnectScreen />
              </div>
            </div>
          </PhoneMockup>
        </div>
      </div>
    </PhoneContext.Provider>
  );
}
