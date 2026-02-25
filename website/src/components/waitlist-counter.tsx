/**
 * WaitlistCounter — animated odometer-style number counter.
 * Peach-themed for the website waitlist section.
 *
 * Animates from the current spring value toward `value` every time `value`
 * changes — including realtime updates — so the display always stays live.
 */
'use client';

import { useEffect, useRef } from 'react';
import { motion, useSpring, useTransform, useInView } from 'framer-motion';

interface WaitlistCounterProps {
  value: number;
  className?: string;
  prefix?: string;
  suffix?: string;
  delay?: number;
  sizeClass?: string;
}

export function WaitlistCounter({
  value,
  className,
  prefix,
  suffix,
  delay = 0,
  sizeClass = 'text-3xl',
}: WaitlistCounterProps) {
  const ref = useRef<HTMLDivElement>(null);
  // once: false so that subsequent value changes (realtime updates) also
  // trigger a re-animation when the element scrolls into view.
  const isInView = useInView(ref, { once: false });
  const spring = useSpring(0, { stiffness: 55, damping: 22 });
  const display = useTransform(spring, (v) => Math.round(v).toLocaleString());

  useEffect(() => {
    if (value <= 0) return;
    if (!isInView) return;
    const timer = setTimeout(() => spring.set(value), delay);
    return () => clearTimeout(timer);
  }, [isInView, value, spring, delay]);

  return (
    <div ref={ref} className={className}>
      <span className={`font-bold text-dark-charcoal tabular-nums ${sizeClass}`}>
        {prefix}
        <motion.span>{display}</motion.span>
        {suffix}
      </span>
    </div>
  );
}
