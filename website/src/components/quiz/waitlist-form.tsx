/**
 * WaitlistForm — email signup form (Step 0 in the quiz flow).
 * Shown first before quiz questions. Peach-themed for website.
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
  onSignupSuccess: (data: SuccessData) => void;
  onEmailChange?: (value: string) => void;
}

export function WaitlistForm({ onSignupSuccess, onEmailChange }: WaitlistFormProps) {
  const [loading, setLoading] = useState(false);
  const [urlRef, setUrlRef] = useState('');

  useEffect(() => {
    const ref = new URLSearchParams(window.location.search).get('ref') ?? '';
    setUrlRef(ref);
  }, []);

  const {
    register,
    handleSubmit,
    watch,
    formState: { errors },
  } = useForm<FormData>({ resolver: zodResolver(schema) });

  const emailValue = watch('email');
  useEffect(() => {
    onEmailChange?.(emailValue ?? '');
  }, [emailValue, onEmailChange]);

  async function onSubmit(data: FormData) {
    setLoading(true);
    try {
      const res = await fetch('/api/waitlist/join', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: data.email,
          referralCode: data.referralCode || urlRef || null,
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
        <h2 className="text-2xl font-bold text-dark-charcoal md:text-3xl">
          Secure your spot
        </h2>
        <p className="mt-2 text-black/50">
          Enter your email to join — then answer 3 quick questions so we can personalise your experience.
        </p>
      </div>

      <form onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-4">
        <div className="flex flex-col gap-1.5">
          <Input
            type="email"
            placeholder="your@email.com"
            autoComplete="email"
            className="h-14 rounded-2xl border-black/10 bg-white px-5 text-base placeholder:text-black/30 focus:border-peach/50 focus:ring-2 focus:ring-peach/20 shadow-sm"
            {...register('email')}
          />
          {errors.email && (
            <p className="text-sm text-red-500">{errors.email.message}</p>
          )}
        </div>

        <div className="flex flex-col gap-1.5">
          <Input
            type="text"
            placeholder="Referral code (optional)"
            defaultValue={urlRef}
            className="h-12 rounded-2xl border-black/10 bg-white px-5 text-sm placeholder:text-black/30 shadow-sm"
            {...register('referralCode')}
          />
        </div>

        <Button
          type="submit"
          disabled={loading}
          className={`h-14 w-full rounded-full bg-peach text-base font-semibold text-white transition-all duration-300 hover:bg-peach-dim hover:scale-[1.02] hover:shadow-[0_0_40px_rgba(207,225,185,0.55)] active:scale-[0.98] disabled:opacity-50 ${
            loading
              ? 'animate-pulse shadow-[0_0_30px_rgba(207,225,185,0.45)]'
              : 'shadow-[0_0_20px_rgba(207,225,185,0.30)]'
          }`}
        >
          {loading ? 'Joining…' : 'Join & Tell Us About Yourself →'}
        </Button>
      </form>

      <p className="text-center text-xs text-black/30">
        No spam. Unsubscribe anytime. 30 seconds to complete.
      </p>

      {/* Easter egg hint */}
      <motion.p
        initial={{ opacity: 0 }}
        animate={{ opacity: [0, 0.7, 0, 0.5, 0, 0.8, 0] }}
        transition={{ delay: 3, duration: 2.5, repeat: Infinity, repeatDelay: 2.5 }}
        className="text-center font-mono text-[11px] tracking-widest text-peach/60 select-none"
      >
        psst... try connect4
      </motion.p>
    </motion.div>
  );
}
