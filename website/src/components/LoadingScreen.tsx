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

/** Maximum time (ms) to wait for 3D assets before force-dismissing. */
const MAX_LOADING_MS = 8_000;

/** Minimum time (ms) to show the loading screen for brand visibility. */
const MIN_DISPLAY_MS = 1_500;

interface LoadingScreenProps {
    onComplete?: () => void;
}

export function LoadingScreen({ onComplete }: LoadingScreenProps) {
    const exitFiredRef = useRef(false);
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

        // --- Safety timeout: force-dismiss after MAX_LOADING_MS ---
        const safetyTimer = setTimeout(() => {
            handleComplete();
        }, MAX_LOADING_MS);

        // --- Normal path: dismiss when loadingBridge reports 100% ---
        const unsubscribe = loadingBridge.subscribe((p) => {
            if (p >= 100) {
                handleComplete();
            }
        });

        return () => {
            clearTimeout(safetyTimer);
            unsubscribe();
        };
    }, [onComplete, handleComplete]);

    // Renders nothing — the SSR overlay IS the loading screen
    return null;
}
