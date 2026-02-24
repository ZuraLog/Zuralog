/**
 * Features Showcase section — 4 alternating text/visual blocks.
 * GSAP ScrollTrigger animations with parallax.
 */
"use client";

import { useRef } from "react";
import { useGSAP } from "@gsap/react";
import { gsap } from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { motion } from "framer-motion";
import { Brain, Zap, PenLine, LayoutDashboard } from "lucide-react";

gsap.registerPlugin(ScrollTrigger);

const FEATURES = [
  {
    icon: Brain,
    tag: "AI Reasoning",
    title: "Cross-app intelligence that actually connects the dots",
    body: "ZuraLog’s AI reads across Strava, Oura, CalAI, and more simultaneously — noticing that your recovery scores drop when you eat late, or that your best runs follow 8+ hours of deep sleep.",
    visual: "neural",
    accent: "#CFE1B9",
  },
  {
    icon: Zap,
    tag: "Autonomous Actions",
    title: "Your AI acts — not just advises",
    body: "ZuraLog doesn’t just tell you what to do. When your HRV is low, it adjusts your training plan. When you hit a macro goal, it celebrates and suggests a recovery meal. It works, so you don’t have to think.",
    visual: "actions",
    accent: "#A8D8A8",
  },
  {
    icon: PenLine,
    tag: "Zero-Friction Logging",
    title: "Log once, sync everywhere — or don’t log at all",
    body: "Connect your apps and ZuraLog pulls data automatically. Snap a photo of your meal with CalAI — ZuraLog sees it. Finish a Strava run — ZuraLog knows. Talk to it like a human. It listens.",
    visual: "logging",
    accent: "#CFE1B9",
  },
  {
    icon: LayoutDashboard,
    tag: "One Dashboard",
    title: "Every metric, every app, one beautiful view",
    body: "Replace your five-app morning routine with a single intelligent dashboard that shows you exactly what you need to know — nothing more, nothing less — in language you actually understand.",
    visual: "dashboard",
    accent: "#A8D8A8",
  },
];

interface VisualProps {
  type: string;
  accent: string;
}

/**
 * Abstract animated visual for each feature block.
 */
function FeatureVisual({ type, accent }: VisualProps) {
  const visuals: Record<string, React.ReactNode> = {
    neural: (
      <div className="relative flex h-full items-center justify-center">
        <div className="relative h-48 w-48">
          {[0, 1, 2, 3, 4].map((i) => (
            <motion.div
              key={i}
              className="absolute rounded-full border"
              style={{
                width: 40 + i * 26,
                height: 40 + i * 26,
                top: "50%",
                left: "50%",
                borderColor: `${accent}${Math.floor(40 - i * 6).toString(16).padStart(2, "0")}`,
                transform: "translate(-50%,-50%)",
              }}
              animate={{ rotate: i % 2 === 0 ? 360 : -360, scale: [1, 1.03, 1] }}
              transition={{ duration: 8 + i * 2, repeat: Infinity, ease: "linear" }}
            />
          ))}
          <motion.div
            className="absolute left-1/2 top-1/2 h-4 w-4 -translate-x-1/2 -translate-y-1/2 rounded-full"
            style={{ backgroundColor: accent }}
            animate={{ scale: [1, 1.4, 1] }}
            transition={{ duration: 2, repeat: Infinity }}
          />
        </div>
      </div>
    ),
    actions: (
      <div className="flex flex-col gap-3 p-4">
        {["Adjust training plan", "Log recovery meal", "Alert: Low HRV"].map((action, i) => (
          <motion.div
            key={action}
            className="flex items-center gap-3 rounded-2xl border border-border/30 bg-surface px-4 py-3"
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: i * 0.3, repeat: Infinity, repeatDelay: 3 }}
          >
            <div className="h-2 w-2 rounded-full" style={{ backgroundColor: accent }} />
            <span className="text-sm text-foreground/80">{action}</span>
          </motion.div>
        ))}
      </div>
    ),
    logging: (
      <div className="space-y-3 p-4">
        {[
          { app: "Strava", data: "Run: 8.2km @ 5:12/km" },
          { app: "CalAI", data: "Lunch: 640 kcal logged" },
          { app: "Oura", data: "Sleep score: 87" },
        ].map((item, i) => (
          <motion.div
            key={item.app}
            className="flex items-center justify-between rounded-xl border border-border/20 bg-surface px-4 py-2.5"
            animate={{ borderColor: [`rgba(207,225,185,0)`, `rgba(207,225,185,0.3)`, `rgba(207,225,185,0)`] }}
            transition={{ duration: 2, delay: i * 0.7, repeat: Infinity }}
          >
            <span className="text-xs font-medium text-muted-foreground">{item.app}</span>
            <span className="text-xs text-foreground/80">{item.data}</span>
          </motion.div>
        ))}
      </div>
    ),
    dashboard: (
      <div className="grid grid-cols-2 gap-3 p-4">
        {[
          { label: "HRV", value: "68ms" },
          { label: "Calories", value: "2,340" },
          { label: "Sleep", value: "7h 42m" },
          { label: "Steps", value: "9,820" },
        ].map((metric) => (
          <motion.div
            key={metric.label}
            className="rounded-2xl border border-border/20 bg-surface p-4"
            whileHover={{ borderColor: "rgba(207,225,185,0.3)" }}
          >
            <p className="text-xs text-muted-foreground">{metric.label}</p>
            <p className="mt-1 font-display text-xl font-bold" style={{ color: accent }}>{metric.value}</p>
          </motion.div>
        ))}
      </div>
    ),
  };

  return (
    <div className="h-72 overflow-hidden rounded-3xl border border-border/20 bg-surface/50 md:h-80">
      {visuals[type] ?? null}
    </div>
  );
}

