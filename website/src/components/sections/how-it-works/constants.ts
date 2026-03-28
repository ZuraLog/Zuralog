export const STEPS = [
  {
    id: "connect",
    label: "Connect",
    headline: "Link your world",
    description:
      "One tap to connect Apple Health, Google Health Connect, and 50+ more. Your data flows in automatically — no exports, no friction, no manual entry ever again.",
    accent: "#CFE1B9",
  },
  {
    id: "today",
    label: "Today",
    headline: "Your day, at a glance",
    description:
      "Daily insights, quick logging for water, calories, workouts — everything you need to know and do, all in one place.",
    accent: "#D4F291",
  },
  {
    id: "data",
    label: "Data",
    headline: "Your data, your way",
    description:
      "Organize, customize, and explore every metric. Built around you, not a template — your own personal health dashboard.",
    accent: "#E8F5A8",
  },
  {
    id: "coach",
    label: "Coach",
    headline: "Talk to your data",
    description:
      "Ask anything in plain English. \"Why am I tired?\" \"What should I eat tonight?\" Your AI health coach has all the context it needs.",
    accent: "#CFE1B9",
  },
  {
    id: "progress",
    label: "Progress",
    headline: "Set goals, earn wins",
    description:
      "Track goals, unlock achievements, journal your journey, and watch yourself grow — all your progress in one place.",
    accent: "#D4F291",
  },
  {
    id: "trends",
    label: "Trends",
    headline: "Discover what you can't see",
    description:
      "AI finds correlations in your data you'd never notice — like why your pace dropped after a bad night's sleep.",
    accent: "#E8F5A8",
  },
] as const;

export type Step = (typeof STEPS)[number];
