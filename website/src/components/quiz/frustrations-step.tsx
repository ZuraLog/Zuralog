/**
 * FrustrationsStep — quiz step 2: what frustrates the user most?
 * Peach selection state.
 */
'use client';

import { motion } from 'framer-motion';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';

const FRUSTRATIONS = [
  { id: 'too_many_apps',  label: 'Too many apps to check',          emoji: '📱' },
  { id: 'no_single_view', label: 'No single overview',              emoji: '👁' },
  { id: 'manual_logging', label: 'Manual data entry',               emoji: '✍️' },
  { id: 'no_insights',    label: "Data doesn't turn into advice",   emoji: '💡' },
  { id: 'sync_issues',    label: 'Apps never sync properly',        emoji: '🔄' },
  { id: 'overwhelmed',    label: 'Too many metrics to track',       emoji: '📊' },
];

interface FrustrationsStepProps {
  selected: string[];
  onToggle: (f: string) => void;
  onNext: () => void;
  onBack: () => void;
  canProceed: boolean;
}

export function FrustrationsStep({ selected, onToggle, onNext, onBack, canProceed }: FrustrationsStepProps) {
  return (
    <div className="flex flex-col gap-6">
      <div>
        <h2 className="text-2xl font-bold text-dark-charcoal md:text-3xl">
          What frustrates you most?
        </h2>
        <p className="mt-2 text-[#6B6864]">Select everything that resonates.</p>
      </div>

      <div className="flex flex-col gap-3">
        {FRUSTRATIONS.map((item, i) => {
          const active = selected.includes(item.id);
          return (
            <motion.button
              key={item.id}
              initial={{ opacity: 0, x: -16 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ delay: i * 0.05 }}
              onClick={() => onToggle(item.id)}
              className={cn(
                'flex items-center gap-4 rounded-2xl border p-4 text-left transition-all',
                active
                  ? 'border-[#344E41]/40 bg-[#344E41]/8 text-dark-charcoal shadow-[0_0_16px_rgba(52,78,65,0.20)]'
                  : 'border-[rgba(22,22,24,0.08)] bg-[#DEDAD4] text-[#6B6864] hover:border-black/20 hover:bg-black/4 hover:text-dark-charcoal shadow-sm',
              )}
            >
              <span className="text-2xl">{item.emoji}</span>
              <span className="font-medium">{item.label}</span>
              {active && (
                <span className="ml-auto flex h-5 w-5 items-center justify-center rounded-full bg-[#344E41] text-xs font-bold text-white">
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
          className="rounded-full border border-[rgba(22,22,24,0.15)] text-[#6B6864] hover:text-dark-charcoal"
        >
          Back
        </Button>
        <Button
          disabled={!canProceed}
          onClick={onNext}
          className="flex-1 rounded-full py-4 text-base font-semibold disabled:opacity-30"
        >
          Continue
        </Button>
      </div>
    </div>
  );
}