/**
 * Renders the 4-feature showcase with alternating layout and scroll animations.
 */
export function FeaturesSection() {
  const sectionRef = useRef<HTMLElement>(null);

  useGSAP(
    () => {
      if (!sectionRef.current) return;

      sectionRef.current.querySelectorAll(".feature-block").forEach((block) => {
        gsap.fromTo(
          block,
          { opacity: 0, y: 50 },
          {
            opacity: 1,
            y: 0,
            duration: 0.9,
            ease: "power3.out",
            scrollTrigger: {
              trigger: block,
              start: "top 80%",
            },
          },
        );
      });
    },
    { scope: sectionRef },
  );

  return (
    <section ref={sectionRef} className="py-28 md:py-40" id="features">
      <div className="mx-auto max-w-6xl px-4">
        <div className="mb-20 text-center">
          <p className="mb-4 text-xs font-semibold tracking-[0.2em] text-sage uppercase">What ZuraLog Does</p>
          <h2 className="font-display text-4xl font-bold tracking-tight md:text-5xl">
            One AI. All your apps. Actually useful.
          </h2>
        </div>

        <div className="space-y-24">
          {FEATURES.map((feature, i) => {
            const Icon = feature.icon;
            const isReversed = i % 2 === 1;
            return (
              <div
                key={feature.tag}
                className={`feature-block grid items-center gap-12 md:grid-cols-2 ${isReversed ? "md:[&>*:first-child]:order-2" : ""}`}
              >
                {/* Text */}
                <div className="space-y-5">
                  <div className="flex items-center gap-3">
                    <div className="inline-flex h-10 w-10 items-center justify-center rounded-xl border border-border/30 bg-surface">
                      <Icon className="h-4 w-4 text-sage" />
                    </div>
                    <span className="text-xs font-semibold tracking-[0.15em] text-sage uppercase">{feature.tag}</span>
                  </div>
                  <h3 className="font-display text-3xl font-bold leading-tight tracking-tight md:text-4xl">
                    {feature.title}
                  </h3>
                  <p className="text-lg leading-relaxed text-muted-foreground">{feature.body}</p>
                </div>

                {/* Visual */}
                <FeatureVisual type={feature.visual} accent={feature.accent} />
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
}
