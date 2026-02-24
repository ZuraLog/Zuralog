/**
 * GoalStep — quiz step 3: what is the user's primary fitness goal?
 */
'use client';

import { motion } from 'framer-motion';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';

const GOALS = [
  { id: 'performance', label: 'Improve athletic performance', emoji: '🏆', desc: 'Faster, stronger, fitter' },
  { id: 'health', label: 'Optimise general health', emoji: '❤️', desc: 'Sleep, HRV, recovery' },
  { id: 'weight', label: 'Manage weight & nutrition', emoji: '⚖️', desc: 'Body composition' },
  { id: 'consistency', label: 'Build consistent habits', emoji: '📅', desc: 'Show up every day' },
  { id: 'data', label: 'Understand my data better', emoji: '🔍', desc: 'Turn numbers into meaning' },
];

interface GoalStepProps {
  selected: string;
  onSelect: (goal: string) => void;
  onNext: () => void;
  onBack: () => void;
  canProceed: boolean;
}

/**
 * Single-select list of primary fitness goals.
 */
export function GoalStep({ selected, onSelect, onNext, onBack, canProceed }: GoalStepProps) {
  return (
    <div className="flex flex-col gap-6">
      <div>
        <h2 className="font-display text-2xl font-bold text-white md:text-3xl">
          What's your main goal?
        </h2>
        <p className="mt-2 text-zinc-400">
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
                  ? 'border-sage/50 bg-sage/10 text-white shadow-[0_0_24px_rgba(207,225,185,0.12)]'
                  : 'border-white/8 bg-white/4 text-zinc-400 hover:border-white/20 hover:bg-white/8 hover:text-white',
              )}
            >
              <span className="text-2xl">{goal.emoji}</span>
              <div className="flex flex-col">
                <span className="font-medium">{goal.label}</span>
                <span className="text-xs text-zinc-500">{goal.desc}</span>
              </div>
              {active && (
                <span className="ml-auto flex h-5 w-5 items-center justify-center rounded-full bg-sage text-xs font-bold text-black">
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
          className="rounded-full border border-white/10 text-zinc-400 hover:text-white"
        >
          Back
        </Button>
        <Button
          disabled={!canProceed}
          onClick={onNext}
          className="flex-1 rounded-full bg-sage py-4 text-base font-semibold text-black hover:bg-sage/90 disabled:opacity-30"
        >
          Get my spot
        </Button>
      </div>
    </div>
  );
}
