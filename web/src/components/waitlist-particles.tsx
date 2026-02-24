/**
 * WaitlistParticles — subtle floating sage-green particles for ambiance.
 *
 * CSS-only implementation: each particle is a small div that floats
 * upward indefinitely. Purely decorative, pointer-events: none.
 */
'use client';

import { useMemo } from 'react';

interface Particle {
  id: number;
  left: number;
  size: number;
  opacity: number;
  duration: number;
  delay: number;
}

/**
 * Renders floating particle dots that drift upward in the background.
 * Should be placed inside a `relative overflow-hidden` container.
 */
export function WaitlistParticles() {
  const particles = useMemo<Particle[]>(
    () =>
      Array.from({ length: 18 }, (_, i) => ({
        id: i,
        left: Math.random() * 100,
        size: Math.random() * 2.5 + 1,
        opacity: Math.random() * 0.18 + 0.04,
        duration: Math.random() * 10 + 12,
        delay: Math.random() * 10,
      })),
    [],
  );

  return (
    <>
      <div className="pointer-events-none absolute inset-0 overflow-hidden">
        {particles.map((p) => (
          <div
            key={p.id}
            className="absolute rounded-full bg-sage"
            style={{
              left: `${p.left}%`,
              bottom: 0,
              width: `${p.size}px`,
              height: `${p.size}px`,
              opacity: p.opacity,
              animationName: 'particleFloat',
              animationDuration: `${p.duration}s`,
              animationDelay: `${p.delay}s`,
              animationTimingFunction: 'linear',
              animationIterationCount: 'infinite',
            }}
          />
        ))}
      </div>
      <style>{`
        @keyframes particleFloat {
          0%   { transform: translateY(0px); opacity: 0; }
          10%  { opacity: 1; }
          90%  { opacity: 1; }
          100% { transform: translateY(-100vh); opacity: 0; }
        }
      `}</style>
    </>
  );
}
