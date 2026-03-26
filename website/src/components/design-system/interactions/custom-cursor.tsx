"use client";

import { useEffect, useRef, useCallback, useState } from "react";
import gsap from "gsap";

/** Interactive selectors — elements that trigger the "expanded ring" cursor state. */
const INTERACTIVE_SELECTOR =
  "button, a, input, textarea, select, [role='button'], [role='switch'], [role='tab'], [role='checkbox'], [role='radio'], label";

function isInteractive(el: Element | null): boolean {
  return !!el?.closest(INTERACTIVE_SELECTOR);
}

export function CustomCursor() {
  const dotRef = useRef<HTMLDivElement>(null);
  const ringRef = useRef<HTMLDivElement>(null);
  const mounted = useRef(false);
  const rafId = useRef(0);
  const mousePos = useRef({ x: -100, y: -100 });
  const dirty = useRef(false);
  const hovering = useRef(false);
  const reducedMotion = useRef(false);
  const [visible, setVisible] = useState(false);

  const onMouseMove = useCallback((e: MouseEvent) => {
    mousePos.current = { x: e.clientX, y: e.clientY };
    dirty.current = true;
  }, []);

  useEffect(() => {
    // Only show on devices with a fine pointer (mouse, trackpad) — not touch
    if (!window.matchMedia("(pointer: fine)").matches) return;

    // Respect users who prefer less animation
    reducedMotion.current = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

    setVisible(true);
    mounted.current = true;

    // Hide the default cursor on the body
    document.body.style.cursor = "none";

    const RING_SIZE = 32;

    // Track mouse position with rAF-throttled rendering
    const tick = () => {
      if (!mounted.current) return;
      const { x, y } = mousePos.current;

      // Check interactive state once per frame (moved out of mousemove)
      if (dirty.current) {
        const target = document.elementFromPoint(x, y);
        const interactive = isInteractive(target);

        if (interactive !== hovering.current) {
          hovering.current = interactive;
          if (dotRef.current) {
            gsap.to(dotRef.current, {
              scale: interactive ? 0.5 : 1,
              duration: 0.25,
              ease: "power2.out",
            });
          }
          if (ringRef.current) {
            gsap.to(ringRef.current, {
              width: interactive ? 48 : 32,
              height: interactive ? 48 : 32,
              duration: 0.3,
              ease: "power2.out",
            });
          }
        }
      }

      // Dot follows exactly
      if (dotRef.current) {
        dotRef.current.style.transform = `translate(${x}px, ${y}px) translate(-50%, -50%)`;
      }

      // Ring trails with GSAP spring — only tween when mouse actually moved
      if (ringRef.current && dirty.current) {
        const ringHalfW = (hovering.current ? 48 : RING_SIZE) / 2;
        const ringHalfH = ringHalfW;

        if (reducedMotion.current) {
          // Snap directly — no trailing spring
          ringRef.current.style.transform = `translate(${x - ringHalfW}px, ${y - ringHalfH}px)`;
        } else {
          gsap.to(ringRef.current, {
            x: x - ringHalfW,
            y: y - ringHalfH,
            duration: 0.5,
            ease: "power3.out",
            overwrite: "auto",
          });
        }
      }

      dirty.current = false;
      rafId.current = requestAnimationFrame(tick);
    };

    document.addEventListener("mousemove", onMouseMove, { passive: true });
    rafId.current = requestAnimationFrame(tick);

    return () => {
      mounted.current = false;
      setVisible(false);
      document.body.style.cursor = "";
      document.removeEventListener("mousemove", onMouseMove);
      cancelAnimationFrame(rafId.current);
      if (ringRef.current) gsap.killTweensOf(ringRef.current);
      if (dotRef.current) gsap.killTweensOf(dotRef.current);
    };
  }, [onMouseMove]);

  // Render nothing until the client-side check confirms a fine pointer
  if (!visible) return null;

  return (
    <div
      aria-hidden="true"
      style={{ pointerEvents: "none", position: "fixed", inset: 0, zIndex: 9999 }}
    >
      {/* Inner dot — follows mouse exactly */}
      <div
        ref={dotRef}
        className="bg-ds-sage"
        style={{
          position: "fixed",
          top: 0,
          left: 0,
          width: 8,
          height: 8,
          borderRadius: "50%",
          transform: "translate(-100px, -100px) translate(-50%, -50%)",
          willChange: "transform",
        }}
      />
      {/* Outer ring — trails with spring physics */}
      <div
        ref={ringRef}
        style={{
          position: "fixed",
          top: 0,
          left: 0,
          width: 32,
          height: 32,
          borderRadius: "50%",
          border: "1.5px solid var(--color-ds-sage)",
          background: "transparent",
          transform: "translate(-116px, -116px)",
          willChange: "transform, width, height",
        }}
      />
    </div>
  );
}
