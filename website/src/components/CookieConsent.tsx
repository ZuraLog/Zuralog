"use client";

import { useState, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import Link from "next/link";
import { useSoundContext } from "@/components/design-system/interactions/sound-provider";

const COOKIE_KEY = "zuralog-cookie-consent";

export function CookieConsent() {
  const [visible, setVisible] = useState(false);
  const { playSound } = useSoundContext();

  useEffect(() => {
    const stored = localStorage.getItem(COOKIE_KEY);
    if (!stored) setVisible(true);
  }, []);

  function accept() {
    playSound("click");
    localStorage.setItem(COOKIE_KEY, "accepted");
    setVisible(false);
  }

  function decline() {
    playSound("click");
    localStorage.setItem(COOKIE_KEY, "declined");
    setVisible(false);
  }

  return (
    <AnimatePresence>
      {visible && (
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: 20 }}
          transition={{ duration: 0.35, ease: [0.16, 1, 0.3, 1] }}
          className="fixed bottom-6 left-6 right-6 z-[70] flex justify-center pointer-events-none font-jakarta"
        >
          <div
            className="pointer-events-auto w-full max-w-lg rounded-2xl border border-[#344E41]/10 bg-[#F7F6F3] px-5 py-4 shadow-lg flex flex-col gap-3 sm:flex-row sm:items-center sm:gap-4"
          >
            <p className="text-[13px] leading-relaxed text-[#6B6864] flex-1">
              We use cookies to improve your experience and understand how people use our site.{" "}
              <Link
                href="/cookie-policy"
                className="underline underline-offset-2 text-[#344E41] hover:text-[#1A2E22] transition-colors"
              >
                Learn more
              </Link>
            </p>
            <div className="flex items-center gap-2 shrink-0">
              <button
                onClick={decline}
                className="rounded-full border border-[#344E41]/15 bg-transparent px-4 py-1.5 text-[12px] font-medium text-[#6B6864] transition-colors hover:bg-[#344E41]/[0.05] hover:text-[#161618]"
              >
                Decline
              </button>
              <button
                onClick={accept}
                className="rounded-full px-4 py-1.5 text-[12px] font-semibold text-[#F0EEE9] transition-colors hover:opacity-90"
                style={{ backgroundColor: "#344E41" }}
              >
                Accept
              </button>
            </div>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
