"use client";

import { useEffect } from "react";
import { CustomCursor } from "./custom-cursor";
import { SoundToggle } from "./sound-toggle";
import { ThemeToggle } from "./theme-toggle";
import { useSoundContext } from "./sound-provider";
import { SpotlightFollow } from "./spotlight-follow";
import { ScrollProgress } from "./scroll-progress";

/**
 * Client-side wrapper that renders premium interaction layers
 * for the brand bible page. Imported into the server-component layout.
 */
export function BrandBibleInteractions() {
  const { playSound } = useSoundContext();

  // Event-delegated sound triggers — no component modifications needed.
  // Listens for clicks on the document and plays the right sound based on
  // what the user clicked (button, toggle, checkbox, tab, etc.).
  useEffect(() => {
    const handleClick = (e: MouseEvent) => {
      const target = e.target;
      if (!(target instanceof HTMLElement)) return;

      // Toggle switches
      if (target.closest("[role='switch']")) {
        const sw = target.closest("[role='switch']") as HTMLElement;
        playSound(
          sw.getAttribute("aria-checked") === "true" ? "toggle-off" : "toggle-on"
        );
        return;
      }

      // Checkboxes
      if (target.closest("[role='checkbox']")) {
        playSound("tick");
        return;
      }

      // Tabs
      if (target.closest("[role='tab']")) {
        playSound("tab-click");
        return;
      }

      // Buttons (general — catch-all after more specific matches)
      if (
        target.closest(
          "button[class*='bg-ds-sage'], button[class*='ds-pattern-drift']"
        )
      ) {
        playSound("click");
        return;
      }
    };

    // Hover sound on buttons
    const handleHover = (e: MouseEvent) => {
      const target = e.target as Element;
      if (target instanceof HTMLElement && target.closest("button:not([disabled])")) {
        playSound("pop");
      }
    };

    document.addEventListener("click", handleClick);
    document.addEventListener("mouseenter", handleHover, true);
    return () => {
      document.removeEventListener("click", handleClick);
      document.removeEventListener("mouseenter", handleHover, true);
    };
  }, [playSound]);

  return (
    <>
      <SpotlightFollow />
      <ScrollProgress />
      <CustomCursor />
      <SoundToggle />
      <ThemeToggle />
    </>
  );
}
