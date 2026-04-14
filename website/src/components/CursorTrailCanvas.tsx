"use client";

/**
 * CursorRevealCanvas
 *
 * Two-layer cursor reveal effect:
 *   Layer 1 (z-index: -2): Brand topographic pattern — always present, static.
 *   Layer 2 (z-index: -1): Canvas cleared and redrawn every frame.
 *
 * Each brush stamp is stored with a timestamp. Every frame the canvas is
 * cleared to solid cream, then all live stamps are redrawn with opacity
 * proportional to their age — newest stamps are fully visible, oldest are
 * nearly transparent. This produces a "snake" tail: the end of the trail
 * fades first, working backwards toward the cursor.
 *
 * To remove entirely: delete this file and remove <CursorTrailCanvas /> from
 * app/page.tsx. Nothing else in the codebase references it.
 */

import { useEffect, useRef } from "react";

const BG             = "rgb(240, 238, 233)"; // #F0EEE9 — page background
const RADIUS         = 12;                   // brush radius in px
const SPACING        = 6;                    // min px between stamps along the path
const TRAIL_DURATION = 1800;                 // ms — how long a stamp lives
const LERP           = 0.12;                 // brush easing (0 = frozen, 1 = instant)
const STOP_THRESHOLD = 0.4;                  // px/frame below which brush is "settled"
const MAX_STAMPS     = 1000;                 // safety cap on buffer size

interface Stamp { x: number; y: number; t: number }

export function CursorTrailCanvas() {
  const maskRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = maskRef.current;
    if (!canvas) return;
    if (!window.matchMedia("(pointer: fine)").matches) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    // ── Size canvas to full viewport ──────────────────────────────────────────
    const resize = () => {
      canvas.width  = window.innerWidth;
      canvas.height = window.innerHeight;
      // canvas auto-clears on resize; the animate loop fills it each frame anyway
    };
    resize();
    window.addEventListener("resize", resize, { passive: true });

    // ── Draw one brush stamp at (x, y) with a given opacity ──────────────────
    // opacity=1 → full hole, opacity=0 → no hole (invisible)
    const punchHole = (x: number, y: number, opacity: number) => {
      if (opacity <= 0) return;
      const g = ctx.createRadialGradient(x, y, 0, x, y, RADIUS);
      g.addColorStop(0,    `rgba(0,0,0,${0.95 * opacity})`);
      g.addColorStop(0.45, `rgba(0,0,0,${0.6  * opacity})`);
      g.addColorStop(0.8,  `rgba(0,0,0,${0.12 * opacity})`);
      g.addColorStop(1,    "rgba(0,0,0,0)");
      ctx.globalCompositeOperation = "destination-out";
      ctx.fillStyle = g;
      ctx.beginPath();
      ctx.arc(x, y, RADIUS, 0, Math.PI * 2);
      ctx.fill();
    };

    // ── State ─────────────────────────────────────────────────────────────────
    const stamps: Stamp[] = [];
    let stampStart = 0; // index of the oldest live stamp (avoids O(n) shift())

    let cursorX    = -9999;
    let cursorY    = -9999;
    let brushX     = -9999;
    let brushY     = -9999;
    let prevBrushX = -9999;
    let prevBrushY = -9999;
    let paintX     = -9999; // last position where a stamp was committed
    let paintY     = -9999;
    let active     = false;

    const onMouseMove = (e: MouseEvent) => {
      cursorX = e.clientX;
      cursorY = e.clientY;
      if (!active) {
        brushX = prevBrushX = paintX = cursorX;
        brushY = prevBrushY = paintY = cursorY;
        active = true;
      }
    };
    const onMouseLeave = () => { active = false; };

    // ── Animation loop ────────────────────────────────────────────────────────
    let rafId = 0;

    const animate = () => {
      const now = performance.now();

      // 1. Move brush toward cursor
      let velocity = 0;
      if (active) {
        prevBrushX = brushX;
        prevBrushY = brushY;
        brushX += (cursorX - brushX) * LERP;
        brushY += (cursorY - brushY) * LERP;
        velocity = Math.sqrt(
          (brushX - prevBrushX) ** 2 + (brushY - prevBrushY) ** 2
        );
      }

      // 2. Add new stamps while the brush is actively moving
      if (active && velocity > STOP_THRESHOLD) {
        const dx   = brushX - paintX;
        const dy   = brushY - paintY;
        const dist = Math.sqrt(dx * dx + dy * dy);

        if (dist >= SPACING) {
          const steps = Math.floor(dist / SPACING);
          for (let i = 1; i <= steps; i++) {
            stamps.push({
              x: paintX + (dx * i) / steps,
              y: paintY + (dy * i) / steps,
              t: now,
            });
          }
          paintX = brushX;
          paintY = brushY;

          // Hard cap — trim the oldest if we overshoot
          if (stamps.length - stampStart > MAX_STAMPS) {
            stampStart = stamps.length - MAX_STAMPS;
          }
        }
      }

      // 3. Advance the start pointer past expired stamps (O(1) amortized)
      while (stampStart < stamps.length && now - stamps[stampStart].t >= TRAIL_DURATION) {
        stampStart++;
      }

      // Compact the array periodically so it doesn't grow unboundedly
      if (stampStart > MAX_STAMPS / 2) {
        stamps.splice(0, stampStart);
        stampStart = 0;
      }

      // 4. Clear canvas to solid cream
      ctx.globalCompositeOperation = "source-over";
      ctx.fillStyle = BG;
      ctx.fillRect(0, 0, canvas.width, canvas.height);

      // 5. Redraw live stamps — oldest first so newer ones paint on top.
      //    Opacity = 1 − (age / duration): tail fades first, head stays bright.
      for (let i = stampStart; i < stamps.length; i++) {
        const age     = now - stamps[i].t;
        const opacity = 1 - age / TRAIL_DURATION;
        punchHole(stamps[i].x, stamps[i].y, opacity);
      }

      rafId = requestAnimationFrame(animate);
    };

    window.addEventListener("mousemove",  onMouseMove,  { passive: true });
    window.addEventListener("mouseleave", onMouseLeave, { passive: true });
    rafId = requestAnimationFrame(animate);

    return () => {
      window.removeEventListener("mousemove",  onMouseMove);
      window.removeEventListener("mouseleave", onMouseLeave);
      window.removeEventListener("resize",     resize);
      cancelAnimationFrame(rafId);
    };
  }, []);

  return (
    <>
      {/* Layer 1 — static pattern, always visible through holes */}
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
      {/* Layer 2 — mask canvas, rebuilt from stamp history each frame */}
      <canvas
        ref={maskRef}
        aria-hidden="true"
        className="fixed inset-0 pointer-events-none"
        style={{ zIndex: -1 }}
      />
    </>
  );
}
