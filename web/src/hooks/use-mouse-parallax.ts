/**
 * useMouseParallax — shared normalized mouse position for parallax effects.
 *
 * Returns { x, y } in range [-1, 1] centered at viewport middle.
 * Uses requestAnimationFrame lerp for smooth tracking.
 *
 * On touch-only devices (no hover), `mousemove` never fires and the value
 * stays at { x: 0, y: 0 } naturally — no explicit guard needed.
 *
 * ⚠️  NON-REACTIVE: The returned `MousePosition` is a mutable ref object.
 * Do NOT read `.x` / `.y` in JSX or React render — it will NOT cause re-renders.
 * Read values only inside animation callbacks (useFrame, requestAnimationFrame).
 * For React-reactive consumers, use `getMouseParallax()` and manage your own state.
 */
"use client";

import { useEffect, useRef } from "react";

interface MousePosition {
  x: number;
  y: number;
}

const LERP_SPEED = 0.08;

/** Singleton mouse state so multiple consumers share one listener. */
const rawMouse = { x: 0, y: 0 };
const smoothMouse = { x: 0, y: 0 };
let listenerCount = 0;
let rafId: number | null = null;

function onMouseMove(e: MouseEvent) {
  rawMouse.x = (e.clientX / window.innerWidth - 0.5) * 2;
  rawMouse.y = -(e.clientY / window.innerHeight - 0.5) * 2;
}

function tick() {
  smoothMouse.x += (rawMouse.x - smoothMouse.x) * LERP_SPEED;
  smoothMouse.y += (rawMouse.y - smoothMouse.y) * LERP_SPEED;
  rafId = requestAnimationFrame(tick);
}

export function useMouseParallax(): MousePosition {
  const pos = useRef<MousePosition>({ x: 0, y: 0 });

  useEffect(() => {
    listenerCount++;
    if (listenerCount === 1) {
      window.addEventListener("mousemove", onMouseMove, { passive: true });
      rafId = requestAnimationFrame(tick);
    }

    let localRaf: number;
    const loop = () => {
      pos.current.x = smoothMouse.x;
      pos.current.y = smoothMouse.y;
      localRaf = requestAnimationFrame(loop);
    };
    localRaf = requestAnimationFrame(loop);

    return () => {
      cancelAnimationFrame(localRaf);
      listenerCount--;
      if (listenerCount === 0) {
        window.removeEventListener("mousemove", onMouseMove);
        if (rafId) cancelAnimationFrame(rafId);
      }
    };
  }, []);

  return pos.current;
}

/**
 * getMouseParallax — non-hook access for R3F useFrame callbacks.
 * Returns the same singleton smoothed mouse values.
 */
export function getMouseParallax(): MousePosition {
  return { x: smoothMouse.x, y: smoothMouse.y };
}
