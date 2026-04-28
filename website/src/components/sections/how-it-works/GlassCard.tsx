"use client";

import { motion, AnimatePresence } from "framer-motion";
import type { Step } from "./constants";

interface GlassCardProps {
  step: Step;
  stepIndex: number;
  isVisible: boolean;
}

export function GlassCard({ step, stepIndex, isVisible }: GlassCardProps) {
  return (
    <AnimatePresence mode="wait">
      {isVisible && (
        <motion.div
          key={step.id}
          initial={{ opacity: 0, y: 24, filter: "blur(8px)" }}
          animate={{ opacity: 1, y: 0, filter: "blur(0px)" }}
          exit={{ opacity: 0, y: -24, filter: "blur(8px)" }}
          transition={{ duration: 0.6, ease: [0.16, 1, 0.3, 1] }}
          className="pointer-events-none absolute bottom-8 left-1/2 z-30 w-[320px] -translate-x-1/2 sm:bottom-12 sm:w-[380px]"
        >
          <div
            className="rounded-2xl px-6 py-5"
            style={{
              backgroundColor: "rgba(22, 22, 24, 0.75)",
              backdropFilter: "blur(16px)",
              WebkitBackdropFilter: "blur(16px)",
              border: `1px solid rgba(207, 225, 185, 0.12)`,
              boxShadow: `0 8px 32px rgba(0,0,0,0.3), 0 0 0 1px rgba(207,225,185,0.04), 0 0 60px ${step.accent}08`,
            }}
          >
            {/* Step badge */}
            <div
              className="mb-3 inline-flex items-center gap-1.5 rounded-full px-3 py-1"
              style={{
                backgroundColor: `${step.accent}15`,
                border: `1px solid ${step.accent}25`,
              }}
            >
              <span className="text-[11px] font-bold" style={{ color: step.accent }}>
                {stepIndex + 1}
              </span>
              <span className="text-[10px] font-semibold" style={{ color: step.accent }}>
                {step.label}
              </span>
            </div>

            {/* Headline */}
            <h3
              className="mb-2 text-xl font-bold tracking-tight sm:text-2xl"
              style={{ color: "#F0EEE9", fontFamily: "var(--font-jakarta)" }}
            >
              {step.headline}
            </h3>

            {/* Description */}
            <p className="text-sm leading-relaxed" style={{ color: "#9B9894" }}>
              {step.description}
            </p>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
