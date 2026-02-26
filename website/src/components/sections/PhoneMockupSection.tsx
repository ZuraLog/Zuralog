/**
 * PhoneMockupSection — standalone section showcasing the iPhone mockup
 * with the Zuralog chat interface preview.
 */
'use client';

import { motion } from 'framer-motion';
import { IPhoneMockup } from '@/components/iphone-mockup';

export function PhoneMockupSection() {
  return (
    <section className="relative py-16 md:py-24 overflow-hidden">
      {/* Subtle background glow */}
      <div className="pointer-events-none absolute inset-0">
        <div className="absolute left-1/2 top-1/2 h-[500px] w-[500px] -translate-x-1/2 -translate-y-1/2 rounded-full bg-sage/10 blur-[120px]" />
      </div>

      <div className="relative mx-auto max-w-4xl px-6">
        {/* Header */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          className="mb-12 text-center"
        >
          <motion.span
            initial={{ opacity: 0, scale: 0.9 }}
            whileInView={{ opacity: 1, scale: 1 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5, delay: 0.1 }}
            className="mb-4 inline-flex items-center gap-2 rounded-full border border-sage/30 bg-sage/10 px-4 py-1.5 text-xs font-semibold uppercase tracking-widest text-dark-charcoal/60"
          >
            <span className="h-1.5 w-1.5 rounded-full bg-sage animate-pulse" />
            Preview
          </motion.span>

          <h2 className="mt-4 text-3xl font-bold text-dark-charcoal sm:text-4xl md:text-5xl tracking-tight">
            Your health, one conversation away
          </h2>
          <p className="mx-auto mt-4 max-w-lg text-black/45 text-base">
            Chat with Zuralog to get real-time insights from all your connected health apps — sleep, heart rate, stress, and more.
          </p>
        </motion.div>

        {/* Phone mockup centered */}
        <motion.div
          initial={{ opacity: 0, y: 30, scale: 0.95 }}
          whileInView={{ opacity: 1, y: 0, scale: 1 }}
          viewport={{ once: true }}
          transition={{ duration: 0.7, delay: 0.2, ease: 'easeOut' }}
          className="flex justify-center"
        >
          <IPhoneMockup />
        </motion.div>
      </div>
    </section>
  );
}
