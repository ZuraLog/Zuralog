/**
 * CompletionStep — shown after all quiz questions are answered.
 *
 * Displays the success panel with:
 * - Position on waitlist
 * - Founding member badge (if applicable)
 * - Referral code
 * - Share buttons
 */
'use client';

import { motion } from 'framer-motion';
import { toast } from 'sonner';
import dynamic from 'next/dynamic';
import { Button } from '@/components/ui/button';
import { getReferralUrl, buildShareText } from '@/lib/referral';
import type { SuccessData } from '@/hooks/use-quiz';

const ConfettiBurst = dynamic(
  () => import('@/components/confetti-burst').then((m) => m.ConfettiBurst),
  { ssr: false },
);

interface CompletionStepProps {
  data: SuccessData;
}

/**
 * Final step — success panel with referral sharing.
 */
export function CompletionStep({ data }: CompletionStepProps) {
  const referralUrl = getReferralUrl(data.referralCode);
  const { twitter } = buildShareText(data.position, referralUrl);
  const isFoundingMember = data.tier === 'founding_30';

  function copyLink() {
    navigator.clipboard.writeText(referralUrl).then(() => toast.success('Link copied!'));
  }

  return (
    <>
      <ConfettiBurst trigger={true} />
      <motion.div
      initial={{ opacity: 0, scale: 0.95 }}
      animate={{ opacity: 1, scale: 1 }}
      transition={{ duration: 0.4, ease: 'easeOut' }}
      className="flex flex-col items-center gap-6 text-center"
    >
      {/* Animated success icon */}
      <motion.div
        initial={{ scale: 0 }}
        animate={{ scale: 1 }}
        transition={{ type: 'spring', stiffness: 300, damping: 15, delay: 0.1 }}
        className="flex h-20 w-20 items-center justify-center rounded-full bg-sage/15 text-4xl"
      >
        {isFoundingMember ? '⭐' : '🎉'}
      </motion.div>

      <div className="flex flex-col gap-2">
        {isFoundingMember && (
          <span className="rounded-full border border-sage/30 bg-sage/10 px-4 py-1 text-xs font-semibold uppercase tracking-widest text-sage">
            Founding Member
          </span>
        )}
        <h2 className="font-display text-3xl font-bold text-white">
          You&apos;re #{data.position}!
        </h2>
        <p className="text-zinc-400">
          {isFoundingMember
            ? "You're one of the first 30 — Founding Member status locked in."
            : "Thanks for telling us about yourself. Share your link to move up the list."}
        </p>
      </div>

      {/* Referral code display */}
      <div className="w-full rounded-2xl border border-white/8 bg-white/4 p-4">
        <p className="mb-2 text-xs font-medium uppercase tracking-widest text-zinc-500">
          Your referral code
        </p>
        <p className="font-display text-2xl font-bold tracking-widest text-sage">
          {data.referralCode}
        </p>
      </div>

      {/* Share buttons */}
      <div className="flex w-full flex-col gap-3">
        <Button
          onClick={() =>
            window.open(
              `https://twitter.com/intent/tweet?text=${encodeURIComponent(twitter)}`,
              '_blank',
            )
          }
          className="w-full rounded-full bg-[#1DA1F2] font-semibold text-white hover:bg-[#1a8cd8]"
        >
          Share on X / Twitter
        </Button>
        <Button
          variant="outline"
          onClick={copyLink}
          className="w-full rounded-full border-white/15 text-zinc-300 hover:border-white/30 hover:text-white"
        >
          Copy referral link
        </Button>
      </div>

      <p className="text-xs text-zinc-600">
        Each friend who joins moves you up one spot.
      </p>
      </motion.div>
    </>
  );
}
