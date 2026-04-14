/**
 * WaitlistForm — email signup form (Step 0 in the quiz flow).
 * Shown first before quiz questions. Peach-themed for website.
 */
'use client';

import { useState, useEffect, useRef } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { motion } from 'framer-motion';
import { toast } from 'sonner';
import { usePostHog } from 'posthog-js/react';
import ReCAPTCHA from 'react-google-recaptcha';
import { DSButton, TextField } from '@/components/design-system';
import { useSoundContext } from "@/components/design-system/interactions/sound-provider";
import { useMagnetic } from "@/hooks/use-magnetic";
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
  const { playSound } = useSoundContext();
  const magnetRef = useMagnetic<HTMLDivElement>();
  const [loading, setLoading] = useState(false);
  const [urlRef, setUrlRef] = useState('');
  const recaptchaRef = useRef<ReCAPTCHA>(null);
  const [captchaToken, setCaptchaToken] = useState<string | null>(null);
  const posthog = usePostHog();

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
    playSound("click");
    setLoading(true);
    try {
      const res = await fetch('/api/waitlist/join', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: data.email,
          referralCode: data.referralCode || urlRef || null,
          quizAnswers: { apps: [], frustrations: [], goal: '' },
          captchaToken,
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
        // Track successful new waitlist signup client-side
        posthog?.capture("waitlist_joined", {
          referral_code: data.referralCode || urlRef || null,
          position: json.position,
        });
      }

      playSound("success");
      onSignupSuccess({
        position: json.position,
        referralCode: json.referralCode,
        tier: json.tier,
      });
    } catch {
      toast.error('Network error. Please try again.');
    } finally {
      recaptchaRef.current?.reset();
      setCaptchaToken(null);
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
        <p className="mt-2 text-[#6B6864]">
          Enter your email to join — then answer 3 quick questions so we can personalise your experience.
        </p>
      </div>

      <form onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-4">
        <TextField
          type="email"
          placeholder="your@email.com"
          autoComplete="email"
          fullWidth
          className="bg-[#F0EEE9] h-14 w-full rounded-[14px]"
          error={errors.email?.message}
          {...register('email')}
        />

        <TextField
          type="text"
          placeholder="Referral code (optional)"
          defaultValue={urlRef}
          fullWidth
          className="bg-[#F0EEE9] h-12 w-full rounded-[14px]"
          {...register('referralCode')}
        />

        <div className="flex justify-center">
          <ReCAPTCHA
            ref={recaptchaRef}
            sitekey={process.env.NEXT_PUBLIC_RECAPTCHA_SITE_KEY!}
            onChange={(token) => setCaptchaToken(token)}
            onExpired={() => setCaptchaToken(null)}
            onErrored={() => setCaptchaToken(null)}
            theme="light"
            size="normal"
          />
        </div>

        <div ref={magnetRef}>
          <DSButton
            type="submit"
            intent="primary"
            size="lg"
            disabled={!captchaToken}
            loading={loading}
            className="w-full"
          >
            Join & Tell Us About Yourself →
          </DSButton>
        </div>
      </form>

      <p className="text-center text-xs text-[#6B6864]">
        No spam. Unsubscribe anytime. 30 seconds to complete.
      </p>

    </motion.div>
  );
}
