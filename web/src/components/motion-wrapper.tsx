/**
 * Framer Motion animation presets for the Zuralog website.
 *
 * Exports reusable `variants` objects and pre-configured `motion` components.
 * All animations respect `prefers-reduced-motion` via Framer Motion's built-in
 * `useReducedMotion` hook — when active, transitions are set to `{ duration: 0 }`.
 *
 * @example
 * ```tsx
 * import { MotionDiv, fadeInVariants } from '@/components/motion-wrapper';
 *
 * <MotionDiv variants={fadeInVariants} initial="hidden" animate="visible">
 *   <p>Hello</p>
 * </MotionDiv>
 * ```
 */
'use client';

import { motion, useReducedMotion, type Variants } from 'framer-motion';

/**
 * Fade in from opacity 0 to 1 with a gentle upward slide.
 */
export const fadeInVariants: Variants = {
  hidden: { opacity: 0, y: 20 },
  visible: { opacity: 1, y: 0, transition: { duration: 0.6, ease: 'easeOut' } },
};

/**
 * Slide up from below with fade.
 */
export const slideUpVariants: Variants = {
  hidden: { opacity: 0, y: 40 },
  visible: { opacity: 1, y: 0, transition: { duration: 0.7, ease: [0.25, 0.1, 0.25, 1] } },
};

/**
 * Scale in from slightly smaller.
 */
export const scaleInVariants: Variants = {
  hidden: { opacity: 0, scale: 0.95 },
  visible: { opacity: 1, scale: 1, transition: { duration: 0.5, ease: 'easeOut' } },
};

/**
 * Stagger container — staggers children animations.
 * Use with `staggerChildren` and child variants.
 */
export const staggerContainerVariants: Variants = {
  hidden: {},
  visible: {
    transition: {
      staggerChildren: 0.1,
      delayChildren: 0.1,
    },
  },
};

interface MotionDivProps extends Omit<React.ComponentProps<typeof motion.div>, 'children'> {
  children?: React.ReactNode;
}

/**
 * MotionDiv — pre-configured `motion.div` that auto-disables
 * animations when `prefers-reduced-motion` is active.
 *
 * Drop-in replacement for `motion.div` with reduced-motion support.
 *
 * @param props - All motion.div props plus optional children.
 */
export function MotionDiv({ children, ...props }: MotionDivProps) {
  const prefersReducedMotion = useReducedMotion();

  if (prefersReducedMotion) {
    return <div>{children}</div>;
  }

  return <motion.div {...props}>{children}</motion.div>;
}

interface MotionSectionProps extends Omit<React.ComponentProps<typeof motion.section>, 'children'> {
  children?: React.ReactNode;
}

/**
 * MotionSection — pre-configured `motion.section` with reduced-motion support.
 *
 * @param props - All motion.section props plus optional children.
 */
export function MotionSection({ children, ...props }: MotionSectionProps) {
  const prefersReducedMotion = useReducedMotion();

  if (prefersReducedMotion) {
    return <section>{children}</section>;
  }

  return <motion.section {...props}>{children}</motion.section>;
}
