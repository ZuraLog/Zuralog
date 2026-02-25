/**
 * ProgressIndicator — animated progress bar for the quiz steps.
 * Peach accent on cream background.
 */
'use client';

import { motion } from 'framer-motion';

interface ProgressIndicatorProps {
  current: number;
  total: number;
  pct: number;
}

export function ProgressIndicator({ current, total, pct }: ProgressIndicatorProps) {
  return (
    <div className="flex flex-col gap-2">
      <div className="flex items-center justify-between">
        <span className="text-xs font-medium text-black/40">
          Step {current + 1} of {total}
        </span>
        <span className="text-xs font-medium text-black/40">{pct}%</span>
      </div>
      <div className="h-1 w-full overflow-hidden rounded-full bg-black/8">
        <motion.div
          className="h-full rounded-full bg-peach"
          initial={{ width: 0 }}
          animate={{ width: `${pct}%` }}
          transition={{ duration: 0.4, ease: 'easeOut' }}
        />
      </div>
    </div>
  );
}
