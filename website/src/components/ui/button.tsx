/**
 * Button — minimal shadcn-style button with variant support.
 */
import * as React from 'react';
import { cn } from '@/lib/utils';

export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'default' | 'ghost';
}

export const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant = 'default', ...props }, ref) => {
    return (
      <button
        ref={ref}
        className={cn(
          'inline-flex items-center justify-center rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 disabled:pointer-events-none disabled:opacity-50',
          variant === 'default' &&
            'bg-peach text-white shadow hover:bg-peach-dim px-4 py-2',
          variant === 'ghost' &&
            'hover:bg-black/5 px-4 py-2',
          className,
        )}
        {...props}
      />
    );
  },
);
Button.displayName = 'Button';
