"use client";

/**
 * ClientShell.tsx
 *
 * Client-only (loaded via dynamic ssr:false). Renders PhoneCanvas and the
 * LoadingScreen overlay. Because this is never SSR'd, useState(true) for
 * showLoader is always the correct initial state with no hydration mismatch.
 */

import { useState } from "react";
import { LoadingScreen } from "@/components/LoadingScreen";
import { PhoneCanvas } from "@/components/sections/hero/PhoneCanvas";

export function ClientShell() {
    const [showLoader, setShowLoader] = useState(true);

    return (
        <>
            <PhoneCanvas />
            {showLoader && (
                <LoadingScreen onComplete={() => setShowLoader(false)} />
            )}
        </>
    );
}
