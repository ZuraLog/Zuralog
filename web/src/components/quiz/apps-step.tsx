/**
 * AppsStep — quiz step 1: which fitness apps does the user currently use?
 *
 * Uses @icons-pack/react-simple-icons for real brand logos where available.
 * Falls back to a styled letter badge for brands not in the icon pack
 * (WHOOP, Oura Ring, MyFitnessPal).
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

/** Brand colors for icon tinting */
const BRAND_COLORS: Record<string, string> = {
  strava: '#FC4C02',
  apple_health: '#ffffff',
  garmin: '#007CC3',
  myfitnesspal: '#00B2FF',
  whoop: '#ffffff',
  oura: '#ffffff',
  peloton: '#D90000',
  google_fit: '#4285F4',
  fitbit: '#00B0B9',
  nike_run: '#ffffff',
};

/** Letter badge for brands without an icon in simple-icons. */
function LetterIcon({ letter, color }: { letter: string; color: string }) {
  return (
    <span
      className="flex h-5 w-5 items-center justify-center rounded-md text-[10px] font-bold"
      style={{ background: color, color: '#000' }}
    >
      {letter}
    </span>
  );
}

/** Returns the icon component for a given app id. */
function AppIcon({ id }: { id: string }) {
  const color = BRAND_COLORS[id] ?? '#ffffff';
  const props = { size: 20, color };

  switch (id) {
    case 'strava':      return <SiStrava {...props} />;
    case 'apple_health': return <SiApple {...props} />;
    case 'garmin':      return <SiGarmin {...props} />;
    case 'fitbit':      return <SiFitbit {...props} />;
    case 'peloton':     return <SiPeloton {...props} />;
    case 'google_fit':  return <SiGoogle {...props} />;
    case 'myfitnesspal': return <LetterIcon letter="MFP" color="#00B2FF" />;
    case 'whoop':       return <LetterIcon letter="W" color="#3DFF54" />;
    case 'oura':        return <LetterIcon letter="O" color="#9B8EFF" />;
    case 'nike_run':    return <LetterIcon letter="N" color="#ffffff" />;
    default:            return <LetterIcon letter={id[0].toUpperCase()} color="#888" />;
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

/**
 * Multi-select grid of fitness app chips with real brand logos.
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
              <span className="shrink-0">
                <AppIcon id={app.id} />
              </span>
              <span className="text-sm font-medium leading-tight">{app.label}</span>
              {active && (
                <span className="ml-auto flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-sage text-xs font-bold text-black">
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
