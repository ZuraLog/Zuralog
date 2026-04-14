"use client";

import Image from "next/image";
import { motion } from "framer-motion";
import { useRef, useCallback } from "react";
import gsap from "gsap";

const CATEGORIES = [
  {
    id: "nutrition",
    title: "Nutrition",
    subtitle:
      "Snap it, scan it, or say it. Log any meal in seconds — no typing, no guessing.",
    image: "/images/feature/nutrition.png",
  },
  {
    id: "workouts",
    title: "Workouts",
    subtitle:
      "Track live, log after, or sync automatically from Apple Health or Strava.",
    image: "/images/feature/workout.png",
  },
  {
    id: "sleep",
    title: "Sleep",
    subtitle:
      "See how you slept every morning — duration, quality, and stages, automatically.",
    image: "/images/feature/sleep.png",
  },
  {
    id: "heart",
    title: "Heart",
    subtitle:
      "Resting heart rate, HRV, and recovery — tracked automatically, shown in context.",
    image: "/images/feature/heart.png",
  },
];

// ---------------------------------------------------------------------------
// TiltCard
// ---------------------------------------------------------------------------

interface TiltCardProps {
  cat: (typeof CATEGORIES)[number];
  index: number;
}

function TiltCard({ cat, index }: TiltCardProps) {
  const cardRef = useRef<HTMLDivElement>(null);
  const glowRef = useRef<HTMLDivElement>(null);

  const onMouseMove = useCallback((e: React.MouseEvent<HTMLDivElement>) => {
    const card = cardRef.current;
    const glow = glowRef.current;
    if (!card) return;

    const rect = card.getBoundingClientRect();
    const dx = (e.clientX - rect.left - rect.width / 2) / (rect.width / 2);
    const dy = (e.clientY - rect.top - rect.height / 2) / (rect.height / 2);

    gsap.to(card, {
      rotateX: -dy * 7,
      rotateY: dx * 7,
      duration: 0.4,
      ease: "power2.out",
    });

    if (glow) {
      gsap.to(glow, {
        x: e.clientX - rect.left,
        y: e.clientY - rect.top,
        opacity: 1,
        duration: 0.35,
        ease: "power2.out",
      });
    }
  }, []);

  const onMouseLeave = useCallback(() => {
    const card = cardRef.current;
    const glow = glowRef.current;
    if (!card) return;

    gsap.to(card, {
      rotateX: 0,
      rotateY: 0,
      duration: 0.7,
      ease: "elastic.out(1, 0.5)",
    });

    if (glow) {
      gsap.to(glow, { opacity: 0, duration: 0.4, ease: "power2.out" });
    }
  }, []);

  return (
    <motion.div
      initial={{ opacity: 0, y: 32 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true }}
      transition={{ duration: 0.5, delay: index * 0.08 }}
      style={{ perspective: "1000px" }}
    >
      <div
        ref={cardRef}
        onMouseMove={onMouseMove}
        onMouseLeave={onMouseLeave}
        className="relative overflow-hidden rounded-[20px] flex flex-col"
        style={{
          backgroundColor: "#E8E6E1",
          boxShadow: "0 2px 16px rgba(22, 22, 24, 0.06)",
          transformStyle: "preserve-3d",
          willChange: "transform",
        }}
      >
        {/* Text block */}
        <div className="relative z-10 px-7 pt-7 pb-4 flex-shrink-0">
          <h3
            className="font-bold text-[#161618] leading-tight"
            style={{ fontSize: "clamp(1.4rem, 2.2vw, 1.9rem)" }}
          >
            {cat.title}
          </h3>
          <p className="mt-2 text-[#6B6864] text-[15px] leading-relaxed max-w-[280px]">
            {cat.subtitle}
          </p>
        </div>

        {/* Image — 1:1 container, never stretches */}
        <div className="relative w-full aspect-square">
          <Image
            src={cat.image}
            alt={cat.title}
            fill
            className="object-cover object-top"
            sizes="(max-width: 640px) 100vw, 50vw"
            priority={index < 2}
          />
          {/* Gradient fades from card color at top into the image — no hard seam */}
          <div
            className="absolute inset-x-0 top-0 h-16 pointer-events-none"
            style={{
              background: "linear-gradient(to bottom, #E8E6E1, transparent)",
            }}
          />
        </div>

        {/* Cursor glow */}
        <div
          ref={glowRef}
          aria-hidden="true"
          className="pointer-events-none absolute z-30 opacity-0"
          style={{
            width: 240,
            height: 240,
            borderRadius: "50%",
            background:
              "radial-gradient(circle, rgba(52,78,65,0.18) 0%, transparent 70%)",
            transform: "translate(-50%, -50%)",
            top: 0,
            left: 0,
          }}
        />
      </div>
    </motion.div>
  );
}

// ---------------------------------------------------------------------------
// FeaturesCardSection
// ---------------------------------------------------------------------------

export function FeaturesCardSection() {
  return (
    <section
      className="relative py-24 md:py-32 px-6 md:px-12 font-jakarta"
    >
      <div className="mx-auto max-w-6xl">
        {/* Section headline */}
        <motion.div
          initial={{ opacity: 0, y: 24 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          className="mb-16 md:mb-20"
        >
          <span className="inline-flex items-center gap-2 rounded-full border border-[#344E41]/30 bg-[#344E41]/8 px-4 py-1.5 text-xs font-semibold uppercase tracking-widest text-[#344E41] mb-6">
            <span className="h-1.5 w-1.5 rounded-full bg-[#344E41]" />
            Features
          </span>

          <h2
            className="font-bold uppercase tracking-tighter leading-[0.9] text-[#161618]"
            style={{ fontSize: "clamp(2.5rem, 5vw, 5.5rem)" }}
          >
            Every part
            <br />
            of your health.
          </h2>
          <p className="mt-5 text-lg md:text-xl text-[#6B6864] max-w-xl">
            ZuraLog tracks the four things that actually matter — and shows you
            how they all connect.
          </p>
        </motion.div>

        {/* 2×2 card grid */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          {CATEGORIES.map((cat, i) => (
            <TiltCard key={cat.id} cat={cat} index={i} />
          ))}
        </div>
      </div>
    </section>
  );
}
