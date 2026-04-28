"use client";

import * as Sentry from "@sentry/nextjs";
import { useEffect, useRef } from "react";
import { motion } from "framer-motion";
import { gsap } from "gsap";
import Link from "next/link";
import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";

const EXPO_OUT = [0.16, 1, 0.3, 1] as [number, number, number, number];

interface ErrorPageProps {
  error: Error & { digest?: string };
  reset: () => void;
}

export default function ErrorPage({ error, reset }: ErrorPageProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const numberRef = useRef<HTMLParagraphElement>(null);
  const patternRef = useRef<HTMLDivElement>(null);

  // Report to Sentry
  useEffect(() => {
    Sentry.captureException(error);
  }, [error]);

  // Mouse parallax on the 500 number
  useEffect(() => {
    const container = containerRef.current;
    const number = numberRef.current;
    const pattern = patternRef.current;
    if (!container || !number || !pattern) return;

    const handleMouseMove = (e: MouseEvent) => {
      const rect = container.getBoundingClientRect();
      const x = (e.clientX - rect.left) / rect.width - 0.5;
      const y = (e.clientY - rect.top) / rect.height - 0.5;

      gsap.to(number, {
        x: x * 30,
        y: y * 15,
        duration: 0.8,
        ease: "power2.out",
      });

      gsap.to(pattern, {
        x: x * -10,
        y: y * -8,
        duration: 1.2,
        ease: "power2.out",
      });
    };

    const handleMouseLeave = () => {
      gsap.to([number, pattern], {
        x: 0,
        y: 0,
        duration: 1,
        ease: "elastic.out(1, 0.4)",
      });
    };

    container.addEventListener("mousemove", handleMouseMove);
    container.addEventListener("mouseleave", handleMouseLeave);
    return () => {
      container.removeEventListener("mousemove", handleMouseMove);
      container.removeEventListener("mouseleave", handleMouseLeave);
    };
  }, []);

  // Slow pattern drift animation
  useEffect(() => {
    const pattern = patternRef.current;
    if (!pattern) return;

    gsap.to(pattern, {
      backgroundPosition: "600px 600px",
      duration: 60,
      ease: "none",
      repeat: -1,
    });
  }, []);

  return (
    <>
      <div
        ref={containerRef}
        className="relative flex min-h-screen flex-col overflow-hidden"
        style={{ background: "#FAFAF5" }}
      >
        {/* Topographic pattern texture */}
        <div
          ref={patternRef}
          className="pointer-events-none absolute inset-[-100px]"
          style={{
            backgroundImage: 'url("/brand-pattern-hd.jpg")',
            backgroundSize: "600px auto",
            backgroundRepeat: "repeat",
            opacity: 0.025,
            mixBlendMode: "multiply",
          }}
        />

        <Navbar />

        <main className="relative z-10 flex flex-1 items-center justify-center px-6 pt-24 pb-16">
          {/* Giant background 500 watermark */}
          <motion.p
            ref={numberRef}
            initial={{ opacity: 0, scale: 0.9 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ duration: 1.2, ease: EXPO_OUT }}
            className="pointer-events-none absolute select-none font-bold leading-none tracking-[-0.04em]"
            style={{
              fontSize: "clamp(300px, 40vw, 600px)",
              color: "rgba(207, 225, 185, 0.25)",
            }}
          >
            500
          </motion.p>

          {/* Centered content on top */}
          <div className="relative z-10 flex flex-col items-center text-center">
            {/* Headline */}
            <motion.h1
              initial={{ opacity: 0, y: 24 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.8, ease: EXPO_OUT, delay: 0.2 }}
              className="text-[36px] font-semibold tracking-tight sm:text-[48px]"
              style={{ color: "#1A2E22" }}
            >
              There was an error
            </motion.h1>

            {/* Buttons */}
            <motion.div
              initial={{ opacity: 0, y: 16 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.7, ease: EXPO_OUT, delay: 0.4 }}
              className="mt-8 flex flex-col items-center gap-3 sm:flex-row"
            >
              <button
                onClick={reset}
                className="btn-pattern-light inline-flex items-center justify-center rounded-full px-7 py-3.5 text-[15px] font-semibold animate-sage-glow transition-all duration-300 hover:scale-[1.03] active:scale-[0.97]"
                style={{
                  background: "#CFE1B9",
                  color: "#141E18",
                  boxShadow: "0 2px 12px rgba(207, 225, 185, 0.4)",
                }}
              >
                Try again
              </button>
              <Link
                href="/"
                className="inline-flex items-center justify-center rounded-full px-7 py-3.5 text-[15px] font-semibold transition-all duration-300 hover:scale-[1.03] active:scale-[0.97]"
                style={{
                  color: "#344E41",
                  border: "1.5px solid rgba(52, 78, 65, 0.20)",
                }}
              >
                Go to home
              </Link>
            </motion.div>

            {/* Error digest */}
            {error.digest && (
              <motion.p
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={{ duration: 0.7, delay: 0.6 }}
                className="mt-8 text-[10px]"
                style={{
                  color: "rgba(52, 78, 65, 0.2)",
                  fontFamily: "var(--font-geist-mono, monospace)",
                }}
              >
                Error ID: {error.digest}
              </motion.p>
            )}
          </div>
        </main>

        <Footer />
      </div>
    </>
  );
}
