/**
 * IPhoneMockup — CSS-only iPhone frame displaying a simulated Zuralog app screen.
 *
 * Peach-themed chat interface. Easter egg: type "connect4" in the email field
 * to replace the chat with a playable Connect 4 game.
 */
'use client';

import { motion, AnimatePresence } from 'framer-motion';
import Image from 'next/image';
import dynamic from 'next/dynamic';

const Connect4Game = dynamic(
  () => import('@/components/connect4-game').then((m) => m.Connect4Game),
  { ssr: false },
);

interface IPhoneMockupProps {
  emailValue?: string;
}

export function IPhoneMockup({ emailValue = '' }: IPhoneMockupProps) {
  const showConnect4 = emailValue.toLowerCase() === 'connect4';

  return (
    <motion.div
      initial={{ opacity: 0, x: 40, rotateY: -8 }}
      whileInView={{ opacity: 1, x: 0, rotateY: 0 }}
      viewport={{ once: true }}
      transition={{ duration: 0.8, delay: 0.3, ease: 'easeOut' }}
      className="relative mx-auto w-[240px] shrink-0 sm:w-[260px] md:w-[280px]"
      style={{ perspective: '1200px' }}
    >
      {/* Soft peach glow behind phone */}
      <div className="absolute -inset-8 rounded-full bg-peach/15 blur-[60px]" />

      {/* iPhone frame */}
      <div className="relative overflow-hidden rounded-[3rem] border-[3px] border-black/10 bg-white shadow-2xl shadow-peach/20">
        {/* Dynamic Island */}
        <div className="absolute left-1/2 top-3 z-20 h-[22px] w-[90px] -translate-x-1/2 rounded-full bg-dark-charcoal" />

        {/* Screen */}
        <div className="relative bg-white px-1 pb-1 pt-1">
          <div className="overflow-hidden rounded-[2.7rem] bg-[#FAFAF5]">
            <AnimatePresence mode="wait">
              {showConnect4 ? (
                <motion.div
                  key="connect4"
                  initial={{ opacity: 0, scale: 0.95 }}
                  animate={{ opacity: 1, scale: 1 }}
                  exit={{ opacity: 0, scale: 0.95 }}
                  transition={{ duration: 0.3 }}
                  className="flex flex-col"
                  style={{ minHeight: 460 }}
                >
                  <Connect4Game />
                </motion.div>
              ) : (
                <motion.div
                  key="chat"
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  exit={{ opacity: 0 }}
                  transition={{ duration: 0.3 }}
                >
                  {/* Status bar */}
                  <div className="flex items-center justify-between px-8 pb-1 pt-4 text-[10px] font-semibold text-dark-charcoal">
                    <span>9:41</span>
                    <div className="flex items-center gap-1">
                      <svg width="14" height="10" viewBox="0 0 14 10" fill="currentColor" className="text-dark-charcoal">
                        <rect x="0" y="6" width="2.5" height="4" rx="0.5" />
                        <rect x="3.5" y="4" width="2.5" height="6" rx="0.5" />
                        <rect x="7" y="2" width="2.5" height="8" rx="0.5" />
                        <rect x="10.5" y="0" width="2.5" height="10" rx="0.5" />
                      </svg>
                      <svg width="14" height="10" viewBox="0 0 24 12" fill="currentColor" className="text-dark-charcoal">
                        <rect x="0" y="1" width="20" height="10" rx="2" stroke="currentColor" strokeWidth="1.5" fill="none" />
                        <rect x="21" y="4" width="2" height="4" rx="1" />
                        <rect x="2" y="3" width="14" height="6" rx="1" />
                      </svg>
                    </div>
                  </div>

                  {/* App header */}
                  <div className="flex items-center gap-2 px-5 pb-3 pt-2">
                    <div className="relative h-8 w-8">
                      <Image
                        src="/logo/Zuralog.png"
                        alt="Zuralog"
                        width={32}
                        height={32}
                        className="rounded-lg"
                      />
                    </div>
                    <div>
                      <p className="text-[11px] font-semibold text-dark-charcoal">Zuralog</p>
                      <p className="text-[9px] text-peach">Online</p>
                    </div>
                  </div>

                  {/* Divider */}
                  <div className="mx-4 h-px bg-black/5" />

                  {/* Chat messages */}
                  <div className="flex flex-col gap-2.5 px-4 py-4">
                    {/* AI message */}
                    <div className="max-w-[85%] rounded-2xl rounded-tl-sm bg-black/5 px-3 py-2">
                      <p className="text-[10px] leading-relaxed text-dark-charcoal/80">
                        Good morning! You slept 7h 42m last night. Your deep sleep was up 12% from last week.
                      </p>
                    </div>

                    {/* AI follow-up */}
                    <div className="max-w-[85%] rounded-2xl rounded-tl-sm bg-black/5 px-3 py-2">
                      <p className="text-[10px] leading-relaxed text-dark-charcoal/80">
                        Your resting heart rate has been trending down — nice work on the evening walks.
                      </p>
                    </div>

                    {/* User message */}
                    <div className="ml-auto max-w-[75%] rounded-2xl rounded-br-sm bg-peach/20 px-3 py-2">
                      <p className="text-[10px] leading-relaxed text-peach-dim">
                        How are my stress levels?
                      </p>
                    </div>

                    {/* AI response */}
                    <div className="max-w-[85%] rounded-2xl rounded-tl-sm bg-black/5 px-3 py-2">
                      <p className="text-[10px] leading-relaxed text-dark-charcoal/80">
                        HRV shows you recovered well. Your stress score is{' '}
                        <span className="font-semibold text-peach-dim">24 — low</span>. Keep it up!
                      </p>
                    </div>

                    {/* Health summary card */}
                    <div className="rounded-xl border border-peach/20 bg-peach/8 p-2.5">
                      <p className="mb-1 text-[9px] font-semibold uppercase tracking-wider text-peach-dim/70">
                        Today&apos;s Summary
                      </p>
                      <div className="grid grid-cols-3 gap-2">
                        <div className="text-center">
                          <p className="text-[13px] font-bold text-peach-dim">7.7k</p>
                          <p className="text-[8px] text-black/40">Steps</p>
                        </div>
                        <div className="text-center">
                          <p className="text-[13px] font-bold text-peach-dim">62</p>
                          <p className="text-[8px] text-black/40">BPM</p>
                        </div>
                        <div className="text-center">
                          <p className="text-[13px] font-bold text-peach-dim">24</p>
                          <p className="text-[8px] text-black/40">Stress</p>
                        </div>
                      </div>
                    </div>

                    {/* Typing indicator */}
                    <div className="flex items-center gap-1 px-1">
                      <div className="flex gap-0.5">
                        <span className="h-1 w-1 animate-pulse rounded-full bg-peach/50" />
                        <span className="h-1 w-1 animate-pulse rounded-full bg-peach/50 [animation-delay:150ms]" />
                        <span className="h-1 w-1 animate-pulse rounded-full bg-peach/50 [animation-delay:300ms]" />
                      </div>
                      <span className="text-[9px] text-black/30">Zuralog is typing...</span>
                    </div>
                  </div>

                  {/* Input bar */}
                  <div className="mx-3 mb-4 flex items-center gap-2 rounded-full border border-black/8 bg-white px-3 py-2 shadow-sm">
                    <p className="flex-1 text-[10px] text-black/30">Ask anything...</p>
                    <div className="flex h-5 w-5 items-center justify-center rounded-full bg-peach">
                      <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
                        <line x1="12" y1="19" x2="12" y2="5" />
                        <polyline points="5 12 12 5 19 12" />
                      </svg>
                    </div>
                  </div>

                  {/* Home indicator */}
                  <div className="mx-auto mb-2 h-1 w-28 rounded-full bg-black/10" />
                </motion.div>
              )}
            </AnimatePresence>
          </div>
        </div>
      </div>
    </motion.div>
  );
}
