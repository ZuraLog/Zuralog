/**
 * WaitlistSection — full-page quiz + signup section.
 *
 * This is the primary conversion section. It contains:
 * - Section header with social proof
 * - QuizContainer (steps + form)
 * - Leaderboard sidebar (desktop only)
 */
'use client';

import { motion } from 'framer-motion';
import { QuizContainer } from '@/components/quiz/quiz-container';
import { WaitlistStatsBar } from '@/components/waitlist-stats-bar';
import { WaitlistParticles } from '@/components/waitlist-particles';
import { IPhoneMockup } from '@/components/iphone-mockup';

/**
 * Full waitlist section with quiz funnel and iPhone app preview.
 */
export function WaitlistSection() {

  return (
    <section
      id="waitlist"
      className="relative min-h-screen bg-black py-24 md:py-32"
    >
      {/* Background gradient glow */}
      <div className="pointer-events-none absolute inset-0 overflow-hidden">
        <div className="absolute left-1/2 top-1/2 h-[600px] w-[600px] -translate-x-1/2 -translate-y-1/2 rounded-full bg-sage/5 blur-[120px]" />
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
          <h2 className="font-display text-3xl font-bold text-white sm:text-4xl md:text-5xl">
            Join the waitlist
          </h2>
          <p className="mx-auto mt-4 max-w-xl text-zinc-400">
            Secure your spot first — then answer 3 quick questions so we can
            personalize your experience before we launch.
          </p>
        </motion.div>

        {/* Animated stats counters */}
        <WaitlistStatsBar />

        {/* Main layout */}
        <div className="flex flex-col items-center gap-10 lg:flex-row lg:items-start lg:justify-between lg:gap-12">
          {/* Quiz (left / main) */}
          <motion.div
            initial={{ opacity: 0, x: -24 }}
            whileInView={{ opacity: 1, x: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.6, delay: 0.1 }}
            className="w-full lg:max-w-xl"
          >
            <QuizContainer />
          </motion.div>

          {/* iPhone mockup */}
          <div className="py-4 lg:py-0">
            <IPhoneMockup />
          </div>
        </div>
      </div>
    </section>
  );
}
