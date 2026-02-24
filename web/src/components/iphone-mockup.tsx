/**
 * IPhoneMockup — CSS-only iPhone frame displaying a simulated app screen.
 *
 * Shows a realistic health AI chat interface inside an iPhone 15 Pro frame.
 * Purely decorative — no interactivity.
 */
'use client';

import { motion } from 'framer-motion';
import Image from 'next/image';

/**
 * Renders a CSS iPhone frame with a mock Zuralog app screen inside.
 */
export function IPhoneMockup() {
  return (
    <motion.div
      initial={{ opacity: 0, x: 40, rotateY: -8 }}
      whileInView={{ opacity: 1, x: 0, rotateY: 0 }}
      viewport={{ once: true }}
      transition={{ duration: 0.8, delay: 0.3, ease: 'easeOut' }}
      className="relative mx-auto w-[240px] shrink-0 sm:w-[260px] md:w-[280px]"
      style={{ perspective: '1200px' }}
    >
      {/* Glow behind phone */}
      <div className="absolute -inset-8 rounded-full bg-sage/8 blur-[60px]" />

      {/* iPhone frame */}
      <div className="relative overflow-hidden rounded-[3rem] border-[3px] border-zinc-700 bg-black shadow-2xl shadow-sage/10">
        {/* Dynamic Island */}
        <div className="absolute left-1/2 top-3 z-20 h-[22px] w-[90px] -translate-x-1/2 rounded-full bg-black" />

        {/* Screen content */}
        <div className="relative bg-black px-1 pb-1 pt-1">
          <div className="overflow-hidden rounded-[2.7rem] bg-[#0a0a0a]">
            {/* Status bar */}
            <div className="flex items-center justify-between px-8 pb-1 pt-4 text-[10px] font-semibold text-white">
              <span>9:41</span>
              <div className="flex items-center gap-1">
                <svg width="14" height="10" viewBox="0 0 14 10" fill="white">
                  <rect x="0" y="6" width="2.5" height="4" rx="0.5" />
                  <rect x="3.5" y="4" width="2.5" height="6" rx="0.5" />
                  <rect x="7" y="2" width="2.5" height="8" rx="0.5" />
                  <rect x="10.5" y="0" width="2.5" height="10" rx="0.5" />
                </svg>
                <svg width="14" height="10" viewBox="0 0 24 12" fill="white">
                  <rect x="0" y="1" width="20" height="10" rx="2" stroke="white" strokeWidth="1.5" fill="none" />
                  <rect x="21" y="4" width="2" height="4" rx="1" />
                  <rect x="2" y="3" width="14" height="6" rx="1" fill="white" />
                </svg>
              </div>
            </div>

            {/* App header */}
            <div className="flex items-center gap-2 px-5 pb-3 pt-2">
              <div className="relative h-8 w-8">
                <Image
                  src="/logo.svg"
                  alt="Zuralog"
                  width={32}
                  height={32}
                  className="rounded-lg"
                />
              </div>
              <div>
                <p className="text-[11px] font-semibold text-white">Zuralog</p>
                <p className="text-[9px] text-sage">Online</p>
              </div>
            </div>

            {/* Divider */}
            <div className="mx-4 h-px bg-white/8" />

            {/* Chat messages */}
            <div className="flex flex-col gap-2.5 px-4 py-4">
              {/* AI message */}
              <div className="max-w-[85%] rounded-2xl rounded-tl-sm bg-white/8 px-3 py-2">
                <p className="text-[10px] leading-relaxed text-zinc-300">
                  Good morning! You slept 7h 42m last night. Your deep sleep was up 12% from last week.
                </p>
              </div>

              {/* AI follow-up */}
              <div className="max-w-[85%] rounded-2xl rounded-tl-sm bg-white/8 px-3 py-2">
                <p className="text-[10px] leading-relaxed text-zinc-300">
                  Your resting heart rate has been trending down — nice work on the evening walks.
                </p>
              </div>

              {/* User message */}
              <div className="ml-auto max-w-[75%] rounded-2xl rounded-br-sm bg-sage/20 px-3 py-2">
                <p className="text-[10px] leading-relaxed text-sage">
                  How are my stress levels?
                </p>
              </div>

              {/* AI response */}
              <div className="max-w-[85%] rounded-2xl rounded-tl-sm bg-white/8 px-3 py-2">
                <p className="text-[10px] leading-relaxed text-zinc-300">
                  HRV shows you recovered well. Your stress score is{' '}
                  <span className="font-semibold text-sage">24 — low</span>. Keep it up!
                </p>
              </div>

              {/* Health card */}
              <div className="rounded-xl border border-sage/20 bg-sage/5 p-2.5">
                <p className="mb-1 text-[9px] font-semibold uppercase tracking-wider text-sage/70">
                  Today&apos;s Summary
                </p>
                <div className="grid grid-cols-3 gap-2">
                  <div className="text-center">
                    <p className="text-[13px] font-bold text-sage">7.7k</p>
                    <p className="text-[8px] text-zinc-500">Steps</p>
                  </div>
                  <div className="text-center">
                    <p className="text-[13px] font-bold text-sage">62</p>
                    <p className="text-[8px] text-zinc-500">BPM</p>
                  </div>
                  <div className="text-center">
                    <p className="text-[13px] font-bold text-sage">24</p>
                    <p className="text-[8px] text-zinc-500">Stress</p>
                  </div>
                </div>
              </div>

              {/* Typing indicator */}
              <div className="flex items-center gap-1 px-1">
                <div className="flex gap-0.5">
                  <span className="h-1 w-1 animate-pulse rounded-full bg-sage/50" />
                  <span className="h-1 w-1 animate-pulse rounded-full bg-sage/50 [animation-delay:150ms]" />
                  <span className="h-1 w-1 animate-pulse rounded-full bg-sage/50 [animation-delay:300ms]" />
                </div>
                <span className="text-[9px] text-zinc-600">Zuralog is typing...</span>
              </div>
            </div>

            {/* Input bar */}
            <div className="mx-3 mb-4 flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-3 py-2">
              <p className="flex-1 text-[10px] text-zinc-600">Ask anything...</p>
              <div className="flex h-5 w-5 items-center justify-center rounded-full bg-sage">
                <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="black" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
                  <line x1="12" y1="19" x2="12" y2="5" />
                  <polyline points="5 12 12 5 19 12" />
                </svg>
              </div>
            </div>

            {/* Home indicator */}
            <div className="mx-auto mb-2 h-1 w-28 rounded-full bg-white/20" />
          </div>
        </div>
      </div>
    </motion.div>
  );
}
