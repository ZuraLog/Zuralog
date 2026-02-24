/**
 * ConfettiBurst — fires a confetti animation when triggered.
 *
 * Renders nothing visually. Uses canvas-confetti to overlay a
 * burst of sage-green, white, and gold particles on the screen.
 * Import dynamically (ssr: false) to avoid SSR issues.
 */
'use client';

import { useEffect, useRef } from 'react';
import confetti from 'canvas-confetti';

interface ConfettiBurstProps {
  /** Set to true to trigger the burst */
  trigger: boolean;
}

/**
 * Fires a two-stage confetti burst when trigger becomes true.
 */
export function ConfettiBurst({ trigger }: ConfettiBurstProps) {
  const fired = useRef(false);

  useEffect(() => {
    if (!trigger || fired.current) return;
    fired.current = true;

    const colors = ['#CFE1B9', '#ffffff', '#FFD700', '#A8C98A', '#D4EBB8'];

    // First burst — main explosion
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

    // Second burst — softer follow-up
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
