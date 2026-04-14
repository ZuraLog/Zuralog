"use client";

/**
 * LoadingScreen.tsx
 *
 * Client-side controller for the SSR loading overlay (rendered in layout.tsx
 * with id="ssr-loading-overlay"). This component renders nothing itself — it
 * subscribes to loadingBridge for real 3D-asset progress and fades the SSR
 * overlay out when loading completes.
 *
 * The SSR overlay is visible from the very first paint (it's in the server
 * HTML). This component just takes over once JS hydrates.
 *
 * Minimum display: 1.5s so the brand + spinner are always seen.
 * Safety timeout: 8s max — if 3D assets hang or never load, the overlay is
 * forcibly dismissed so the user is never stuck on an infinite loader.
 */

import { useEffect, useRef, useCallback } from "react";
import { loadingBridge } from "@/lib/loading-bridge";

/** Maximum time (ms) before force-dismissing — absolute last resort. */
const MAX_LOADING_MS = 8_000;

/** Minimum time (ms) the loading screen is always shown. */
const MIN_DISPLAY_MS = 2_000;

interface LoadingScreenProps {
    onComplete?: () => void;
}

export function LoadingScreen({ onComplete }: LoadingScreenProps) {
    const exitFiredRef = useRef(false);
    // eslint-disable-next-line react-hooks/purity -- Date.now() is used only once via ref initializer, not during re-renders
    const mountTimeRef = useRef(Date.now());

    /** Fade out and remove the SSR overlay, then notify parent. */
    const handleComplete = useCallback(() => {
        if (exitFiredRef.current) return;
        exitFiredRef.current = true;

        const overlay = document.getElementById("ssr-loading-overlay");
        if (!overlay) {
            onComplete?.();
            return;
        }

        const elapsed = Date.now() - mountTimeRef.current;
        const remaining = Math.max(0, MIN_DISPLAY_MS - elapsed);

        setTimeout(() => {
            overlay.style.opacity = "0";
            setTimeout(() => {
                overlay.remove();
                onComplete?.();
            }, 600);
        }, remaining);
    }, [onComplete]);

    useEffect(() => {
        const overlay = document.getElementById("ssr-loading-overlay");
        if (!overlay) {
            // Overlay already gone (another instance dismissed it, or it was
            // never rendered). Nothing to do.
            onComplete?.();
            return;
        }

            // --- Safety timeout: absolute last resort ---
        const safetyTimer = setTimeout(handleComplete, MAX_LOADING_MS);

        // --- Normal path: wait for fonts + minimum display time ---
        // document.fonts.ready resolves when all @font-face fonts have loaded,
        // so the page never shows with invisible or fallback text.
        Promise.all([
            document.fonts.ready,
            new Promise<void>((r) => setTimeout(r, MIN_DISPLAY_MS)),
        ]).then(handleComplete);

        // --- Bonus: also dismiss early if 3D assets finish before MIN_DISPLAY_MS ---
        // handleComplete guards against double-firing via exitFiredRef.
        const unsubscribe = loadingBridge.subscribe((p) => {
            if (p >= 100) handleComplete();
        });

        return () => {
            clearTimeout(safetyTimer);
            unsubscribe();
        };
    }, [onComplete, handleComplete]);

    // Renders nothing — the SSR overlay IS the loading screen
    return null;
}
