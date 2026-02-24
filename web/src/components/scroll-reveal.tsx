/**
 * ScrollReveal — reusable GSAP ScrollTrigger wrapper component.
 *
 * Animates children into view when they enter the viewport:
 * - Fades in from opacity 0 → 1
 * - Slides up from `y` offset → 0
 *
 * Disabled automatically when `prefers-reduced-motion` is active.
 *
 * @example
 * ```tsx
 * <ScrollReveal>
 *   <FeatureCard />
 * </ScrollReveal>
 *
 * <ScrollReveal delay={0.2} y={40}>
 *   <HeroText />
 * </ScrollReveal>
 * ```
 */
'use client';

import { useRef } from 'react';
import { gsap, ScrollTrigger } from '@/lib/gsap';
import { useGSAP } from '@/hooks/use-gsap';

interface ScrollRevealProps {
  /** Content to animate in. */
  children: React.ReactNode;
  /** Animation delay in seconds. Default: 0 */
  delay?: number;
  /** Animation duration in seconds. Default: 0.8 */
  duration?: number;
  /** Initial Y offset in pixels. Default: 30 */
  y?: number;
  /** Additional CSS class names applied to the wrapper div. */
  className?: string;
}

/**
 * Wraps children with a GSAP scroll-triggered fade-up animation.
 *
 * @param props - ScrollRevealProps
 */
export function ScrollReveal({
  children,
  delay = 0,
  duration = 0.8,
  y = 30,
  className,
}: ScrollRevealProps) {
  const containerRef = useRef<HTMLDivElement>(null);

  useGSAP(
    () => {
      const prefersReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
      if (prefersReducedMotion || !containerRef.current) return;

      gsap.fromTo(
        containerRef.current,
        { opacity: 0, y },
        {
          opacity: 1,
          y: 0,
          duration,
          delay,
          ease: 'power3.out',
          scrollTrigger: {
            trigger: containerRef.current,
            start: 'top 85%',
            toggleActions: 'play none none none',
          },
        },
      );

      return () => {
        ScrollTrigger.getAll().forEach((trigger) => {
          if (trigger.trigger === containerRef.current) {
            trigger.kill();
          }
        });
      };
    },
    { scope: containerRef },
  );

  return (
    <div ref={containerRef} className={className}>
      {children}
    </div>
  );
}
