/**
 * WaitlistForm — email signup form (Step 0 in the new flow).
 *
 * This is shown FIRST before any quiz questions.
 * On success, calls onSignupSuccess() to advance to quiz questions.
 * The success/referral panel is shown at the end of the quiz (in CompletionStep).
 */
'use client';

import { useState, useEffect } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { motion } from 'framer-motion';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import type { SuccessData } from '@/hooks/use-quiz';

const schema = z.object({
  email: z.email('Enter a valid email address'),
  referralCode: z.string().optional(),
});
type FormData = z.infer<typeof schema>;

interface WaitlistFormProps {
  /** Called after successful email signup; advances to quiz steps */
  onSignupSuccess: (data: SuccessData) => void;
}

/**
 * First-step email signup form. On success, passes data up to advance to quiz.
 */
export function WaitlistForm({ onSignupSuccess }: WaitlistFormProps) {
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
          // Quiz answers not available yet — will be empty; update via separate call if needed
          quizAnswers: { apps: [], frustrations: [], goal: '' },
        }),
      });
      const json = await res.json();

      if (!res.ok) {
        toast.error(json.error ?? 'Something went wrong. Please try again.');
        return;
      }

      if (json.alreadyJoined) {
        toast.info("You're already on the waitlist! Tell us more about yourself.");
      } else {
        toast.success("You're on the waitlist! Now tell us about yourself.");
      }

      onSignupSuccess({
        position: json.position,
        referralCode: json.referralCode,
        tier: json.tier,
      });
    } catch {
      toast.error('Network error. Please try again.');
    } finally {
      setLoading(false);
    }
  }

  return (
    <motion.div
      key="form"
      initial={{ opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -16 }}
      transition={{ duration: 0.4 }}
      className="flex flex-col gap-6"
    >
      <div>
        <h2 className="font-display text-2xl font-bold text-white md:text-3xl">
          Secure your spot
        </h2>
        <p className="mt-2 text-zinc-400">
          Enter your email to join — then answer 3 quick questions so we can personalize your experience.
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
          {loading ? 'Joining…' : 'Join & Tell Us About Yourself →'}
        </Button>
      </form>

      <p className="text-center text-xs text-zinc-600">
        No spam. Unsubscribe anytime. 30 seconds to complete.
      </p>
    </motion.div>
  );
}
