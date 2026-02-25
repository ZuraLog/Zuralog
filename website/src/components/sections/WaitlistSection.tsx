/**
 * WaitlistSection — full-page quiz + signup section for website/.
 *
 * Cream background (#FAFAF5) with peach (#FFAB76) accent.
 * Layout: stats bar at top, then quiz (left) + iPhone mockup (right).
 * Includes all easter eggs from web/ (connect4, etc.).
 */
'use client';

import { useState, useCallback } from 'react';
import { motion } from 'framer-motion';
import { QuizContainer } from '@/components/quiz/quiz-container';
import { WaitlistStatsBar } from '@/components/waitlist-stats-bar';
import { WaitlistParticles } from '@/components/waitlist-particles';
import { IPhoneMockup } from '@/components/iphone-mockup';
import { Toaster } from 'sonner';

export function WaitlistSection() {
  const [emailValue, setEmailValue] = useState('');
  const handleEmailChange = useCallback((value: string) => setEmailValue(value), []);

  return (
    <section
      id="waitlist"
      className="relative min-h-screen py-16 md:py-24 lg:py-32 overflow-hidden"
    >
      <Toaster position="top-center" richColors />

      {/* Subtle lime glow + particles */}
      <div className="pointer-events-none absolute inset-0">
        <div className="absolute left-1/2 top-1/2 h-[600px] w-[600px] -translate-x-1/2 -translate-y-1/2 rounded-full bg-primary-lime/10 blur-[140px]" />
        <WaitlistParticles />
      </div>

      <div className="relative mx-auto max-w-6xl px-6">
        {/* Section header */}
        <motion.div
          initial={{ opacity: 0, y: 24 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          className="mb-10 text-center md:mb-16"
        >
          {/* Eyebrow */}
          <motion.span
            initial={{ opacity: 0, scale: 0.9 }}
            whileInView={{ opacity: 1, scale: 1 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5, delay: 0.1 }}
            className="mb-4 inline-flex items-center gap-2 rounded-full border border-primary-lime/40 bg-primary-lime/15 px-4 py-1.5 text-xs font-semibold uppercase tracking-widest text-dark-charcoal/70"
          >
            <span className="h-1.5 w-1.5 rounded-full bg-accent-lime animate-pulse" />
            Early Access
          </motion.span>

          <h2 className="mt-4 text-4xl font-bold text-dark-charcoal sm:text-5xl md:text-6xl tracking-tight">
            Join the waitlist
          </h2>
          <p className="mx-auto mt-4 max-w-xl text-black/50 text-lg">
            Secure your spot first — then answer 3 quick questions so we can
            personalise your experience before launch.
          </p>
        </motion.div>

        {/* Animated stats counters */}
        <WaitlistStatsBar />

        {/* Main layout: quiz left, phone right */}
        <div className="flex flex-col items-center gap-10 lg:flex-row lg:items-start lg:justify-between lg:gap-16">
          {/* Quiz (left / main) */}
          <motion.div
            initial={{ opacity: 0, x: -24 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.6, delay: 0.1 }}
            className="w-full lg:max-w-xl"
          >
            <QuizContainer onEmailChange={handleEmailChange} />
          </motion.div>

          {/* iPhone mockup (right) */}
          <div className="w-full flex justify-center py-4 lg:w-auto lg:justify-start lg:py-0 lg:sticky lg:top-32">
            <IPhoneMockup emailValue={emailValue} />
          </div>
        </div>
      </div>
    </section>
  );
}
