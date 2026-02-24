/**
 * useMouseParallax — shared normalized mouse position for parallax effects.
 *
 * Returns { x, y } in range [-1, 1] centered at viewport middle.
 * Uses requestAnimationFrame lerp for smooth tracking.
 * Returns { x: 0, y: 0 } on mobile / touch devices.
 */
"use client";

import { useEffect, useRef } from "react";

interface MousePosition {
  x: number;
  y: number;
}

const LERP_SPEED = 0.08;

/** Singleton mouse state so multiple consumers share one listener. */
let rawMouse = { x: 0, y: 0 };
let smoothMouse = { x: 0, y: 0 };
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
