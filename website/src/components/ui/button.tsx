/**
 * Button — premium button with variant support and animated topographic pattern.
 *
 * Variants:
 *   - default: Deep Forest bg with animated topo pattern overlay (primary CTA)
 *   - light:   Sage/lime bg with animated topo pattern (light context CTA)
 *   - ghost:   Transparent with hover bg
 *
 * The pattern animation is CSS-only via .btn-pattern / .btn-pattern-light,
 * all pointing to a single shared /pattern-sm.jpg file.
 */
import * as React from 'react';
import { cn } from '@/lib/utils';

export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'default' | 'light' | 'ghost';
}

export const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant = 'default', children, ...props }, ref) => {
    return (
      <button
        ref={ref}
        className={cn(
          'inline-flex items-center justify-center rounded-full text-sm font-semibold transition-all duration-300 focus-visible:outline-none focus-visible:ring-2 disabled:pointer-events-none disabled:opacity-50',
          variant === 'default' &&
            'btn-pattern-light bg-[#CFE1B9] text-[#141E18] px-6 py-3 shadow-[0_2px_16px_rgba(207,225,185,0.35)] hover:scale-[1.03] hover:shadow-[0_4px_30px_rgba(207,225,185,0.55)] active:scale-[0.97] focus-visible:ring-[#344E41]/40',
          variant === 'light' &&
            'btn-pattern bg-[#344E41] text-[#E8EDE0] px-6 py-3 hover:scale-[1.03] hover:shadow-[0_0_24px_rgba(207,225,185,0.25)] active:scale-[0.97] focus-visible:ring-[#CFE1B9]/40',
          variant === 'ghost' &&
            'hover:bg-black/5 px-4 py-2 focus-visible:ring-black/20',
          className,
        )}
        {...props}
      >
        <span className="relative z-2">{children}</span>
      </button>
    );
  },
);
Button.displayName = 'Button';
