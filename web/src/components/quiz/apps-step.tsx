/**
 * AppsStep — quiz step 1: which fitness apps does the user currently use?
 */
'use client';

import { motion } from 'framer-motion';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';

const APPS = [
  { id: 'strava', label: 'Strava', emoji: '🚴' },
  { id: 'apple_health', label: 'Apple Health', emoji: '🍎' },
  { id: 'garmin', label: 'Garmin Connect', emoji: '⌚' },
  { id: 'myfitnesspal', label: 'MyFitnessPal', emoji: '🥗' },
  { id: 'whoop', label: 'WHOOP', emoji: '💪' },
  { id: 'oura', label: 'Oura Ring', emoji: '💍' },
  { id: 'peloton', label: 'Peloton', emoji: '🚲' },
  { id: 'google_fit', label: 'Google Fit', emoji: '📱' },
  { id: 'fitbit', label: 'Fitbit', emoji: '📊' },
  { id: 'nike_run', label: 'Nike Run Club', emoji: '👟' },
];

interface AppsStepProps {
  selected: string[];
  onToggle: (app: string) => void;
  onNext: () => void;
  canProceed: boolean;
}

/**
 * Multi-select grid of fitness app chips.
 */
export function AppsStep({ selected, onToggle, onNext, canProceed }: AppsStepProps) {
  return (
    <div className="flex flex-col gap-6">
      <div>
        <h2 className="font-display text-2xl font-bold text-white md:text-3xl">
          Which fitness apps do you use?
        </h2>
        <p className="mt-2 text-zinc-400">Select all that apply.</p>
      </div>

      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
        {APPS.map((app, i) => {
          const active = selected.includes(app.id);
          return (
            <motion.button
              key={app.id}
              initial={{ opacity: 0, y: 16 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: i * 0.04 }}
              onClick={() => onToggle(app.id)}
              className={cn(
                'flex items-center gap-3 rounded-2xl border p-4 text-left transition-all',
                active
                  ? 'border-sage/50 bg-sage/10 text-white shadow-[0_0_20px_rgba(207,225,185,0.1)]'
                  : 'border-white/8 bg-white/4 text-zinc-400 hover:border-white/20 hover:bg-white/8 hover:text-white',
              )}
            >
              <span className="text-xl">{app.emoji}</span>
              <span className="text-sm font-medium">{app.label}</span>
              {active && (
                <span className="ml-auto flex h-5 w-5 items-center justify-center rounded-full bg-sage text-xs font-bold text-black">
                  ✓
                </span>
              )}
            </motion.button>
          );
        })}
      </div>

      <Button
        disabled={!canProceed}
        onClick={onNext}
        className="w-full rounded-full bg-sage py-4 text-base font-semibold text-black hover:bg-sage/90 disabled:opacity-30"
      >
        Continue
      </Button>
    </div>
  );
}
