"use client";

import { useEffect, useRef, useCallback, useState } from "react";
import gsap from "gsap";

/**
 * Interactive selectors — elements that trigger the "expanded ring" cursor state.
 * Checks the hovered element and up to 3 ancestors.
 */
const INTERACTIVE_SELECTOR =
  "button, a, input, textarea, select, [role='button'], [role='switch'], [role='tab'], [role='checkbox'], [role='radio'], label";

function isInteractive(el: Element | null): boolean {
  if (!el) return false;
  let current: Element | null = el;
  for (let i = 0; i < 4; i++) {
    if (!current) break;
    if (current.matches(INTERACTIVE_SELECTOR)) return true;
    current = current.parentElement;
  }
  return false;
}

export function CustomCursor() {
  const dotRef = useRef<HTMLDivElement>(null);
  const ringRef = useRef<HTMLDivElement>(null);
  const mounted = useRef(false);
  const rafId = useRef(0);
  const mousePos = useRef({ x: -100, y: -100 });
  const hovering = useRef(false);
  const [visible, setVisible] = useState(false);

  const onMouseMove = useCallback((e: MouseEvent) => {
    mousePos.current = { x: e.clientX, y: e.clientY };

    // Check if hovering an interactive element
    const target = document.elementFromPoint(e.clientX, e.clientY);
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
  }, []);

  useEffect(() => {
    // Only show on devices with a fine pointer (mouse, trackpad) — not touch
    if (!window.matchMedia("(pointer: fine)").matches) return;

    setVisible(true);
    mounted.current = true;

    // Hide the default cursor on the body
    document.body.style.cursor = "none";

    // Track mouse position with rAF-throttled rendering
    const tick = () => {
      if (!mounted.current) return;
      const { x, y } = mousePos.current;

      // Dot follows exactly
      if (dotRef.current) {
        dotRef.current.style.transform = `translate(${x}px, ${y}px) translate(-50%, -50%)`;
      }

      // Ring trails with GSAP spring
      if (ringRef.current) {
        gsap.to(ringRef.current, {
          x: x,
          y: y,
          duration: 0.5,
          ease: "power3.out",
          overwrite: "auto",
        });
      }

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
          transform: "translate(-50%, -50%) translate(-100px, -100px)",
          willChange: "transform, width, height",
        }}
      />
    </div>
  );
}
