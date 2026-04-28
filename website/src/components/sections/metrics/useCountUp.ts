"use client";

import { useRef, useState, useEffect } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";

interface UseCountUpOptions {
  target: number;
  duration?: number;
  suffix?: string;
  decimals?: number;
}

export function useCountUp<T extends HTMLElement = HTMLElement>({
  target,
  duration = 1.2,
  suffix = "",
  decimals = 0,
}: UseCountUpOptions) {
  const ref = useRef<T>(null);
  const [display, setDisplay] = useState(`0${suffix}`);
  const hasPlayed = useRef(false);

  useEffect(() => {
    const el = ref.current;
    if (!el || hasPlayed.current) return;

    const prefersReducedMotion = window.matchMedia(
      "(prefers-reduced-motion: reduce)",
    ).matches;

    if (prefersReducedMotion) {
      setDisplay(`${target.toLocaleString()}${suffix}`);
      hasPlayed.current = true;
      return;
    }

    const obj = { val: 0 };

    const tween = gsap.to(obj, {
      val: target,
      duration,
      ease: "power2.out",
      scrollTrigger: {
        trigger: el,
        start: "top 85%",
        toggleActions: "play none none none",
      },
      onUpdate: () => {
        const formatted = decimals > 0
          ? obj.val.toFixed(decimals)
          : Math.round(obj.val).toLocaleString();
        setDisplay(`${formatted}${suffix}`);
      },
      onComplete: () => {
        hasPlayed.current = true;
      },
    });

    return () => {
      tween.scrollTrigger?.kill();
      tween.kill();
    };
  }, [target, duration, suffix, decimals]);

  return { ref, display };
}
