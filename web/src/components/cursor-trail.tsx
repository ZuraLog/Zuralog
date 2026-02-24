/**
 * CursorTrail — a subtle sage-green glow that follows the mouse cursor.
 *
 * Implemented as a single div that tracks mouse position via CSS custom
 * properties, using a radial gradient + mix-blend-mode for a soft glow.
 * No canvas, no heavy libraries — pure CSS transforms.
 *
 * Only renders on non-touch (pointer:fine) devices.
 */
'use client';

import { useEffect, useRef } from 'react';

/**
 * Attaches a glowing div to the document that follows the cursor
 * with a smooth lerp animation.
 */
export function CursorTrail() {
  const dotRef = useRef<HTMLDivElement>(null);
  const pos = useRef({ x: -200, y: -200 });
  const current = useRef({ x: -200, y: -200 });
  const rafRef = useRef<number>(0);

  useEffect(() => {
    // Only on pointer-capable (non-touch) devices
    if (!window.matchMedia('(pointer: fine)').matches) return;

    const onMove = (e: MouseEvent) => {
      pos.current = { x: e.clientX, y: e.clientY };
    };

    window.addEventListener('mousemove', onMove, { passive: true });

    const loop = () => {
      const LERP = 0.12;
      current.current.x += (pos.current.x - current.current.x) * LERP;
      current.current.y += (pos.current.y - current.current.y) * LERP;

      if (dotRef.current) {
        dotRef.current.style.transform =
          `translate(${current.current.x - 150}px, ${current.current.y - 150}px)`;
      }

      rafRef.current = requestAnimationFrame(loop);
    };

    rafRef.current = requestAnimationFrame(loop);

    return () => {
      window.removeEventListener('mousemove', onMove);
      cancelAnimationFrame(rafRef.current);
    };
  }, []);

  return (
    <div
      ref={dotRef}
      aria-hidden="true"
      className="pointer-events-none fixed left-0 top-0 z-[9999] h-[300px] w-[300px] rounded-full"
      style={{
        background:
          'radial-gradient(circle, rgba(207,225,185,0.08) 0%, transparent 70%)',
        willChange: 'transform',
      }}
    />
  );
}
