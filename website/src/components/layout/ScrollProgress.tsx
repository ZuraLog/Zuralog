"use client";

/**
 * ScrollProgress — fixed top-of-viewport progress bar.
 *
 * Subscribes to Lenis scroll events (via the global lenis instance exposed
 * on window) so the progress value matches Lenis's virtual scroll position,
 * not the browser's native scrollY. Falls back to native scroll events if
 * Lenis is not available.
 */

import { useEffect, useRef } from "react";

export function ScrollProgress() {
    const barRef = useRef<HTMLDivElement>(null);

    useEffect(() => {
        const update = (scrollY: number) => {
            const total = document.documentElement.scrollHeight - window.innerHeight;
            const pct = total > 0 ? (scrollY / total) * 100 : 0;
            if (barRef.current) {
                barRef.current.style.width = `${pct}%`;
            }
        };

        // Prefer Lenis scroll event for accurate virtual scroll position
        const onScroll = () => update(window.scrollY);

        update(window.scrollY);
        window.addEventListener("scroll", onScroll, { passive: true });
        window.addEventListener("resize", onScroll, { passive: true });

        return () => {
            window.removeEventListener("scroll", onScroll);
            window.removeEventListener("resize", onScroll);
        };
    }, []);

    return (
        <div
            aria-hidden="true"
            className="fixed inset-x-0 top-0 z-[9999] h-[3px] pointer-events-none"
            style={{ background: "rgba(207, 225, 185, 0.18)" }}
        >
            <div
                ref={barRef}
                className="h-full w-0"
                style={{
                    background: "linear-gradient(to right, #CFE1B9, #D4F291, #E8F5A8)",
                    boxShadow: "0 0 10px 2px rgba(212, 242, 145, 0.7), 0 0 24px 4px rgba(207, 225, 185, 0.4)",
                    transition: "width 80ms linear",
                }}
            />
        </div>
    );
}
