/**
 * CompletionStep — success screen with shareable referral card.
 * Peach + cream palette for website.
 */
'use client';

import { useState } from 'react';
import { motion } from 'framer-motion';
import { toast } from 'sonner';
import dynamic from 'next/dynamic';
import { Button } from '@/components/ui/button';
import { getReferralUrl, buildShareText } from '@/lib/referral';
import type { SuccessData } from '@/hooks/use-quiz';

const ConfettiBurst = dynamic(
  () => import('@/components/confetti-burst').then((m) => m.ConfettiBurst),
  { ssr: false },
);

interface CompletionStepProps {
  data: SuccessData;
}

export function CompletionStep({ data }: CompletionStepProps) {
  const referralUrl = getReferralUrl(data.referralCode);
  const { twitter, generic } = buildShareText(data.position, referralUrl);
  const isFoundingMember = data.tier === 'founding_30' || data.tier === 'founding';
  const [copied, setCopied] = useState(false);

  function copyLink() {
    navigator.clipboard.writeText(referralUrl).then(() => {
      setCopied(true);
      toast.success('Link copied!');
      setTimeout(() => setCopied(false), 2000);
    });
  }

  function shareTwitter() {
    window.open(`https://twitter.com/intent/tweet?text=${encodeURIComponent(twitter)}`, '_blank');
  }

  function shareWhatsApp() {
    window.open(`https://wa.me/?text=${encodeURIComponent(generic)}`, '_blank');
  }

  async function shareNative() {
    if (navigator.share) {
      try {
        await navigator.share({ title: 'Join ZuraLog', text: generic, url: referralUrl });
      } catch {
        copyLink();
      }
    } else {
      copyLink();
    }
  }

  return (
    <>
      <ConfettiBurst trigger={true} />
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5, ease: 'easeOut' }}
        className="flex flex-col items-center gap-6"
      >
        {/* Share Card */}
        <motion.div
          initial={{ opacity: 0, scale: 0.9 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ duration: 0.6, delay: 0.15, ease: 'easeOut' }}
          className="relative w-full max-w-sm overflow-hidden rounded-3xl border border-peach/20 bg-gradient-to-b from-white to-cream p-6 sm:p-8 shadow-[0_8px_40px_rgba(207,225,185,0.30)]"
        >
          {/* Ambient peach glow */}
          <div className="pointer-events-none absolute -top-20 left-1/2 h-40 w-40 -translate-x-1/2 rounded-full bg-peach/20 blur-3xl" />
          <div className="pointer-events-none absolute -bottom-16 left-1/2 h-32 w-32 -translate-x-1/2 rounded-full bg-peach/10 blur-3xl" />

          {/* Logo + branding */}
          <div className="relative mb-6 flex items-center justify-center gap-2">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/logo/Zuralog.png" alt="ZuraLog" className="h-6 w-6 rounded-lg" />
            <span className="text-sm font-semibold tracking-tight text-black/40">ZuraLog</span>
          </div>

          {/* Founding member badge */}
          {isFoundingMember && (
            <motion.div
              initial={{ opacity: 0, y: -8 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.3 }}
              className="relative mb-4 flex justify-center"
            >
              <span className="inline-flex items-center gap-1.5 rounded-full border border-peach/30 bg-peach/10 px-3 py-1">
                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" className="text-peach">
                  <path d="M12 2l2.4 7.4H22l-6.2 4.5 2.4 7.4L12 16.8l-6.2 4.5 2.4-7.4L2 9.4h7.6L12 2z" fill="currentColor" />
                </svg>
                <span className="text-[10px] font-bold uppercase tracking-[0.15em] text-peach-dim">
                  Founding Member
                </span>
              </span>
            </motion.div>
          )}

          {/* Position number */}
          <div className="relative mb-1 text-center">
            <motion.p
              initial={{ opacity: 0, scale: 0.5 }}
              animate={{ opacity: 1, scale: 1 }}
              transition={{ type: 'spring', stiffness: 200, damping: 15, delay: 0.2 }}
              className="text-6xl font-black tracking-tight text-peach sm:text-7xl"
            >
              #{data.position}
            </motion.p>
            <p className="mt-1 text-sm font-medium text-black/30">on the waitlist</p>
          </div>

          {/* Divider */}
          <div className="my-5 flex items-center gap-3">
            <div className="h-px flex-1 bg-gradient-to-r from-transparent via-black/10 to-transparent" />
            <div className="h-1 w-1 rounded-full bg-peach/40" />
            <div className="h-px flex-1 bg-gradient-to-r from-transparent via-black/10 to-transparent" />
          </div>

          {/* Referral code */}
          <div className="relative text-center">
            <p className="mb-2 text-[10px] font-semibold uppercase tracking-[0.2em] text-black/25">
              Your referral code
            </p>
            <div className="inline-flex items-center gap-2 rounded-xl border border-black/8 bg-black/3 px-5 py-2.5">
              <span className="font-mono text-xl font-bold tracking-[0.3em] text-dark-charcoal">
                {data.referralCode}
              </span>
            </div>
            <p className="mt-3 text-[11px] text-black/25">
              Each friend who joins moves you up one spot
            </p>
          </div>

          {/* Watermark */}
          <div className="mt-6 flex items-center justify-center gap-1.5 opacity-30">
            <div className="h-px w-6 bg-peach/50" />
            <span className="text-[9px] font-medium uppercase tracking-[0.2em] text-peach-dim">
              zuralog.com
            </span>
            <div className="h-px w-6 bg-peach/50" />
          </div>
        </motion.div>

        {/* Share Actions */}
        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.4, duration: 0.4 }}
          className="w-full max-w-sm space-y-2.5"
        >
          <p className="mb-3 text-center text-xs font-semibold uppercase tracking-[0.15em] text-black/25">
            Share & move up
          </p>

          <Button
            onClick={shareTwitter}
            className="group w-full rounded-xl bg-black/4 py-5 font-medium text-black/60 transition-all hover:bg-black/8 hover:text-dark-charcoal"
          >
            <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" className="mr-2.5 opacity-60 group-hover:opacity-100">
              <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
            </svg>
            Share on X
          </Button>

          <Button
            onClick={shareWhatsApp}
            className="group w-full rounded-xl bg-black/4 py-5 font-medium text-black/60 transition-all hover:bg-[#25D366]/15 hover:text-[#25D366]"
          >
            <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" className="mr-2.5 opacity-60 group-hover:opacity-100">
              <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z" />
            </svg>
            Share on WhatsApp
          </Button>

          <Button
            onClick={copyLink}
            className="group w-full rounded-xl bg-black/4 py-5 font-medium text-black/60 transition-all hover:bg-peach/10 hover:text-peach-dim"
          >
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" className="mr-2.5 opacity-60 group-hover:opacity-100">
              <rect x="9" y="9" width="13" height="13" rx="2" ry="2" />
              <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" />
            </svg>
            {copied ? 'Copied!' : 'Copy referral link'}
          </Button>

          {'share' in (typeof navigator !== 'undefined' ? navigator : {}) && (
            <Button
              onClick={shareNative}
              className="group w-full rounded-xl bg-peach/10 py-5 font-semibold text-peach-dim transition-all hover:bg-peach/20"
            >
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="mr-2.5">
                <path d="M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8" />
                <polyline points="16 6 12 2 8 6" />
                <line x1="12" y1="2" x2="12" y2="15" />
              </svg>
              Share via...
            </Button>
          )}
        </motion.div>
      </motion.div>
    </>
  );
}
