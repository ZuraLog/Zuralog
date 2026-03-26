"use client";

import React, {
  createContext,
  useContext,
  useRef,
  useCallback,
  useEffect,
  useState,
} from "react";

/**
 * PatternVideoProvider — loads the Sage.mp4 once and shares a single <video>
 * element across the entire component tree. Components call `attachTo(container)`
 * on mouseenter and `detach()` on mouseleave. The video is reparented into the
 * hovered component's container so it fills it with object-fit:cover.
 *
 * This avoids loading 20+ <video> elements — only one exists at any time.
 */

interface PatternVideoCtx {
  attachTo: (container: HTMLElement) => void;
  detach: () => void;
}

const Ctx = createContext<PatternVideoCtx | null>(null);

export function PatternVideoProvider({ children }: { children: React.ReactNode }) {
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const currentContainerRef = useRef<HTMLElement | null>(null);

  // Create the video element once on mount
  useEffect(() => {
    const video = document.createElement("video");
    video.src = "/patterns/Sage.mp4";
    video.muted = true;
    video.loop = true;
    video.playsInline = true;
    video.preload = "auto";
    video.setAttribute("aria-hidden", "true");
    Object.assign(video.style, {
      position: "absolute",
      inset: "0",
      width: "100%",
      height: "100%",
      objectFit: "cover",
      pointerEvents: "none",
      borderRadius: "inherit",
      zIndex: "1",
      opacity: "0",
      transition: "opacity 0.25s ease",
      filter: "brightness(1.1) saturate(0.9)",
    });
    videoRef.current = video;

    return () => {
      video.pause();
      video.removeAttribute("src");
      video.load();
      if (video.parentNode) video.parentNode.removeChild(video);
    };
  }, []);

  const attachTo = useCallback((container: HTMLElement) => {
    const video = videoRef.current;
    if (!video) return;

    // If already in this container, nothing to do
    if (currentContainerRef.current === container) return;

    // Move the video into the new container
    container.appendChild(video);
    currentContainerRef.current = container;

    // Play and fade in
    video.currentTime = 0;
    video.play().catch(() => {});
    video.style.opacity = "0.55";
  }, []);

  const detach = useCallback(() => {
    const video = videoRef.current;
    if (!video) return;

    // Fade out
    video.style.opacity = "0";

    // After transition, pause and remove from DOM
    const timeout = setTimeout(() => {
      video.pause();
      if (video.parentNode) video.parentNode.removeChild(video);
      currentContainerRef.current = null;
    }, 200);

    // Clean up if attachTo is called before timeout fires
    return () => clearTimeout(timeout);
  }, []);

  return <Ctx.Provider value={{ attachTo, detach }}>{children}</Ctx.Provider>;
}

/**
 * usePatternVideo — returns onMouseEnter/onMouseLeave handlers that wire up
 * the shared video to any container ref.
 */
export function usePatternVideo() {
  const ctx = useContext(Ctx);
  const containerRef = useRef<HTMLElement | null>(null);
  const detachCleanup = useRef<(() => void) | undefined>(undefined);

  const onMouseEnter = useCallback(() => {
    if (!ctx || !containerRef.current) return;
    if (detachCleanup.current) detachCleanup.current();
    ctx.attachTo(containerRef.current);
  }, [ctx]);

  const onMouseLeave = useCallback(() => {
    if (!ctx) return;
    detachCleanup.current = ctx.detach() as (() => void) | undefined;
  }, [ctx]);

  return { containerRef, onMouseEnter, onMouseLeave };
}

/**
 * withPatternVideo — a thin wrapper div that hooks up the hover video.
 * Wrap any patterned component with this to get the animated hover effect.
 *
 * Usage:
 *   <PatternVideoHover className="rounded-ds-pill">
 *     <button ...>Primary</button>
 *   </PatternVideoHover>
 */
export function PatternVideoHover({
  children,
  className,
  style,
}: {
  children: React.ReactNode;
  className?: string;
  style?: React.CSSProperties;
}) {
  const { containerRef, onMouseEnter, onMouseLeave } = usePatternVideo();

  return (
    <div
      ref={containerRef as React.Ref<HTMLDivElement>}
      className={className}
      style={{ position: "relative", overflow: "hidden", ...style }}
      onMouseEnter={onMouseEnter}
      onMouseLeave={onMouseLeave}
    >
      {children}
    </div>
  );
}
