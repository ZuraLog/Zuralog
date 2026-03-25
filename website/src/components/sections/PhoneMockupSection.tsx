/**
 * PhoneMockupSection — standalone section showcasing the iPhone mockup
 * with the Zuralog chat interface preview.
 *
 * Scroll-driven background: subtle sage-tinted video texture that fades in
 * as you enter, giving the section atmosphere instead of flat cream.
 */
'use client';

import { motion } from 'framer-motion';
import { IPhoneMockup } from '@/components/iphone-mockup';

export function PhoneMockupSection() {
  return (
    <section
      id="phone-mockup-section"
      className="relative py-16 md:py-24 overflow-hidden"
      style={{ backgroundColor: "transparent" }}
    >
      {/* Sage glow behind phone */}
      <div className="pointer-events-none absolute inset-0">
        <div className="absolute left-1/2 top-1/2 h-[500px] w-[500px] -translate-x-1/2 -translate-y-1/2 rounded-full blur-[120px]" style={{ backgroundColor: "rgba(207, 225, 185, 0.12)" }} />
      </div>

      <div className="relative mx-auto max-w-4xl px-6">
        {/* Header */}
        <motion.div
          initial={{ opacity: 0, y: 20, filter: "blur(8px)" }}
          whileInView={{ opacity: 1, y: 0, filter: "blur(0px)" }}
          viewport={{ once: true }}
          transition={{ duration: 0.8, ease: [0.16, 1, 0.3, 1] }}
          className="mb-12 text-center"
        >
          <motion.span
            initial={{ opacity: 0, scale: 0.9 }}
            whileInView={{ opacity: 1, scale: 1 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5, delay: 0.1 }}
            className="mb-4 inline-flex items-center gap-2 rounded-full px-4 py-1.5 text-xs font-semibold uppercase tracking-widest"
            style={{ backgroundColor: "rgba(52, 78, 65, 0.06)", border: "1px solid rgba(52, 78, 65, 0.10)", color: "rgba(52, 78, 65, 0.55)" }}
          >
            <span className="h-1.5 w-1.5 rounded-full bg-[#344E41] animate-pulse" />
            Preview
          </motion.span>

          <h2 className="mt-4 text-3xl font-bold sm:text-4xl md:text-5xl tracking-tight" style={{ color: "#1A2E22" }}>
            Your health, one conversation away
          </h2>
          <p className="mx-auto mt-4 max-w-lg text-base" style={{ color: "rgba(52, 78, 65, 0.50)" }}>
            Chat with Zuralog to get real-time insights from all your connected health apps — sleep, heart rate, stress, and more.
          </p>
        </motion.div>

        {/* Phone mockup centered */}
        <motion.div
          initial={{ opacity: 0, y: 30, scale: 0.95, filter: "blur(6px)" }}
          whileInView={{ opacity: 1, y: 0, scale: 1, filter: "blur(0px)" }}
          viewport={{ once: true }}
          transition={{ duration: 0.9, delay: 0.2, ease: [0.16, 1, 0.3, 1] }}
          className="flex justify-center"
        >
          <IPhoneMockup />
        </motion.div>
      </div>
    </section>
  );
}
