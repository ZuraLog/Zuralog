/**
 * ConfettiBurst — fires a confetti animation when triggered.
 * Peach, cream, and gold palette for the website.
 * Import dynamically (ssr: false) to avoid SSR issues.
 */
'use client';

import { useEffect, useRef } from 'react';
import confetti from 'canvas-confetti';

interface ConfettiBurstProps {
  trigger: boolean;
}

export function ConfettiBurst({ trigger }: ConfettiBurstProps) {
  const fired = useRef(false);

  useEffect(() => {
    if (!trigger || fired.current) return;
    fired.current = true;

    const colors = ['#FFAB76', '#FFF5EE', '#FFD700', '#FF8C4B', '#FFDAB9'];

    confetti({
      particleCount: 120,
      spread: 80,
      origin: { x: 0.5, y: 0.65 },
      colors,
      ticks: 220,
      gravity: 0.8,
      scalar: 0.9,
      startVelocity: 35,
    });

    const timer = setTimeout(() => {
      confetti({
        particleCount: 60,
        spread: 50,
        origin: { x: 0.5, y: 0.6 },
        colors,
        ticks: 160,
        gravity: 0.6,
        scalar: 0.7,
        startVelocity: 25,
      });
    }, 350);

    return () => clearTimeout(timer);
  }, [trigger]);

  return null;
}
