"use client";

import { useRef, useEffect } from "react";
import gsap from "gsap";
import { SplitText } from "gsap/SplitText";
import { ScrollTrigger } from "gsap/dist/ScrollTrigger";

if (typeof window !== "undefined") {
  gsap.registerPlugin(SplitText, ScrollTrigger);
}

const DEMO_TEXT =
  "Your health data from every app and device — unified into one clear picture that helps you understand your body better.";

/**
 * Container Animation SplitText demo.
 *
 * Text scrolls horizontally while each character animates in from a
 * random Y offset and rotation, driven by ScrollTrigger's
 * containerAnimation. Based on the GreenSock CodePen dPMjJWv variant.
 *
 * This demo uses the actual page scroll — it pins a section and
 * scrubs the horizontal text movement as the user scrolls through.
 */
export function ContainerTextDemo() {
  const sectionRef = useRef<HTMLElement>(null);
  const textRef = useRef<HTMLHeadingElement>(null);

  useEffect(() => {
    const section = sectionRef.current;
    const textEl = textRef.current;
    if (!section || !textEl) return;

    const prefersReducedMotion = window.matchMedia(
      "(prefers-reduced-motion: reduce)",
    ).matches;
    if (prefersReducedMotion) return;

    const split = SplitText.create(textEl, { type: "chars, words" });

    const scrollTween = gsap.to(textEl, {
      xPercent: -100,
      ease: "none",
      scrollTrigger: {
        trigger: section,
        pin: true,
        end: "+=3000px",
        scrub: true,
      },
    });

    const charTweens: gsap.core.Tween[] = [];

    (split.chars as HTMLElement[]).forEach((char) => {
      const tween = gsap.from(char, {
        yPercent: gsap.utils.random(-200, 200),
        rotation: gsap.utils.random(-20, 20),
        ease: "back.out(1.2)",
        scrollTrigger: {
          trigger: char,
          containerAnimation: scrollTween,
          start: "left 100%",
          end: "left 30%",
          scrub: 1,
        },
      });
      charTweens.push(tween);
    });

    return () => {
      charTweens.forEach((t) => {
        t.scrollTrigger?.kill();
        t.kill();
      });
      scrollTween.scrollTrigger?.kill();
      scrollTween.kill();
      split.revert();
    };
  }, []);

  return (
    <section
      ref={sectionRef}
      className="overflow-hidden grid place-items-center"
      style={{ height: "100vh" }}
    >
      <h3
        ref={textRef}
        className="flex items-center whitespace-nowrap text-ds-sage font-semibold"
        style={{
          fontSize: "clamp(2rem, 8vw, 10rem)",
          width: "max-content",
          gap: "4vw",
          paddingLeft: "100vw",
          lineHeight: 1.1,
        }}
      >
        {DEMO_TEXT}
      </h3>
    </section>
  );
}
