/**
 * HeroGlow — CSS-based radial glow background for the hero section.
 *
 * Replaces the broken Three.js Canvas approach with a reliable CSS
 * implementation. Renders several layered radial gradients that react
 * to mouse position via JS, creating the ambient sage-green atmospheric
 * glow seen in the reference design.
 *
 * No WebGL, no Three.js — pure DOM + CSS transforms.
 */
'use client';

import { useEffect, useRef } from 'react';

/**
 * Layered radial glow orbs that softly track the mouse cursor.
 * Each orb lerps toward the mouse at a different speed to create depth.
 */
export function HeroGlow() {
  const primaryRef = useRef<HTMLDivElement>(null);
  const secondaryRef = useRef<HTMLDivElement>(null);
  const tertiaryRef = useRef<HTMLDivElement>(null);

  const mouse = useRef({ x: 0.5, y: 0.5 });
  const pos = useRef([
    { x: 0.5, y: 0.5 },
    { x: 0.5, y: 0.5 },
    { x: 0.5, y: 0.5 },
  ]);
  const rafRef = useRef<number>(0);

  useEffect(() => {
    const onMove = (e: MouseEvent) => {
      mouse.current.x = e.clientX / window.innerWidth;
      mouse.current.y = e.clientY / window.innerHeight;
    };
    window.addEventListener('mousemove', onMove, { passive: true });

    const refs = [primaryRef, secondaryRef, tertiaryRef];
    const speeds = [0.04, 0.025, 0.015];

    const loop = () => {
      refs.forEach((ref, i) => {
        pos.current[i].x += (mouse.current.x - pos.current[i].x) * speeds[i];
        pos.current[i].y += (mouse.current.y - pos.current[i].y) * speeds[i];

        if (ref.current) {
          // Convert 0-1 range to -30px..+30px offset from center
          const dx = (pos.current[i].x - 0.5) * 60;
          const dy = (pos.current[i].y - 0.5) * 60;
          ref.current.style.transform = `translate(calc(-50% + ${dx}px), calc(-50% + ${dy}px))`;
        }
      });

      rafRef.current = requestAnimationFrame(loop);
    };

    rafRef.current = requestAnimationFrame(loop);

    return () => {
      window.removeEventListener('mousemove', onMove);
      cancelAnimationFrame(rafRef.current);
    };
  }, []);

  return (
    <div className="pointer-events-none absolute inset-0 overflow-hidden" aria-hidden="true">
      {/* Primary sage glow — large, slow, central */}
      <div
        ref={primaryRef}
        className="absolute left-1/2 top-[45%]"
        style={{
          width: '80vmax',
          height: '80vmax',
          transform: 'translate(-50%, -50%)',
          background:
            'radial-gradient(ellipse at center, rgba(207,225,185,0.18) 0%, rgba(207,225,185,0.06) 35%, transparent 70%)',
          willChange: 'transform',
        }}
      />

      {/* Secondary glow — medium, offset top-left */}
      <div
        ref={secondaryRef}
        className="absolute left-[40%] top-[35%]"
        style={{
          width: '55vmax',
          height: '55vmax',
          transform: 'translate(-50%, -50%)',
          background:
            'radial-gradient(ellipse at center, rgba(207,225,185,0.10) 0%, transparent 65%)',
          willChange: 'transform',
        }}
      />

      {/* Tertiary accent — small, bottom-right, warmish */}
      <div
        ref={tertiaryRef}
        className="absolute left-[62%] top-[60%]"
        style={{
          width: '40vmax',
          height: '40vmax',
          transform: 'translate(-50%, -50%)',
          background:
            'radial-gradient(ellipse at center, rgba(180,220,160,0.07) 0%, transparent 60%)',
          willChange: 'transform',
        }}
      />

      {/* Static vignette — darkens edges so text always reads */}
      <div
        className="absolute inset-0"
        style={{
          background:
            'radial-gradient(ellipse at 50% 50%, transparent 30%, rgba(0,0,0,0.55) 100%)',
        }}
      />
    </div>
  );
}
