/**
 * WaitlistParticles — subtle floating peach particles for the waitlist section.
 * CSS-only: each particle drifts upward indefinitely. Purely decorative.
 */
'use client';

import { useEffect, useMemo, useState } from 'react';

interface Particle {
  id: number;
  left: number;
  size: number;
  opacity: number;
  duration: number;
  delay: number;
}

export function WaitlistParticles() {
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  const particles = useMemo<Particle[]>(
    () =>
      Array.from({ length: 18 }, (_, i) => ({
        id: i,
        left: Math.random() * 100,
        size: Math.random() * 2.5 + 1,
        opacity: Math.random() * 0.25 + 0.06,
        duration: Math.random() * 10 + 12,
        delay: Math.random() * 10,
      })),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [mounted],
  );

  if (!mounted) return null;

  return (
    <div className="pointer-events-none absolute inset-0 overflow-hidden">
      {particles.map((p) => (
        <div
          key={p.id}
          className="absolute rounded-full bg-peach"
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
  );
}
