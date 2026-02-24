/**
 * WaitlistForm — email signup form with referral code support.
 *
 * Handles:
 * - Email + optional referral code input
 * - Submission to /api/waitlist/join
 * - Success state with position, share buttons, and referral URL
 * - Error states with toast notifications
 */
'use client';

import { useState, useEffect } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { motion, AnimatePresence } from 'framer-motion';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { getReferralUrl, buildShareText } from '@/lib/referral';
import type { QuizAnswers } from '@/hooks/use-quiz';

const schema = z.object({
  email: z.string().email('Enter a valid email address'),
  referralCode: z.string().optional(),
});
type FormData = z.infer<typeof schema>;

interface SuccessData {
  position: number;
  referralCode: string;
  tier: string;
}

interface WaitlistFormProps {
  quizAnswers: QuizAnswers;
  onBack: () => void;
}

/**
 * Waitlist email signup form with success state.
 */
export function WaitlistForm({ quizAnswers, onBack }: WaitlistFormProps) {
  const [success, setSuccess] = useState<SuccessData | null>(null);
  const [loading, setLoading] = useState(false);

  // Pre-fill referral code from URL ?ref= param
  const [urlRef, setUrlRef] = useState('');
  useEffect(() => {
    const ref = new URLSearchParams(window.location.search).get('ref') ?? '';
    setUrlRef(ref);
  }, []);

  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<FormData>({ resolver: zodResolver(schema) });

  async function onSubmit(data: FormData) {
    setLoading(true);
    try {
      const res = await fetch('/api/waitlist/join', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: data.email,
          referralCode: data.referralCode || urlRef || null,
          quizAnswers,
        }),
      });
      const json = await res.json();

      if (!res.ok) {
        toast.error(json.error ?? 'Something went wrong. Please try again.');
        return;
      }

      setSuccess({
        position: json.position,
        referralCode: json.referralCode,
        tier: json.tier,
      });

      if (json.alreadyJoined) {
        toast.info("You're already on the waitlist!");
      } else {
        toast.success("You're on the waitlist!");
      }
    } catch {
      toast.error('Network error. Please try again.');
    } finally {
      setLoading(false);
    }
  }

  return (
    <AnimatePresence mode="wait">
      {!success ? (
        <motion.div
          key="form"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          className="flex flex-col gap-6"
        >
          <div>
            <h2 className="font-display text-2xl font-bold text-white md:text-3xl">
              Secure your spot on the list
            </h2>
            <p className="mt-2 text-zinc-400">
              We'll notify you the moment ZuraLog is ready for you.
            </p>
          </div>

          <form onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-4">
            <div className="flex flex-col gap-1.5">
              <Input
                type="email"
                placeholder="your@email.com"
                autoComplete="email"
                className="h-14 rounded-2xl border-white/10 bg-white/5 px-5 text-base placeholder:text-zinc-600 focus:border-sage/50 focus:ring-sage/20"
                {...register('email')}
              />
              {errors.email && (
                <p className="text-sm text-red-400">{errors.email.message}</p>
              )}
            </div>

            {/* Referral code (pre-filled from URL or manual) */}
            <div className="flex flex-col gap-1.5">
              <Input
                type="text"
                placeholder="Referral code (optional)"
                defaultValue={urlRef}
                className="h-12 rounded-2xl border-white/10 bg-white/5 px-5 text-sm placeholder:text-zinc-600 focus:border-sage/50"
                {...register('referralCode')}
              />
            </div>

            <Button
              type="submit"
              disabled={loading}
              className="h-14 w-full rounded-full bg-sage text-base font-semibold text-black shadow-[0_0_40px_rgba(207,225,185,0.25)] hover:bg-sage/90 disabled:opacity-50"
            >
              {loading ? 'Joining…' : 'Join the Waitlist'}
            </Button>
          </form>

          <div className="flex items-center gap-3">
            <Button
              variant="ghost"
              size="sm"
              onClick={onBack}
              className="text-zinc-500 hover:text-zinc-300"
            >
              ← Back
            </Button>
            <p className="text-xs text-zinc-600">
              No spam. Unsubscribe anytime.
            </p>
          </div>
        </motion.div>
      ) : (
        <SuccessPanel data={success} />
      )}
    </AnimatePresence>
  );
}

// ─── Success panel ────────────────────────────────────────────────────────────

function SuccessPanel({ data }: { data: SuccessData }) {
  const referralUrl = getReferralUrl(data.referralCode);
  const { twitter, generic } = buildShareText(data.position, referralUrl);
  const isFoundingMember = data.tier === 'founding_30';

  function copyLink() {
    navigator.clipboard.writeText(referralUrl).then(() => toast.success('Link copied!'));
  }

  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.95 }}
      animate={{ opacity: 1, scale: 1 }}
      transition={{ duration: 0.4, ease: 'easeOut' }}
      className="flex flex-col items-center gap-6 text-center"
    >
      {/* Confetti-like emoji */}
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
          You're #{data.position}!
        </h2>
        <p className="text-zinc-400">
          {isFoundingMember
            ? "You're one of the first 30 — Founding Member status locked in."
            : 'Share your link to move up the list.'}
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
  );
}
