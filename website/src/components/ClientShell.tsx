"use client";

/**
 * ClientShell.tsx
 *
 * Client-only (loaded via dynamic ssr:false). Renders PhoneCanvas and the
 * LoadingScreen. The LoadingScreen subscribes to 3D-asset progress via
 * loadingBridge and fades out the SSR overlay when assets finish loading
 * (or after a safety timeout).
 *
 * Because this is never SSR'd, there are no hydration mismatches.
 */

import { LoadingScreen } from "@/components/LoadingScreen";
import { PhoneCanvas } from "@/components/sections/hero/PhoneCanvas";

export function ClientShell() {
    return (
        <>
            <PhoneCanvas />
            {/* LoadingScreen listens for 3D progress and dismisses the
                SSR overlay. It has a built-in safety timeout so the
                overlay is never stuck indefinitely. */}
            <LoadingScreen />
        </>
    );
}
