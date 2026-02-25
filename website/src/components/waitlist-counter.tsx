/**
 * WaitlistCounter — animated odometer-style number counter.
 * Peach-themed for the website waitlist section.
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
      <span className={`font-bold text-dark-charcoal tabular-nums ${sizeClass}`}>
        {prefix}
        <motion.span>{display}</motion.span>
        {suffix}
      </span>
    </div>
  );
}
