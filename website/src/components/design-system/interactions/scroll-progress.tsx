"use client";

import { useEffect, useRef } from "react";

/**
 * ScrollProgress — a thin bar fixed to the top of the viewport that
 * fills from left to right as the user scrolls down the page.
 * Uses the topographic sage pattern as its fill texture.
 */
export function ScrollProgress() {
  const barRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const onScroll = () => {
      if (!barRef.current) return;
      const scrollTop = window.scrollY;
      const docHeight =
        document.documentElement.scrollHeight - window.innerHeight;
      const progress = docHeight > 0 ? (scrollTop / docHeight) * 100 : 0;
      barRef.current.style.width = `${progress}%`;
    };

    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <div className="fixed top-0 left-0 right-0 z-50 h-[2px] bg-transparent">
      <div
        ref={barRef}
        className="h-full ds-pattern-drift"
        style={{
          backgroundImage: "url('/patterns/sage.png')",
          width: "0%",
        }}
      />
    </div>
  );
}
