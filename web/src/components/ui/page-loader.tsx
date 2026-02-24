/**
 * PageLoader — full-screen loading overlay shown on initial page load.
 *
 * Fades out automatically after a brief delay, giving the 3D scene
 * time to initialize without showing a broken blank state.
 */
"use client";

import { useEffect, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";

/**
 * Full-screen page loader that auto-dismisses after assets load.
 */
export function PageLoader() {
  const [visible, setVisible] = useState(true);

  useEffect(() => {
    const timer = setTimeout(() => setVisible(false), 1800);
    return () => clearTimeout(timer);
  }, []);

  return (
    <AnimatePresence>
      {visible && (
        <motion.div
          key="loader"
          initial={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.6, ease: "easeInOut" }}
          className="fixed inset-0 z-[100] flex flex-col items-center justify-center bg-black"
        >
          <motion.span
            initial={{ opacity: 0, scale: 0.9 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ duration: 0.4 }}
            className="font-display text-2xl font-bold tracking-widest text-sage"
          >
            ZURALOG
          </motion.span>

          {/* Loading bar */}
          <div className="mt-6 h-px w-24 overflow-hidden bg-white/10">
            <motion.div
              className="h-full bg-sage"
              initial={{ width: "0%" }}
              animate={{ width: "100%" }}
              transition={{ duration: 1.5, ease: "easeInOut" }}
            />
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
