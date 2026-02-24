/**
 * WaitlistCounter — an animated odometer-style number counter.
 *
 * Uses framer-motion useSpring + useTransform to smoothly animate
 * from 0 to the target value when it enters the viewport.
 */
'use client';

import { useEffect, useRef } from 'react';
import { motion, useSpring, useTransform, useInView } from 'framer-motion';

interface WaitlistCounterProps {
  /** Target number to count up to */
  value: number;
  /** Optional CSS class for the root element */
  className?: string;
  /** Optional text prefix (e.g. "#") */
  prefix?: string;
  /** Optional text suffix (e.g. "+") */
  suffix?: string;
  /** Delay before animation starts (ms) */
  delay?: number;
  /** Font size class override */
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
  const isInView = useInView(ref, { once: true });
  const spring = useSpring(0, { stiffness: 55, damping: 22 });
  const display = useTransform(spring, (v) => Math.round(v).toLocaleString());

  useEffect(() => {
    if (!isInView || value <= 0) return;
    const timer = setTimeout(() => spring.set(value), delay);
    return () => clearTimeout(timer);
  }, [isInView, value, spring, delay]);

  return (
    <div ref={ref} className={className}>
      <span className={`font-display font-bold text-white tabular-nums ${sizeClass}`}>
        {prefix}
        <motion.span>{display}</motion.span>
        {suffix}
      </span>
    </div>
  );
}
