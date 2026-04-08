// website/src/components/phone/ScrollPhone.tsx
"use client";

import { useRef, useEffect } from "react";
import { useGSAP } from "@gsap/react";
import gsap from "gsap";
import ScrollTrigger from "gsap/ScrollTrigger";
import { PhoneMockup } from "./PhoneMockup";
import { PhoneContext } from "./PhoneContext";
import { PlaceholderScreen } from "./screens/PlaceholderScreen";
import { loadingBridge } from "@/lib/loading-bridge";

if (typeof window !== "undefined") {
  gsap.registerPlugin(ScrollTrigger);
}

export function ScrollPhone() {
  const containerRef = useRef<HTMLDivElement>(null);
  const phoneRef = useRef<HTMLDivElement>(null);

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

  return (
    <PhoneContext.Provider value={phoneRef}>
      {/* Same fixed full-viewport layering as the old ScrollPhoneCanvas */}
      <div
        ref={containerRef}
        className="hidden md:block fixed inset-0 z-40 pointer-events-none"
        aria-hidden="true"
      >
        <div className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2">
          <PhoneMockup ref={phoneRef}>
            <PlaceholderScreen label="ZuraLog" />
          </PhoneMockup>
        </div>
      </div>
    </PhoneContext.Provider>
  );
}
