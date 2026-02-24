/**
 * ProgressIndicator — animated progress bar for the quiz steps.
 */
'use client';

import { motion } from 'framer-motion';

interface ProgressIndicatorProps {
  /** Current 0-based step index */
  current: number;
  /** Total steps (excluding signup) */
  total: number;
  /** Percentage 0–100 */
  pct: number;
}

/**
 * Renders a pill-shaped progress bar and step counter.
 */
export function ProgressIndicator({ current, total, pct }: ProgressIndicatorProps) {
  return (
    <div className="flex flex-col gap-2">
      <div className="flex items-center justify-between">
        <span className="text-xs font-medium text-zinc-500">
          Step {current + 1} of {total}
        </span>
        <span className="text-xs font-medium text-zinc-500">{pct}%</span>
      </div>
      <div className="h-1 w-full overflow-hidden rounded-full bg-white/8">
        <motion.div
          className="h-full rounded-full bg-sage"
          initial={{ width: 0 }}
          animate={{ width: `${pct}%` }}
          transition={{ duration: 0.4, ease: 'easeOut' }}
        />
      </div>
    </div>
  );
}
