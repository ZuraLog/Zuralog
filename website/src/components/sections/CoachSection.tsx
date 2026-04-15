// website/src/components/sections/CoachSection.tsx
"use client";

import { motion } from "framer-motion";
import { PhoneMockup } from "@/components/phone";
import { CoachScreen } from "@/components/phone/screens/CoachScreen";
import { useCursorParallax } from "@/hooks/use-cursor-parallax";

export function CoachSection() {
  const headlineCursorRef = useCursorParallax<HTMLDivElement>({ depth: 0.4 });
  const phoneCursorRef = useCursorParallax<HTMLDivElement>({ depth: 0.7 });

  return (
    <section className="relative pt-12 pb-24 md:pt-16 md:pb-32 px-6 md:px-12 font-jakarta">
      <div className="mx-auto max-w-6xl">

        {/* ── Section header ─────────────────────────────────── */}
        <div ref={headlineCursorRef} className="will-change-transform">
          <motion.div
            initial={{ opacity: 0, y: 24 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.6 }}
            className="text-center mb-12 md:mb-16"
          >
            <span className="inline-flex items-center gap-2 rounded-full border border-[#344E41]/30 bg-[#344E41]/[0.07] px-4 py-1.5 text-xs font-semibold uppercase tracking-widest text-[#344E41] mb-6">
              <span className="h-1.5 w-1.5 rounded-full bg-[#344E41]" />
              Meet Zura
            </span>

            <h2
              className="font-bold uppercase tracking-tighter leading-[0.9] text-[#161618]"
              style={{ fontSize: "clamp(3rem, 6vw, 6.5rem)" }}
            >
              Your health, finally
              <br />
              <span
                className="ds-pattern-text"
                style={{ backgroundImage: "var(--ds-pattern-sage)" }}
              >
                understood.
              </span>
            </h2>

            <p className="mt-5 text-lg text-[#6B6864] max-w-lg mx-auto leading-relaxed">
              One AI coach that connects every dot, across every metric you track.
            </p>
          </motion.div>
        </div>

        {/* ── Centered phone ─────────────────────────────────── */}
        <motion.div
          initial={{ opacity: 0, y: 40 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.7, delay: 0.15, ease: "easeOut" }}
          className="flex justify-center"
        >
          <motion.div
            ref={phoneCursorRef}
            className="will-change-transform"
            whileHover={{ scale: 1.02, y: -6 }}
            transition={{ duration: 0.3, ease: "easeOut" }}
          >
            <PhoneMockup frameWidth={380}>
              <CoachScreen />
            </PhoneMockup>
          </motion.div>
        </motion.div>

      </div>
    </section>
  );
}
