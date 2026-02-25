/**
 * GoalStep — quiz step 3: what is the user's primary fitness goal?
 * Single-select. Peach selection state.
 */
'use client';

import { motion } from 'framer-motion';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';

const GOALS = [
  { id: 'performance',  label: 'Improve athletic performance',  emoji: '🏆', desc: 'Faster, stronger, fitter' },
  { id: 'health',       label: 'Optimise general health',       emoji: '❤️', desc: 'Sleep, HRV, recovery' },
  { id: 'weight',       label: 'Manage weight & nutrition',     emoji: '⚖️', desc: 'Body composition' },
  { id: 'consistency',  label: 'Build consistent habits',       emoji: '📅', desc: 'Show up every day' },
  { id: 'data',         label: 'Understand my data better',     emoji: '🔍', desc: 'Turn numbers into meaning' },
];

interface GoalStepProps {
  selected: string;
  onSelect: (goal: string) => void;
  onNext: () => void;
  onBack: () => void;
  canProceed: boolean;
}

export function GoalStep({ selected, onSelect, onNext, onBack, canProceed }: GoalStepProps) {
  return (
    <div className="flex flex-col gap-6">
      <div>
        <h2 className="text-2xl font-bold text-dark-charcoal md:text-3xl">
          What&apos;s your main goal?
        </h2>
        <p className="mt-2 text-black/50">
          ZuraLog will personalise your experience around this.
        </p>
      </div>

      <div className="flex flex-col gap-3">
        {GOALS.map((goal, i) => {
          const active = selected === goal.id;
          return (
            <motion.button
              key={goal.id}
              initial={{ opacity: 0, x: -16 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ delay: i * 0.05 }}
              onClick={() => onSelect(goal.id)}
              className={cn(
                'flex items-center gap-4 rounded-2xl border p-4 text-left transition-all',
                active
                  ? 'border-peach/50 bg-peach/10 text-dark-charcoal shadow-[0_0_20px_rgba(255,171,118,0.15)]'
                  : 'border-black/8 bg-white text-black/50 hover:border-black/20 hover:bg-black/4 hover:text-dark-charcoal shadow-sm',
              )}
            >
              <span className="text-2xl">{goal.emoji}</span>
              <div className="flex flex-col">
                <span className="font-medium">{goal.label}</span>
                <span className="text-xs text-black/30">{goal.desc}</span>
              </div>
              {active && (
                <span className="ml-auto flex h-5 w-5 items-center justify-center rounded-full bg-peach text-xs font-bold text-white">
                  ✓
                </span>
              )}
            </motion.button>
          );
        })}
      </div>

      <div className="flex gap-3">
        <Button
          variant="ghost"
          onClick={onBack}
          className="rounded-full border border-black/10 text-black/50 hover:text-dark-charcoal"
        >
          Back
        </Button>
        <Button
          disabled={!canProceed}
          onClick={onNext}
          className="flex-1 rounded-full bg-peach py-4 text-base font-semibold text-white hover:bg-peach-dim disabled:opacity-30"
        >
          Get my spot
        </Button>
      </div>
    </div>
  );
}
