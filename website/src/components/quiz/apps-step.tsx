/**
 * AppsStep — quiz step 1: which fitness apps does the user currently use?
 * Peach selection state, cream background.
 */
'use client';

import { motion } from 'framer-motion';
import {
  SiStrava,
  SiApple,
  SiGarmin,
  SiFitbit,
  SiPeloton,
  SiGoogle,
} from '@icons-pack/react-simple-icons';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';

const BRAND_COLORS: Record<string, string> = {
  strava: '#FC4C02',
  apple_health: '#1C1C1E',
  garmin: '#007CC3',
  myfitnesspal: '#00B2FF',
  whoop: '#1C1C1E',
  oura: '#1C1C1E',
  peloton: '#D90000',
  google_fit: '#4285F4',
  fitbit: '#00B0B9',
  nike_run: '#1C1C1E',
};

function LetterIcon({ letter, color }: { letter: string; color: string }) {
  return (
    <span
      className="flex h-5 w-5 items-center justify-center rounded-md text-[10px] font-bold text-white"
      style={{ background: color }}
    >
      {letter}
    </span>
  );
}

function AppIcon({ id }: { id: string }) {
  const color = BRAND_COLORS[id] ?? '#555';
  const props = { size: 20, color };
  switch (id) {
    case 'strava':       return <SiStrava {...props} />;
    case 'apple_health': return <SiApple {...props} />;
    case 'garmin':       return <SiGarmin {...props} />;
    case 'fitbit':       return <SiFitbit {...props} />;
    case 'peloton':      return <SiPeloton {...props} />;
    case 'google_fit':   return <SiGoogle {...props} />;
    case 'myfitnesspal': return <LetterIcon letter="MFP" color="#00B2FF" />;
    case 'whoop':        return <LetterIcon letter="W" color="#1a1a1a" />;
    case 'oura':         return <LetterIcon letter="O" color="#9B8EFF" />;
    case 'nike_run':     return <LetterIcon letter="N" color="#1C1C1E" />;
    default:             return <LetterIcon letter={id[0].toUpperCase()} color="#888" />;
  }
}

const APPS = [
  { id: 'strava',       label: 'Strava' },
  { id: 'apple_health', label: 'Apple Health' },
  { id: 'garmin',       label: 'Garmin Connect' },
  { id: 'myfitnesspal', label: 'MyFitnessPal' },
  { id: 'whoop',        label: 'WHOOP' },
  { id: 'oura',         label: 'Oura Ring' },
  { id: 'peloton',      label: 'Peloton' },
  { id: 'google_fit',   label: 'Google Fit' },
  { id: 'fitbit',       label: 'Fitbit' },
  { id: 'nike_run',     label: 'Nike Run Club' },
];

interface AppsStepProps {
  selected: string[];
  onToggle: (app: string) => void;
  onNext: () => void;
  canProceed: boolean;
}

export function AppsStep({ selected, onToggle, onNext, canProceed }: AppsStepProps) {
  return (
    <div className="flex flex-col gap-6">
      <div>
        <h2 className="text-2xl font-bold text-dark-charcoal md:text-3xl">
          Which fitness apps do you use?
        </h2>
        <p className="mt-2 text-black/50">Select all that apply.</p>
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
                  ? 'border-peach/50 bg-peach/10 text-dark-charcoal shadow-[0_0_16px_rgba(255,171,118,0.15)]'
                  : 'border-black/8 bg-white text-black/50 hover:border-black/20 hover:bg-black/4 hover:text-dark-charcoal shadow-sm',
              )}
            >
              <span className="shrink-0"><AppIcon id={app.id} /></span>
              <span className="text-sm font-medium leading-tight">{app.label}</span>
              {active && (
                <span className="ml-auto flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-peach text-xs font-bold text-white">
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
        className="w-full rounded-full bg-peach py-4 text-base font-semibold text-white hover:bg-peach-dim disabled:opacity-30"
      >
        Continue
      </Button>
    </div>
  );
}
