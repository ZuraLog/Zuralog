/**
 * SectionWrapper — Container for full-width page sections with explicit backgrounds.
 *
 * Implements the CryptoHub-inspired alternating background color pattern:
 * cream → lime → dark → dark → lime → dark → cream → dark
 *
 * Each section gets its own background color applied directly (NOT via
 * theme-mode switching). The text colors adjust automatically based on
 * the `theme` prop ("light" or "dark" text).
 *
 * Includes `section-padding` and `section-container` for consistent spacing.
 *
 * @example
 * ```tsx
 * <SectionWrapper bg="cream" theme="light" id="hero">
 *   <h1 className="text-display-hero">Unified Health.</h1>
 * </SectionWrapper>
 *
 * <SectionWrapper bg="dark" theme="dark" id="bento">
 *   <SectionCard variant="light">Feature card on dark bg</SectionCard>
 * </SectionWrapper>
 * ```
 */
'use client';

import * as React from 'react';
import { cn } from '@/lib/utils';

/** Available section background colors from the master plan palette. */
type SectionBackground = 'cream' | 'lime' | 'dark' | 'white';

/** Text theme determines foreground color set for the section. */
type SectionTheme = 'light' | 'dark';

/** Map background tokens to CSS values. */
const bgMap: Record<SectionBackground, string> = {
  cream: 'bg-[var(--section-cream)]',
  lime: 'bg-[var(--section-lime)]',
  dark: 'bg-[var(--section-dark)]',
  white: 'bg-white',
};

/** Map text theme to foreground color classes. */
const themeMap: Record<SectionTheme, string> = {
  /** Dark text for light backgrounds (cream, lime, white). */
  light: 'text-[var(--text-primary)]',
  /** Light text for dark backgrounds. */
  dark: 'text-[var(--text-light)]',
};

interface SectionWrapperProps extends React.ComponentProps<'section'> {
  /** Section background color from the alternating palette. */
  bg: SectionBackground;
  /**
   * Text theme — determines foreground text colors.
   * "light" = dark text (for cream/lime/white backgrounds).
   * "dark" = light text (for dark charcoal backgrounds).
   */
  theme: SectionTheme;
  /** Whether to include the default generous vertical padding. Default: true. */
  padded?: boolean;
  /** Whether to include the max-width container. Default: true. */
  contained?: boolean;
  /** Enable full viewport height. Default: false. */
  fullHeight?: boolean;
}

/**
 * Full-width section wrapper with explicit background color and text theme.
 *
 * @param props - SectionWrapperProps
 * @returns A styled section element with consistent spacing and color scheme.
 */
function SectionWrapper({
  bg,
  theme,
  padded = true,
  contained = true,
  fullHeight = false,
  className,
  children,
  ...props
}: SectionWrapperProps) {
  return (
    <section
      data-slot="section-wrapper"
      data-bg={bg}
      data-theme={theme}
      className={cn(
        'relative w-full overflow-hidden',
        bgMap[bg],
        themeMap[theme],
        padded && 'section-padding',
        fullHeight && 'min-h-screen',
        className,
      )}
      {...props}
    >
      {contained ? (
        <div className="section-container">{children}</div>
      ) : (
        children
      )}
    </section>
  );
}

export { SectionWrapper };
export type { SectionBackground, SectionTheme };
