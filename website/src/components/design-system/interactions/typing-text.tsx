"use client";

import { useRef, useEffect, useState } from "react";
import gsap from "gsap";

interface TypingTextProps {
  /** The full text to type out */
  text: string;
  /** Milliseconds per character (default 30) */
  speed?: number;
  /** Extra CSS classes for the wrapper span */
  className?: string;
  /** Only start typing when the element scrolls into view (default true) */
  triggerOnScroll?: boolean;
}

/**
 * Reveals text one character at a time, like someone is typing it in
 * real time. Used for the AI Insight card to make the health
 * recommendation feel like it's being generated on the spot.
 *
 * A blinking cursor follows the last character, then fades out once
 * the full message has been typed.
 *
 * Respects the user's "prefers-reduced-motion" setting — if they've
 * asked for less motion, the full text appears instantly.
 */
export function TypingText({
  text,
  speed = 30,
  className = "",
  triggerOnScroll = true,
}: TypingTextProps) {
  const containerRef = useRef<HTMLSpanElement>(null);
  const [displayText, setDisplayText] = useState("");
  const [showCursor, setShowCursor] = useState(true);
  const [started, setStarted] = useState(!triggerOnScroll);

  // ScrollTrigger-based start.
  useEffect(() => {
    if (!triggerOnScroll) return;
    const el = containerRef.current;
    if (!el) return;

    // Respect reduced-motion preference — show everything instantly.
    const prefersReducedMotion = window.matchMedia(
      "(prefers-reduced-motion: reduce)",
    ).matches;

    if (prefersReducedMotion) {
      setDisplayText(text);
      setShowCursor(false);
      return;
    }

    const trigger = gsap.to(
      {},
      {
        scrollTrigger: {
          trigger: el,
          start: "top 85%",
          once: true,
          onEnter: () => setStarted(true),
        },
      },
    );

    return () => {
      trigger.scrollTrigger?.kill();
      trigger.kill();
    };
  }, [triggerOnScroll, text]);

  // Character-by-character reveal once started.
  useEffect(() => {
    if (!started) return;

    let charIndex = 0;
    let cursorTimeout = 0;
    setDisplayText("");
    setShowCursor(true);

    const interval = setInterval(() => {
      charIndex++;
      if (charIndex > text.length) {
        clearInterval(interval);
        cursorTimeout = window.setTimeout(() => setShowCursor(false), 800);
        return;
      }
      setDisplayText(text.slice(0, charIndex));
    }, speed);

    return () => {
      clearInterval(interval);
      clearTimeout(cursorTimeout);
    };
  }, [started, text, speed]);

  return (
    <span ref={containerRef} className={className}>
      {displayText}
      {showCursor && (
        <span
          className="inline-block w-[2px] h-[1em] bg-ds-sage ml-0.5 align-text-bottom"
          style={{ animation: "dsCursorBlink 0.8s step-end infinite" }}
          aria-hidden="true"
        />
      )}
    </span>
  );
}
