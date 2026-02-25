"use client";

/**
 * OverlayDismisser.tsx
 *
 * Layout-level safety net for the SSR loading overlay. Mounted in the root
 * layout so it runs on EVERY page — not just the home page with the 3D model.
 *
 * On the home page, the LoadingScreen component (inside ClientShell) will
 * normally dismiss the overlay once 3D assets finish loading. This component
 * acts as a fallback: if the overlay is still present after a generous timeout,
 * it force-dismisses it.
 *
 * On non-home pages (about, contact, privacy, etc.) there is no 3D content
 * and no ClientShell, so this component is the ONLY thing that dismisses the
 * overlay. It does so quickly (after the minimum brand-display time).
 *
 * The overlay's `id="ssr-loading-overlay"` is the contract between layout.tsx
 * (server) and this component + LoadingScreen (client).
 */

import { useEffect, useRef } from "react";
import { usePathname } from "next/navigation";
import { loadingBridge } from "@/lib/loading-bridge";

/**
 * Maximum time (ms) before force-dismissing the overlay on any page.
 * This is the absolute upper bound — a last resort if everything else fails.
 */
const ABSOLUTE_MAX_MS = 10_000;

/**
 * On pages without 3D content, dismiss after this many ms (enough for the
 * brand + spinner to be visible briefly).
 */
const NON_3D_DISMISS_MS = 1_600;

/** Minimum display time so the brand mark is always seen. */
const MIN_DISPLAY_MS = 800;

/**
 * Pages that include the 3D ClientShell. The overlay on these pages is
 * primarily dismissed by LoadingScreen; this component only acts as fallback.
 */
const PAGES_WITH_3D = new Set(["/"]);

export function OverlayDismisser() {
    const pathname = usePathname();
    const dismissedRef = useRef(false);

    useEffect(() => {
        // Reset on navigation (Next.js client-side nav reuses layout)
        dismissedRef.current = false;

        const overlay = document.getElementById("ssr-loading-overlay");
        if (!overlay) return; // Already gone

        const mountTime = Date.now();

        /** Fade out and remove the overlay. */
        const dismiss = () => {
            if (dismissedRef.current) return;
            dismissedRef.current = true;

            const elapsed = Date.now() - mountTime;
            const remaining = Math.max(0, MIN_DISPLAY_MS - elapsed);

            setTimeout(() => {
                // Re-check: LoadingScreen may have already removed it
                const el = document.getElementById("ssr-loading-overlay");
                if (!el) return;
                el.style.opacity = "0";
                setTimeout(() => el.remove(), 600);
            }, remaining);
        };

        const has3D = PAGES_WITH_3D.has(pathname);

        if (!has3D) {
            // No 3D on this page — dismiss quickly after brand display
            const timer = setTimeout(dismiss, NON_3D_DISMISS_MS);
            return () => clearTimeout(timer);
        }

        // Page HAS 3D content. LoadingScreen handles the normal path.
        // We only set an absolute safety timeout here as a last resort.
        const safetyTimer = setTimeout(dismiss, ABSOLUTE_MAX_MS);

        // Also listen to loadingBridge — if it hits 100% and LoadingScreen
        // somehow didn't fire, we dismiss too.
        const unsubscribe = loadingBridge.subscribe((p) => {
            if (p >= 100) dismiss();
        });

        return () => {
            clearTimeout(safetyTimer);
            unsubscribe();
        };
    }, [pathname]);

    return null;
}
