"use client";

/**
 * CursorRevealCanvas
 *
 * Two-layer cursor reveal effect:
 *   Layer 1 (z-index: -2): Brand topographic pattern — always present, static.
 *   Layer 2 (z-index: -1): Solid #F0EEE9 mask canvas — covers the pattern.
 *
 * On mouse move: `destination-out` punches soft brush-stroke holes through
 * the mask, revealing the pattern beneath — like erasing with a Photoshop brush.
 *
 * Each animation frame: a low-alpha `source-over` fill slowly re-covers the
 * holes, making the revealed pattern fade back over ~1.5 seconds.
 *
 * Sections that should show this effect must have transparent backgrounds
 * (no backgroundColor set) so the canvas layers show through beneath them.
 *
 * To remove entirely: delete this file and remove <CursorTrailCanvas /> from
 * app/page.tsx. Nothing else in the codebase references it.
 */

import { useEffect, useRef } from "react";

const BG_COLOR = "rgb(240, 238, 233)";   // #F0EEE9 — matches section bg
const BRUSH_RADIUS = 88;                  // px — brush circle size
const BRUSH_SPACING = 7;                  // px — distance between stamps along path
const FADE_ALPHA = 0.022;                 // per-frame refill speed (lower = longer trail)

export function CursorTrailCanvas() {
  const maskRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = maskRef.current;
    if (!canvas) return;

    // Touch-only devices and reduced-motion: skip entirely
    if (!window.matchMedia("(pointer: fine)").matches) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    // ── Size mask to viewport ─────────────────────────────────────────────────
    const resize = () => {
      canvas.width = window.innerWidth;
      canvas.height = window.innerHeight;
      // Resizing clears the canvas — re-fill with background color
      ctx.fillStyle = BG_COLOR;
      ctx.fillRect(0, 0, canvas.width, canvas.height);
    };
    resize();
    window.addEventListener("resize", resize, { passive: true });

    // ── Punch a soft brush hole at (x, y) ────────────────────────────────────
    const punchHole = (x: number, y: number) => {
      const grad = ctx.createRadialGradient(x, y, 0, x, y, BRUSH_RADIUS);
      grad.addColorStop(0,    "rgba(0,0,0,0.92)"); // strong erase at center
      grad.addColorStop(0.45, "rgba(0,0,0,0.6)");
      grad.addColorStop(0.8,  "rgba(0,0,0,0.15)");
      grad.addColorStop(1,    "rgba(0,0,0,0)");    // feathered to nothing at edge

      ctx.globalCompositeOperation = "destination-out";
      ctx.fillStyle = grad;
      ctx.beginPath();
      ctx.arc(x, y, BRUSH_RADIUS, 0, Math.PI * 2);
      ctx.fill();
    };

    // ── Mouse tracking with path interpolation ────────────────────────────────
    let lastPos: { x: number; y: number } | null = null;

    const onMouseMove = (e: MouseEvent) => {
      const { clientX: x, clientY: y } = e;

      if (!lastPos) {
        punchHole(x, y);
        lastPos = { x, y };
        return;
      }

      // Interpolate stamps along the path so fast moves are still continuous
      const dx = x - lastPos.x;
      const dy = y - lastPos.y;
      const dist = Math.sqrt(dx * dx + dy * dy);
      const steps = Math.max(1, Math.floor(dist / BRUSH_SPACING));

      for (let i = 1; i <= steps; i++) {
        punchHole(
          lastPos.x + (dx * i) / steps,
          lastPos.y + (dy * i) / steps,
        );
      }

      lastPos = { x, y };
    };

    // ── Animation loop: gradually refill holes with background color ───────────
    // One fillRect per frame — extremely cheap.
    let rafId = 0;

    const animate = () => {
      ctx.globalCompositeOperation = "source-over";
      ctx.fillStyle = `rgba(240, 238, 233, ${FADE_ALPHA})`;
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      rafId = requestAnimationFrame(animate);
    };

    window.addEventListener("mousemove", onMouseMove, { passive: true });
    rafId = requestAnimationFrame(animate);

    return () => {
      window.removeEventListener("mousemove", onMouseMove);
      window.removeEventListener("resize", resize);
      cancelAnimationFrame(rafId);
    };
  }, []);

  return (
    <>
      {/* Layer 1 — static pattern: always visible behind the mask */}
      <div
        aria-hidden="true"
        className="fixed inset-0 pointer-events-none"
        style={{
          zIndex: -2,
          backgroundImage: "url('/patterns/original.png')",
          backgroundSize: "300px auto",
          backgroundRepeat: "repeat",
        }}
      />

      {/* Layer 2 — mask canvas: solid bg with destination-out holes */}
      <canvas
        ref={maskRef}
        aria-hidden="true"
        className="fixed inset-0 pointer-events-none"
        style={{ zIndex: -1 }}
      />
    </>
  );
}
