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
 */

import { useEffect, useRef, useCallback } from "react";
import { loadingBridge } from "@/lib/loading-bridge";

interface LoadingScreenProps {
    onComplete: () => void;
}

export function LoadingScreen({ onComplete }: LoadingScreenProps) {
    const exitFiredRef = useRef(false);
    const mountTimeRef = useRef(Date.now());

    const handleComplete = useCallback(() => {
        const overlay = document.getElementById("ssr-loading-overlay");
        if (!overlay) {
            onComplete();
            return;
        }

        const elapsed = Date.now() - mountTimeRef.current;
        const remaining = Math.max(0, 1500 - elapsed);

        setTimeout(() => {
            overlay.style.opacity = "0";
            setTimeout(() => {
                overlay.remove();
                onComplete();
            }, 600);
        }, remaining);
    }, [onComplete]);

    useEffect(() => {
        const overlay = document.getElementById("ssr-loading-overlay");
        if (!overlay) {
            onComplete();
            return;
        }

        return loadingBridge.subscribe((p) => {
            if (p >= 100 && !exitFiredRef.current) {
                exitFiredRef.current = true;
                handleComplete();
            }
        });
    }, [onComplete, handleComplete]);

    // Renders nothing — the SSR overlay IS the loading screen
    return null;
}
