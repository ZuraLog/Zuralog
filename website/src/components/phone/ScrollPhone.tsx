// website/src/components/phone/ScrollPhone.tsx
"use client";

import { useEffect } from "react";
import { PhoneMockup } from "./PhoneMockup";
import { usePhoneContext } from "./PhoneContext";
import { PlaceholderScreen } from "./screens/PlaceholderScreen";
import { ConnectScreen } from "./screens/ConnectScreen";
import { loadingBridge } from "@/lib/loading-bridge";

/**
 * Fixed phone overlay — sits at z-40 above the page, starts fully transparent.
 *
 * Sections manage their own GSAP ScrollTrigger animations by calling useGSAP()
 * with their own scope. That pattern ensures ScrollTrigger instances are cleaned
 * up when sections unmount. This component intentionally contains no GSAP logic —
 * it only owns the DOM structure and attaches the shared refs from PhoneContext
 * to its nodes.
 *
 * PhoneContext.Provider lives in PhoneProvider (mounted in ClientProviders), so
 * the context is available to both this component and to page sections like
 * ConnectSection — even though they are siblings in the React tree.
 *
 * Screen stack: PlaceholderScreen (opacity 1) and ConnectScreen (opacity 0) are
 * stacked absolutely. Sections crossfade between them by animating these opacities.
 * The initial opacity values are set via inline style so GSAP owns them from the
 * first frame — no Tailwind class conflicts.
 */
export function ScrollPhone() {
  const phoneCtx = usePhoneContext();

  // No 3D assets to load — signal complete immediately so LoadingScreen
  // dismisses after its 1.5s minimum display time.
  useEffect(() => {
    loadingBridge.setProgress(100);
  }, []);

  // On mobile the ClientShellGate never mounts this component, but guard
  // here too in case context is unavailable for any reason.
  if (!phoneCtx) return null;

  const { containerRef, phoneRef, placeholderScreenRef, connectScreenRef } =
    phoneCtx;

  return (
    /* Fixed full-viewport layering — phone overlay above page content */
    <div
      ref={containerRef}
      className="hidden md:block fixed inset-0 z-40 pointer-events-none opacity-0"
      aria-hidden="true"
    >
      <div className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2">
        <PhoneMockup ref={phoneRef} frameWidth={320}>
          {/* Screen stack — both screens absolutely fill the phone content area.
              Initial opacity values are intentionally symmetric so the crossfade
              range (0↔1) is readable directly from JSX without needing GSAP context. */}
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
  );
}
